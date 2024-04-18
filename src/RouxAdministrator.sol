// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import { RouxEdition } from "src/RouxEdition.sol";
import { IRouxAdministrator } from "src/interfaces/IRouxAdministrator.sol";

/**
 * @title Roux Administrator
 * @author Roux
 */
contract RouxAdministrator is IRouxAdministrator, OwnableRoles {
    using SafeCast for uint256;

    /* -------------------------------------------- */
    /* constants                                    */
    /* -------------------------------------------- */

    /**
     * @notice RouxAdministrator storage slot
     * @dev keccak256(abi.encode(uint256(keccak256("rouxAdministrator.rouxAdministratorStorage")) - 1)) &
     *      ~bytes32(uint256(0xff));
     */
    bytes32 internal constant ROUX_ADMINISTRATOR_STORAGE_SLOT =
        0x53d9edbcb2a983fdaf9f05a1e8ed20d948db5abe448fd915c1126096da8b9e00;

    /**
     * @notice basis point scale
     */
    uint256 internal constant BASIS_POINT_SCALE = 10_000;

    /**
     * @notice maximum depth of attribution tree
     */
    uint256 internal constant MAX_DEPTH = 8;

    /**
     * @notice mint fee
     *
     * @dev 1000 basis points / 10%
     */
    uint256 internal constant MINT_FEE = 1_000;

    /* -------------------------------------------- */
    /* structures                                   */
    /* -------------------------------------------- */

    /**
     * @notice RouxEdition storage
     * @custom:storage-location erc7201:rouxAdministrator.rouxAdministratorStorage
     */
    struct RouxAdministratorStorage {
        bool initialized;
        bool adminFeeEnabled;
        uint192 adminFeeBalance;
        uint48 gap;
        mapping(address edition => mapping(uint256 tokenId => AdministratorData)) administratorData;
        mapping(address edition => mapping(uint256 tokenId => uint256 balance)) balance;
        mapping(address edition => mapping(uint256 tokenId => uint256 amount)) pending;
    }

    /* -------------------------------------------- */
    /* constructor                                  */
    /* -------------------------------------------- */

    constructor() {
        // disable initialization of implementation contract
        _storage().initialized = true;

        // renounce ownership of implementation contract
        _initializeOwner(msg.sender);
        renounceOwnership();
    }

    /* -------------------------------------------- */
    /* initializer                                  */
    /* -------------------------------------------- */

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
     * @notice get RouxAdministrator storage location
     * @return $ RouxAdministrator storage location
     */
    function _storage() internal pure returns (RouxAdministratorStorage storage $) {
        assembly {
            $.slot := ROUX_ADMINISTRATOR_STORAGE_SLOT
        }
    }

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    /**
     * @inheritdoc IRouxAdministrator
     */
    function balance(address edition, uint256 tokenId) external view returns (uint256) {
        return _storage().balance[edition][tokenId];
    }

    /**
     * @inheritdoc IRouxAdministrator
     */
    function balanceBatch(address edition, uint256[] calldata tokenIds) external view returns (uint256) {
        uint256 total;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            total += _storage().balance[edition][tokenIds[i]];
        }
        return total;
    }

    /**
     * @inheritdoc IRouxAdministrator
     */
    function pending(address edition, uint256 tokenId) external view returns (uint256) {
        return _storage().pending[edition][tokenId];
    }

    /**
     * @inheritdoc IRouxAdministrator
     */
    function adminFeeBalance() external view returns (uint256) {
        return _storage().adminFeeBalance;
    }

    /**
     * @inheritdoc IRouxAdministrator
     */
    function profitShare(address edition, uint256 tokenId) external view returns (uint256) {
        return _storage().administratorData[edition][tokenId].profitShare;
    }

    /**
     * @inheritdoc IRouxAdministrator
     */
    function attribution(address edition, uint256 tokenId) external view returns (address, uint256) {
        RouxAdministratorStorage storage $ = _storage();

        address parentEdition = $.administratorData[edition][tokenId].parentEdition;
        uint256 parentTokenId = $.administratorData[edition][tokenId].parentTokenId;

        return (parentEdition, parentTokenId);
    }

    /**
     * @inheritdoc IRouxAdministrator
     */
    function root(address edition, uint256 tokenId) external view returns (address, uint256, uint256) {
        // pass 0 as starting depth
        return _root(edition, tokenId, 0);
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /**
     * @inheritdoc IRouxAdministrator
     */
    function setAdministratorData(
        uint256 tokenId,
        address fundsRecipient,
        uint16 profitShare_,
        address parentEdition,
        uint256 parentTokenId
    )
        external
    {
        // get current depth of parent edition and tokenId
        (,, uint256 depth) = _root(parentEdition, parentTokenId, 0);

        // revert if addition exceeds max depth
        if (depth + 1 > MAX_DEPTH) revert MaxDepthExceeded();

        // revert if funds recipient is zero address
        if (fundsRecipient == address(0)) revert InvalidFundsRecipient();

        // revert if profit share exceeds basis point scale
        if (profitShare_ > BASIS_POINT_SCALE) revert InvalidProfitShare();

        // set administrator data for edition + token id
        AdministratorData storage d = _storage().administratorData[msg.sender][tokenId];

        d.fundsRecipient = fundsRecipient;
        d.profitShare = profitShare_;
        d.parentEdition = parentEdition;
        d.parentTokenId = parentTokenId;
    }

    /**
     * @inheritdoc IRouxAdministrator
     */
    function disburse(address edition, uint256 tokenId) external payable {
        // handle mint fee
        uint192 fee;
        if (_storage().adminFeeEnabled) {
            fee = ((msg.value * MINT_FEE) / BASIS_POINT_SCALE).toUint192();
            _storage().adminFeeBalance += fee;
        }

        // disburse
        _disburse(edition, tokenId, msg.value - fee);
    }

    /**
     * @inheritdoc IRouxAdministrator
     */
    function withdraw(address edition, uint256 tokenId) external returns (uint256) {
        // get storage
        RouxAdministratorStorage storage $ = _storage();

        // cache edition's funds recipient
        address fundsRecipient = $.administratorData[edition][tokenId].fundsRecipient;

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
     * @inheritdoc IRouxAdministrator
     */
    function withdrawBatch(address edition, uint256[] calldata tokenIds) external returns (uint256) {
        // get storage
        RouxAdministratorStorage storage $ = _storage();

        // cache funding recipient
        address fundsRecipient = $.administratorData[edition][tokenIds[0]].fundsRecipient;

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
            if ($.administratorData[edition][tokenIds[i]].fundsRecipient != fundsRecipient) {
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
    function adminFeeEnabled(bool enable) external onlyOwner {
        _storage().adminFeeEnabled = enable;

        emit AdminFeeUpdated(enable);
    }

    /**
     * @notice withdraw mint fee
     * @param to recipient
     */
    function withdrawAdminFee(address to) external onlyOwner returns (uint256) {
        // get storage
        RouxAdministratorStorage storage $ = _storage();

        // cache mint fee balance
        uint256 amount = $.adminFeeBalance;

        // reset mint fee balance
        $.adminFeeBalance = 0;

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
     * @notice get root edition for a given edition
     * @param edition edition
     * @param tokenId token id
     * @param depth depth, should always be called with 0
     * @return edition if current edition is root, otherwise parent edition
     * @return token id if current edition is root, otherwise parent token id
     * @return depth
     *
     * @dev used to compute the root of an attribution tree
     *      depth is incremented on each subsequent call
     */
    function _root(address edition, uint256 tokenId, uint256 depth) internal view returns (address, uint256, uint256) {
        // get storage
        RouxAdministratorStorage storage $ = _storage();

        // if root, return edition and tokenId
        if ($.administratorData[edition][tokenId].parentEdition == address(0)) {
            return (edition, tokenId, depth);
        } else {
            // if not root, recursively call this function with parent data, incrementing depth
            return _root(
                $.administratorData[edition][tokenId].parentEdition,
                $.administratorData[edition][tokenId].parentTokenId,
                ++depth
            );
        }
    }

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
        RouxAdministratorStorage storage $ = _storage();

        // cache parent data
        address parentEdition = $.administratorData[edition][tokenId].parentEdition;
        uint256 parentTokenId = $.administratorData[edition][tokenId].parentTokenId;

        // if root, increment current edition balance
        if (parentEdition == address(0)) {
            $.balance[edition][tokenId] += amount;
            emit Disbursement(edition, tokenId, amount);
        } else {
            // if not root, compute split, increment balance for current edition and increment pending for parent
            // get profit share from parent
            uint256 parentProfitShareBps = $.administratorData[parentEdition][parentTokenId].profitShare;

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
