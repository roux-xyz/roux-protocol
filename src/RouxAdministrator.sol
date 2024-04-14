// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import { RouxEdition } from "src/RouxEdition.sol";
import { IRouxAdministrator } from "src/interfaces/IRouxAdministrator.sol";

contract RouxAdministrator is IRouxAdministrator, OwnableRoles {
    using SafeCast for uint256;

    /* -------------------------------------------- */
    /* constants                                    */
    /* -------------------------------------------- */

    /**
     * @notice RouxAdministrator storage slot
     * @dev keccak256(abi.encode(uint256(keccak256("rouxAdministrator.rouxAdministrationStorage")) - 1)) &
     *      ~bytes32(uint256(0xff));
     */
    bytes32 internal constant ROUX_ADMINISTRATOR_STORAGE_SLOT =
        0x54aeba14fcc33b5cf6350741e30cfdd5249ab55bc8e60ba8d3af833d27edab00;

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
    struct RouxAdministrationStorage {
        bool _initialized;
        bool _enableMintFee;
        uint192 _mintFeeBalance;
        uint48 _gap;
        mapping(address edition => mapping(uint256 tokenId => AdministrationData)) _administrationData;
        mapping(address edition => mapping(uint256 tokenId => uint256 balance)) _balance;
        mapping(address edition => mapping(uint256 tokenId => uint256 amount)) _pending;
    }

    /* -------------------------------------------- */
    /* constructor                                  */
    /* -------------------------------------------- */

    constructor() {
        // disable initialization of implementation contract
        _storage()._initialized = true;

        // renounce ownership of implementation contract
        _initializeOwner(msg.sender);
        renounceOwnership();
    }

    /* -------------------------------------------- */
    /* initializer                                  */
    /* -------------------------------------------- */

    function initialize() external {
        // initialize
        require(!_storage()._initialized, "Already initialized");
        _storage()._initialized = true;

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
    function _storage() internal pure returns (RouxAdministrationStorage storage $) {
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
        return _storage()._balance[edition][tokenId];
    }

    /**
     * @inheritdoc IRouxAdministrator
     */
    function balanceBatch(address edition, uint256[] calldata tokenIds) external view returns (uint256) {
        uint256 total;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            total += _storage()._balance[edition][tokenIds[i]];
        }
        return total;
    }

    /**
     * @inheritdoc IRouxAdministrator
     */
    function pending(address edition, uint256 tokenId) external view returns (uint256) {
        return _storage()._pending[edition][tokenId];
    }

    /**
     * @inheritdoc IRouxAdministrator
     */
    function attribution(address edition, uint256 tokenId) external view returns (address, uint256) {
        RouxAdministrationStorage storage $ = _storage();

        address parentEdition = $._administrationData[edition][tokenId].parentEdition;
        uint256 parentTokenId = $._administrationData[edition][tokenId].parentTokenId;

        return (parentEdition, parentTokenId);
    }

    /**
     * @inheritdoc IRouxAdministrator
     */
    function root(address edition, uint256 tokenId) external view returns (address, uint256, uint256) {
        return _root(edition, tokenId, 0);
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /**
     * @inheritdoc IRouxAdministrator
     */
    function setAdministrationData(
        uint256 tokenId,
        address parentEdition,
        uint256 parentTokenId,
        address fundsRecipient,
        uint16 profitShare
    )
        external
    {
        // get current depth of parent edition and tokenId
        (,, uint256 depth) = _root(parentEdition, parentTokenId, 0);

        // revert if funds recipient is zero address
        if (fundsRecipient == address(0)) revert InvalidFundsRecipient();

        // revert if addition exceeds max depth
        if (depth + 1 > MAX_DEPTH) revert MaxDepthExceeded();

        // revert if profit share exceeds basis point scale
        if (profitShare > BASIS_POINT_SCALE) revert InvalidProfitShare();

        // set attribution for edition + token id
        AdministrationData storage d = _storage()._administrationData[msg.sender][tokenId];

        d.parentEdition = parentEdition;
        d.parentTokenId = parentTokenId;
        d.fundsRecipient = fundsRecipient;
        d.profitShare = profitShare;
    }

    /**
     * @inheritdoc IRouxAdministrator
     */
    function disburseMint(uint256 tokenId) external payable {
        // handle mint fee
        uint192 fee;
        if (_storage()._enableMintFee) {
            fee = ((msg.value * MINT_FEE) / BASIS_POINT_SCALE).toUint192();
            _storage()._mintFeeBalance += fee;
        }

        // disburse
        _disburse(msg.sender, tokenId, msg.value - fee);
    }

    /**
     * @inheritdoc IRouxAdministrator
     */
    function withdraw(address edition, uint256 tokenId) external returns (uint256) {
        // get storage
        RouxAdministrationStorage storage $ = _storage();

        // cache edition's funds recipient
        address fundsRecipient = $._administrationData[edition][tokenId].fundsRecipient;

        // disburse pending balance
        uint256 pendingBalance = $._pending[edition][tokenId];
        _disburse(edition, tokenId, pendingBalance);

        // cache balance
        uint256 amount = $._balance[edition][tokenId];

        // decrement balance
        $._balance[edition][tokenId] -= amount;

        // transfer to funding recipient
        (bool success,) = fundsRecipient.call{ value: amount }("");
        if (!success) revert TransferFailed();

        emit Withdrawn(edition, tokenId, amount);

        return amount;
    }

    /**
     * @inheritdoc IRouxAdministrator
     */
    function withdrawBatch(address edition, uint256[] calldata tokenIds) external returns (uint256) {
        // get storage
        RouxAdministrationStorage storage $ = _storage();

        // cache funding recipient
        address fundsRecipient = $._administrationData[edition][tokenIds[0]].fundsRecipient;

        // validate funding recipient
        if (fundsRecipient == address(0)) revert InvalidFundsRecipient();

        // disburse pending balances
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _disburse(edition, tokenIds[i], $._pending[edition][tokenIds[i]]);
        }

        // compute balance
        uint256 amount;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            // validate funding recipient
            if ($._administrationData[edition][tokenIds[i]].fundsRecipient != fundsRecipient) {
                revert InvalidFundsRecipient();
            }

            // decrement balance
            uint256 tokenAmount = $._balance[edition][tokenIds[i]];
            amount += tokenAmount;
            $._balance[edition][tokenIds[i]] -= tokenAmount;
        }

        // transfer to funding recipient
        (bool success,) = fundsRecipient.call{ value: amount }("");
        if (!success) revert TransferFailed();

        emit WithdrawnBatch(edition, tokenIds, amount);

        return amount;
    }

    /* -------------------------------------------- */
    /* admin                                        */
    /* -------------------------------------------- */

    /**
     * @notice enable mint fee
     * @param enable enable mint fee boolean
     */
    function enableMintFee(bool enable) external onlyOwner {
        _storage()._enableMintFee = enable;
    }

    /**
     * @notice withdraw mint fee
     * @param to recipient
     */
    function withdrawMintFee(address to) external onlyOwner returns (uint256) {
        // get storage
        RouxAdministrationStorage storage $ = _storage();

        // cache mint fee balance
        uint256 amount = $._mintFeeBalance;

        // reset mint fee balance
        $._mintFeeBalance = 0;

        // transfer to owner
        (bool success,) = to.call{ value: amount }("");
        if (!success) revert TransferFailed();

        return amount;
    }

    /* -------------------------------------------- */
    /* proxy                                        */
    /* -------------------------------------------- */

    /**
     * @notice get proxy implementation
     * @return implementation address
     */
    function getImplementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    /**
     * @notice upgrade proxy
     * @param newImplementation new implementation contract
     * @param data optional calldata
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
        RouxAdministrationStorage storage $ = _storage();

        // if root, return edition and tokenId
        if ($._administrationData[edition][tokenId].parentEdition == address(0)) {
            return (edition, tokenId, depth);
        } else {
            // if not root, recursively call this function with parent data, incrementing depth
            return _root(
                $._administrationData[edition][tokenId].parentEdition,
                $._administrationData[edition][tokenId].parentTokenId,
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
        RouxAdministrationStorage storage $ = _storage();

        // cache parent data
        address parentEdition = $._administrationData[edition][tokenId].parentEdition;
        uint256 parentTokenId = $._administrationData[edition][tokenId].parentTokenId;

        // if root, increment balance and return same edition and token id
        if (parentEdition == address(0)) {
            $._balance[edition][tokenId] += amount;
            emit Disbursement(edition, tokenId, amount);
        } else {
            // if not root, compute split, disburse to current edition and increment pending for parent
            // compute disbursement amounts
            (uint256 currentEditionShare, uint256 parentShare) = _computeSplit(edition, tokenId, amount);

            // increment currentEdition balance by its share
            $._balance[edition][tokenId] += currentEditionShare;

            // increment the parent's pending balance - will be disbursed when parent withdraws
            $._pending[parentEdition][parentTokenId] += parentShare;

            emit Disbursement(edition, tokenId, currentEditionShare);
            emit PendingUpdated(edition, tokenId, parentEdition, parentTokenId, parentShare);
        }
    }

    /**
     * @notice helper function to compute split for a token
     * @param edition edition
     * @param tokenId token id
     * @param amount proceeds
     * @return edition share
     * @return parent edition share
     */
    function _computeSplit(address edition, uint256 tokenId, uint256 amount) internal view returns (uint256, uint256) {
        // get storage
        RouxAdministrationStorage storage $ = _storage();

        // cache parent data
        address parentEdition = $._administrationData[edition][tokenId].parentEdition;
        uint256 parentTokenId = $._administrationData[edition][tokenId].parentTokenId;

        // get profit share from parent
        uint256 parentProfitShareBps = $._administrationData[parentEdition][parentTokenId].profitShare;

        // calculate share of proceeds
        uint256 currentEditionShare = (amount * parentProfitShareBps) / BASIS_POINT_SCALE;
        uint256 parentShare = amount - currentEditionShare;

        return (currentEditionShare, parentShare);
    }
}
