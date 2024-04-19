// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import { RouxEdition } from "src/RouxEdition.sol";
import { IController } from "src/interfaces/IController.sol";
import { IRegistry } from "src/interfaces/IRegistry.sol";

/**
 * @title Controller
 * @author Roux
 */
contract Controller is IController, OwnableRoles {
    using SafeCast for uint256;

    /* -------------------------------------------- */
    /* constants                                    */
    /* -------------------------------------------- */

    /**
     * @notice Controller storage slot
     * @dev keccak256(abi.encode(uint256(keccak256("rouxController.rouxContollerStorage")) - 1)) &
     * ~bytes32(uint256(0xff));
     */
    bytes32 internal constant ROUX_CONTROLLER_STORAGE_SLOT =
        0x3bc9af0df4c5885c004faa3875945a13032d22a808904023c4e4d719ec439800;

    /**
     * @notice basis point scale
     */
    uint256 internal constant BASIS_POINT_SCALE = 10_000;

    /**
     * @notice platform fee
     *
     * @dev 1000 basis points / 10%
     */
    uint256 internal constant PLATFORM_FEE = 1_000;

    /**
     * @notice registry
     */
    IRegistry internal immutable _registry;

    /* -------------------------------------------- */
    /* structures                                   */
    /* -------------------------------------------- */

    /**
     * @notice RouxEdition storage
     * @custom:storage-location erc7201:rouxController.rouxControllerStorage
     */
    struct ControllerStorage {
        bool initialized;
        bool platformFeeEnabled;
        uint192 platformFeeBalance;
        uint48 gap;
        mapping(address edition => mapping(uint256 tokenId => ControllerData)) controllerData;
        mapping(address edition => mapping(uint256 tokenId => uint256 balance)) balance;
        mapping(address edition => mapping(uint256 tokenId => uint256 amount)) pending;
    }

    /* -------------------------------------------- */
    /* constructor                                  */
    /* -------------------------------------------- */

    constructor(address registry) {
        // disable initialization of implementation contract
        _storage().initialized = true;

        // set registry
        _registry = IRegistry(registry);

        // renounce ownership of implementation contract
        _initializeOwner(msg.sender);
        renounceOwnership();
    }

    /* -------------------------------------------- */
    /* initializer                                  */
    /* -------------------------------------------- */

    /**
     * @notice initialize
     */
    function initialize() external {
        // initialize
        require(!_storage().initialized, "Already initialized");
        _storage().initialized = true;

        // set owner of the proxy
        _initializeOwner(msg.sender);
    }

    /* -------------------------------------------- */
    /* storage                                      */
    /* -------------------------------------------- */

    /**
     * @notice get Controller storage location
     * @return $ Controller storage location
     */
    function _storage() internal pure returns (ControllerStorage storage $) {
        assembly {
            $.slot := ROUX_CONTROLLER_STORAGE_SLOT
        }
    }

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    /**
     * @inheritdoc IController
     */
    function balance(address edition, uint256 tokenId) external view returns (uint256) {
        return _storage().balance[edition][tokenId];
    }

    /**
     * @inheritdoc IController
     */
    function balanceBatch(address edition, uint256[] calldata tokenIds) external view returns (uint256) {
        uint256 total;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            total += _storage().balance[edition][tokenIds[i]];
        }
        return total;
    }

    /**
     * @inheritdoc IController
     */
    function pending(address edition, uint256 tokenId) external view returns (uint256) {
        return _storage().pending[edition][tokenId];
    }

    /**
     * @inheritdoc IController
     */
    function platformFeeBalance() external view returns (uint256) {
        return _storage().platformFeeBalance;
    }

    /**
     * @inheritdoc IController
     */
    function profitShare(address edition, uint256 tokenId) external view returns (uint256) {
        return _storage().controllerData[edition][tokenId].profitShare;
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /**
     * @inheritdoc IController
     */
    function setControllerData(uint256 tokenId, address fundsRecipient, uint16 profitShare_) external {
        // revert if funds recipient is zero address
        if (fundsRecipient == address(0)) revert InvalidFundsRecipient();

        // revert if profit share exceeds basis point scale
        if (profitShare_ > BASIS_POINT_SCALE) revert InvalidProfitShare();

        // set controller data for edition + token id
        ControllerData storage d = _storage().controllerData[msg.sender][tokenId];

        d.fundsRecipient = fundsRecipient;
        d.profitShare = profitShare_;
    }

    /**
     * @inheritdoc IController
     */
    function disburse(address edition, uint256 tokenId) external payable {
        // handle mint fee
        uint192 fee;
        if (_storage().platformFeeEnabled) {
            fee = ((msg.value * PLATFORM_FEE) / BASIS_POINT_SCALE).toUint192();
            _storage().platformFeeBalance += fee;
        }

        // disburse
        _disburse(edition, tokenId, msg.value - fee);
    }

    /**
     * @inheritdoc IController
     */
    function withdraw(address edition, uint256 tokenId) external returns (uint256) {
        // get storage
        ControllerStorage storage $ = _storage();

        // cache edition's funds recipient
        address fundsRecipient = $.controllerData[edition][tokenId].fundsRecipient;

        // disburse pending balance
        uint256 pendingBalance = $.pending[edition][tokenId];
        _disburse(edition, tokenId, pendingBalance);

        // cache balance
        uint256 amount = $.balance[edition][tokenId];

        // decrement balance
        $.balance[edition][tokenId] -= amount;

        // transfer to funding recipient
        (bool success,) = fundsRecipient.call{ value: amount }("");
        if (!success) revert TransferFailed();

        emit Withdrawn(edition, tokenId, fundsRecipient, amount);

        return amount;
    }

    /**
     * @inheritdoc IController
     */
    function withdrawBatch(address edition, uint256[] calldata tokenIds) external returns (uint256) {
        // get storage
        ControllerStorage storage $ = _storage();

        // cache funding recipient
        address fundsRecipient = $.controllerData[edition][tokenIds[0]].fundsRecipient;

        // validate funding recipient
        if (fundsRecipient == address(0)) revert InvalidFundsRecipient();

        // disburse pending balances
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _disburse(edition, tokenIds[i], $.pending[edition][tokenIds[i]]);
        }

        // compute balance
        uint256 amount;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            // validate funding recipient
            if ($.controllerData[edition][tokenIds[i]].fundsRecipient != fundsRecipient) {
                revert InvalidFundsRecipient();
            }

            // decrement balance
            uint256 tokenAmount = $.balance[edition][tokenIds[i]];
            amount += tokenAmount;
            $.balance[edition][tokenIds[i]] -= tokenAmount;
        }

        // transfer to funding recipient
        (bool success,) = fundsRecipient.call{ value: amount }("");
        if (!success) revert TransferFailed();

        emit WithdrawnBatch(edition, tokenIds, fundsRecipient, amount);

        return amount;
    }

    /* -------------------------------------------- */
    /* admin                                        */
    /* -------------------------------------------- */

    /**
     * @notice enable mint fee
     * @param enable enable mint fee boolean
     */
    function platformFeeEnabled(bool enable) external onlyOwner {
        _storage().platformFeeEnabled = enable;

        emit PlatformFeeUpdated(enable);
    }

    /**
     * @notice withdraw mint fee
     * @param to recipient
     */
    function withdrawPlatformFee(address to) external onlyOwner returns (uint256) {
        // get storage
        ControllerStorage storage $ = _storage();

        // cache mint fee balance
        uint256 amount = $.platformFeeBalance;

        // reset mint fee balance
        $.platformFeeBalance = 0;

        // transfer to owner
        (bool success,) = to.call{ value: amount }("");
        if (!success) revert TransferFailed();

        return amount;
    }

    /* -------------------------------------------- */
    /* proxy | danger zone                          */
    /* -------------------------------------------- */

    /**
     * @notice get proxy implementation
     * @return implementation address
     *
     * @dev do not remove this function
     */
    function getImplementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    /**
     * @notice upgrade proxy
     * @param newImplementation new implementation contract
     * @param data optional calldata
     *
     * @dev do not remove this function
     */
    function upgradeToAndCall(address newImplementation, bytes calldata data) external onlyOwner {
        ERC1967Utils.upgradeToAndCall(newImplementation, data);
    }

    /* -------------------------------------------- */
    /* internal                                     */
    /* -------------------------------------------- */

    /**
     * @notice disburse proceeds to edition and parent
     * @param edition edition
     * @param tokenId token id
     * @param amount proceeds to disburse
     *
     * @dev proceeds are split between current edition and parent based on parent profit share
     *      profit share is percentage of total proceeds child edition earns, remainder goes to parent
     *      parent share increments parent's pending balance - will be disbursed when parent withdraws
     */
    function _disburse(address edition, uint256 tokenId, uint256 amount) internal {
        // get storage
        ControllerStorage storage $ = _storage();

        // retrieve parent data
        (address parentEdition, uint256 parentTokenId) = _registry.attribution(edition, tokenId);

        // if root, increment current edition balance
        if (parentEdition == address(0)) {
            $.balance[edition][tokenId] += amount;
            emit Disbursement(edition, tokenId, amount);
        } else {
            // if not root, compute split, increment balance for current edition and increment pending for parent
            // get profit share from parent
            uint256 parentProfitShareBps = $.controllerData[parentEdition][parentTokenId].profitShare;

            // calculate share of proceeds
            uint256 currentEditionShare = (amount * parentProfitShareBps) / BASIS_POINT_SCALE;
            uint256 parentShare = amount - currentEditionShare;

            // increment currentEdition balance by its share
            $.balance[edition][tokenId] += currentEditionShare;

            // increment the parent's pending balance - will be disbursed when parent withdraws
            $.pending[parentEdition][parentTokenId] += parentShare;

            emit Disbursement(edition, tokenId, currentEditionShare);
            emit PendingUpdated(edition, tokenId, parentEdition, parentTokenId, parentShare);
        }
    }
}
