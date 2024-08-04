// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IController } from "src/interfaces/IController.sol";
import { IRegistry } from "src/interfaces/IRegistry.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";

import { Initializable } from "solady/utils/Initializable.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ReentrancyGuard } from "solady/utils/ReentrancyGuard.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import { BASIS_POINT_SCALE } from "src/libraries/ConstantsLib.sol";
import { PLATFORM_FEE, REFERRAL_FEE } from "src/libraries/FeesLib.sol";

/**
 * @title controller
 * @author roux
 * @custom:version 1.0
 * @custom:security-contact mp@roux.app
 */
contract Controller is IController, Initializable, OwnableRoles, ReentrancyGuard {
    using SafeCast for uint256;
    using SafeERC20 for IERC20;

    /* ------------------------------------------------- */
    /* constants                                         */
    /* ------------------------------------------------- */

    /**
     * @notice Controller storage slot
     * @dev keccak256(abi.encode(uint256(keccak256("rouxController.controllerStorage")) - 1)) & ~bytes32(uint256(0xff));
     */
    bytes32 internal constant ROUX_CONTROLLER_STORAGE_SLOT =
        0x6ee44408b62b797b2b3f7454b8d82b4275ea0345c9fb009071c08e21e5ce6a00;

    /// @notice registry
    IRegistry internal immutable _registry;

    /**
     * @notice currency
     * @dev if the protocol's base currency needs to be changed, a new controller implementation and
     *      proxy must be deployed, ensuring existing balances can be withdrawn. the RouxEdition
     *      implementation must be upgraded to use the new controller implementation.
     */
    IERC20 internal immutable _currency;

    /* ------------------------------------------------- */
    /* structures                                        */
    /* ------------------------------------------------- */

    /**
     * @notice token config
     * @param fundsRecipient funds recipient
     * @param profitShare profit share
     */
    struct TokenConfig {
        address fundsRecipient;
        uint16 profitShare;
    }

    /**
     * @notice controller storage
     * @custom:storage-location erc7201:rouxController.cntrollerStorage
     * @param paused whether the contract is paused
     * @param platformFeeEnabled whether platform fee is enabled
     * @param platformFeeBalance platform fee balance
     * @param tokenConfig token data
     * @param tokenPending token pending
     * @param balance balance
     */
    struct ControllerStorage {
        bool paused;
        bool platformFeeEnabled;
        uint192 platformFeeBalance;
        mapping(address edition => mapping(uint256 tokenId => TokenConfig)) tokenConfig;
        mapping(address edition => mapping(uint256 tokenId => uint256 amount)) tokenPending;
        mapping(address fundsRecipient => uint256 balance) balance;
    }

    /* ------------------------------------------------- */
    /* modifiers                                         */
    /* ------------------------------------------------- */

    /// @notice revert when paused
    modifier notPaused() {
        if (_storage().paused) revert ErrorsLib.Controller_Paused();
        _;
    }

    /* ------------------------------------------------- */
    /* constructor                                       */
    /* ------------------------------------------------- */

    /**
     * @notice constructor
     * @param registry registry address
     * @param currency_ currency address
     */
    constructor(address registry, address currency_) {
        // disable initialization of implementation contract
        _disableInitializers();

        _initializeOwner(msg.sender);

        _registry = IRegistry(registry);
        _currency = IERC20(currency_);

        // renounce ownership of implementation contract
        renounceOwnership();
    }

    /* ------------------------------------------------- */
    /* initializer                                       */
    /* ------------------------------------------------- */

    /// @notice initialize
    function initialize() external initializer nonReentrant {
        // set owner of the proxy
        _initializeOwner(msg.sender);
    }

    /* ------------------------------------------------- */
    /* storage                                           */
    /* ------------------------------------------------- */

    /**
     * @notice get Controller storage location
     * @return $ Controller storage location
     */
    function _storage() internal pure returns (ControllerStorage storage $) {
        assembly {
            $.slot := ROUX_CONTROLLER_STORAGE_SLOT
        }
    }

    /* ------------------------------------------------- */
    /* view                                              */
    /* ------------------------------------------------- */

    /// @inheritdoc IController
    function currency() external view returns (address) {
        return address(_currency);
    }

    /// @inheritdoc IController
    function decimals() external view returns (uint8) {
        return IERC20Metadata(address(_currency)).decimals();
    }

    /// @inheritdoc IController
    function balance(address recipient) external view returns (uint256) {
        return _storage().balance[recipient];
    }

    /// @inheritdoc IController
    function pending(address edition, uint256 tokenId) external view returns (uint256) {
        return _storage().tokenPending[edition][tokenId];
    }

    /// @inheritdoc IController
    function platformFeeBalance() external view returns (uint256) {
        return _storage().platformFeeBalance;
    }

    /// @inheritdoc IController
    function profitShare(address edition, uint256 tokenId) external view returns (uint256) {
        return _storage().tokenConfig[edition][tokenId].profitShare;
    }

    /// @inheritdoc IController
    function fundsRecipient(address edition, uint256 tokenId) external view returns (address) {
        return _storage().tokenConfig[edition][tokenId].fundsRecipient;
    }

    /* ------------------------------------------------- */
    /* write                                             */
    /* ------------------------------------------------- */

    /// @inheritdoc IController
    function disburse(
        address edition,
        uint256 id,
        uint256 amount,
        address referrer
    )
        external
        payable
        nonReentrant
        notPaused
    {
        // transfer payment
        _transferPayment(msg.sender, amount);

        // handle platform fee
        uint192 fee;
        if (_storage().platformFeeEnabled) {
            fee = ((amount * PLATFORM_FEE) / BASIS_POINT_SCALE).toUint192();
            unchecked {
                _storage().platformFeeBalance += fee;
            }
        }

        // handle referral fee
        uint192 referralFee;
        if (referrer != address(0)) {
            referralFee = ((amount * REFERRAL_FEE) / BASIS_POINT_SCALE).toUint192();
            unchecked {
                _storage().balance[referrer] += referralFee;
            }
        }

        // disburse
        _disburse(edition, id, amount - fee - referralFee);
    }

    /// @inheritdoc IController
    function recordFunds(address recipient, uint256 amount) external payable nonReentrant notPaused {
        // don't send to zero address
        if (recipient == address(0)) revert ErrorsLib.Controller_InvalidFundsRecipient();

        // transfer payment
        _transferPayment(msg.sender, amount);

        // record funds
        unchecked {
            _storage().balance[recipient] += amount;
        }

        // from, to, amount
        emit EventsLib.FundsRecorded(msg.sender, recipient, amount);
    }

    /// @inheritdoc IController
    function distributePending(address edition, uint256 tokenId) external notPaused {
        // distribute pending balance (updates balance and parent's pending balance)
        _distributePending(edition, tokenId);
    }

    /// @inheritdoc IController
    function distributePendingBatch(address[] calldata editions, uint256[] calldata tokenIds) external notPaused {
        // validate arrays
        if (editions.length != tokenIds.length) revert ErrorsLib.Controller_InvalidArrayLength();

        for (uint256 i = 0; i < tokenIds.length; ++i) {
            // distribute pending balance
            _distributePending(editions[i], tokenIds[i]);
        }
    }

    /// @inheritdoc IController
    function distributePendingAndWithdraw(
        address edition,
        uint256 tokenId
    )
        external
        nonReentrant
        notPaused
        returns (uint256)
    {
        // distribute pending balance
        _distributePending(edition, tokenId);

        // withdraw
        return _withdraw(_storage().tokenConfig[edition][tokenId].fundsRecipient);
    }

    /// @inheritdoc IController
    function withdraw(address recipient) external nonReentrant notPaused returns (uint256) {
        return _withdraw(recipient);
    }

    /// @inheritdoc IController
    function setFundsRecipient(uint256 tokenId, address fundsRecipient_) external notPaused {
        _setFundsRecipient(msg.sender, tokenId, fundsRecipient_);
    }

    /// @inheritdoc IController
    function setProfitShare(uint256 tokenId, uint16 profitShare_) external notPaused {
        _setProfitShare(msg.sender, tokenId, profitShare_);
    }

    /// @inheritdoc IController
    function setControllerData(uint256 tokenId, address fundsRecipient_, uint16 profitShare_) external notPaused {
        _setFundsRecipient(msg.sender, tokenId, fundsRecipient_);
        _setProfitShare(msg.sender, tokenId, profitShare_);
    }

    /* ------------------------------------------------- */
    /* admin                                             */
    /* ------------------------------------------------- */

    /**
     * @notice enable mint fee
     * @param enable enable mint fee boolean
     */
    function enablePlatformFee(bool enable) external onlyOwner {
        _storage().platformFeeEnabled = enable;

        emit EventsLib.PlatformFeeUpdated(enable);
    }

    /**
     * @notice withdraw mint fee
     * @param to recipient
     */
    function withdrawPlatformFee(address to) external onlyOwner nonReentrant returns (uint256) {
        // get storage
        ControllerStorage storage $ = _storage();

        // cache mint fee balance
        uint256 amount = $.platformFeeBalance;

        // reset mint fee balance
        $.platformFeeBalance = 0;

        // transfer to owner
        _currency.safeTransfer(to, amount);

        return amount;
    }

    /**
     * @notice pause
     * @param pause_ true to pause, false to unpause
     */
    function pause(bool pause_) external onlyOwner {
        _storage().paused = pause_;

        emit EventsLib.Paused(pause_);
    }

    /* ------------------------------------------------- */
    /* proxy                                             */
    /* ------------------------------------------------- */

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

    /* ------------------------------------------------- */
    /* internal                                          */
    /* ------------------------------------------------- */

    /**
     * @notice handle transfer payment
     * @param from sender
     * @param amount amount
     *
     * @dev does not support fee-on-transfer tokens
     */
    function _transferPayment(address from, uint256 amount) internal {
        // transfer currency
        _currency.safeTransferFrom(from, address(this), amount);
    }

    /**
     * @notice distribute pending balance
     * @param edition edition
     * @param tokenId token id
     */
    function _distributePending(address edition, uint256 tokenId) internal {
        // get storage
        ControllerStorage storage $ = _storage();

        // pending balance
        uint256 pendingBalance = $.tokenPending[edition][tokenId];

        // set pending balance to zero
        $.tokenPending[edition][tokenId] = 0;

        // distribute pending balance (updates balance and parent's pending balance)
        _disburse(edition, tokenId, pendingBalance);

        // edition, id, amount
        emit EventsLib.PendingDistributed(edition, tokenId, pendingBalance);
    }

    /**
     * @notice distribute proceeds to funds recipient balance and parent pending balance
     * @param edition edition
     * @param tokenId token id
     * @param amount proceeds to disburse
     *
     * @dev profit share is set by the parent edition, and represents the percentage of the
     *      proceeds earned by the child edition, with the remainder going to the parent
     */
    function _disburse(address edition, uint256 tokenId, uint256 amount) internal {
        // get storage
        ControllerStorage storage $ = _storage();

        // retrieve parent data
        (address parentEdition, uint256 parentTokenId) = _registry.attribution(edition, tokenId);

        // get recipient
        address recipient = $.tokenConfig[edition][tokenId].fundsRecipient;

        // if root, increment recipient's balance
        if (parentEdition == address(0)) {
            // increment recipient's balance
            unchecked {
                $.balance[recipient] += amount;
            }

            // emit Deposited event
            emit EventsLib.Deposited(edition, tokenId, recipient, amount);
        } else {
            // if not root, compute split, increment balance for current edition and increment pending for parent
            uint256 currentEditionProfitShare = $.tokenConfig[parentEdition][parentTokenId].profitShare;

            // calculate share of proceeds
            uint256 currentEditionShare = (amount * currentEditionProfitShare) / BASIS_POINT_SCALE;
            uint256 parentShare = amount - currentEditionShare;

            unchecked {
                // increment recipient's balance
                $.balance[recipient] += currentEditionShare;
                // increment the parent's pending balance
                $.tokenPending[parentEdition][parentTokenId] += parentShare;
            }

            // emit Deposited event
            emit EventsLib.Deposited(edition, tokenId, recipient, currentEditionShare);

            // emit PendingUpdated event
            emit EventsLib.PendingUpdated(parentEdition, parentTokenId, parentShare);
        }
    }

    /**
     * @notice withdraw
     * @param recipient recipient
     * @return amount amount withdrawn
     *
     * @dev anyone can withdraw on behalf of recipient
     */
    function _withdraw(address recipient) internal returns (uint256) {
        // get storage
        ControllerStorage storage $ = _storage();

        // cache balance
        uint256 amount = $.balance[recipient];

        // decrement balance
        $.balance[recipient] -= amount;

        // transfer to funding recipient
        _currency.safeTransfer(recipient, amount);

        emit EventsLib.Withdrawn(recipient, amount);

        return amount;
    }

    /**
     * @notice set funds recipient
     * @param edition edition
     * @param tokenId token id
     * @param fundsRecipient_ funds recipient
     */
    function _setFundsRecipient(address edition, uint256 tokenId, address fundsRecipient_) internal {
        // revert if funds recipient is set to zero address
        if (fundsRecipient_ == address(0)) revert ErrorsLib.Controller_InvalidFundsRecipient();

        // set funds recipient
        _storage().tokenConfig[edition][tokenId].fundsRecipient = fundsRecipient_;

        emit EventsLib.FundsRecipientUpdated(edition, tokenId, fundsRecipient_);
    }

    /**
     * @notice set profit share
     * @param edition edition
     * @param tokenId token id
     * @param profitShare_ profit share
     */
    function _setProfitShare(address edition, uint256 tokenId, uint16 profitShare_) internal {
        // get storage
        ControllerStorage storage $ = _storage();

        // revert if profit share is decreased
        if (profitShare_ > BASIS_POINT_SCALE || profitShare_ < $.tokenConfig[edition][tokenId].profitShare) {
            revert ErrorsLib.Controller_InvalidProfitShare();
        }

        // set profit share
        $.tokenConfig[edition][tokenId].profitShare = profitShare_;

        emit EventsLib.ProfitShareUpdated(edition, tokenId, profitShare_);
    }
}
