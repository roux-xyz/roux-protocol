// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { BaseRouxEdition } from "src/core/abstracts/BaseRouxEdition.sol";
import { IRouxEdition } from "src/core/interfaces/IRouxEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";
import { LibBitmap } from "solady/utils/LibBitmap.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";

/**
 * italian heirloom
 *
 * 2 oz cynar
 * 1/2 oz blended scotch
 * 1/2 oz laphroaig 10 yr
 * pinch salt
 * 5 swaths of lemon peel
 *
 * build in mixing glass, expressing lemon peels and dropping them
 * into the glass
 *
 * stir and strain, served up
 *
 * garnish with lemon peel
 */

/**
 * @title roux edition co-create
 * @author roux
 * @custom:security-contact security@roux.app
 *
 * @dev co-create is a special edition type that does not enforce an `onlyOwner` modifier
 * on `add`. an allowlist can be optionally enabled and set for group co-creation.
 */
contract RouxEditionCoCreate is BaseRouxEdition {
    using LibBitmap for LibBitmap.Bitmap;

    /* ------------------------------------------------- */
    /* constants                                         */
    /* ------------------------------------------------- */

    /**
     * @notice RouxEdition storage slot
     * @dev keccak256(abi.encode(uint256(keccak256("rouxEditionCoCreate.rouxEditionCoCreateStorage")) - 1)) &
     * ~bytes32(uint256(0xff));
     */
    bytes32 internal constant ROUX_EDITION_CO_CREATE_STORAGE_SLOT =
        0xf8ba7ec7e39a3e47b5b1fcdc921632116b09fd1c7349da6a756bf89cc05f3b00;

    /* ------------------------------------------------- */
    /* structures                                     */
    /* ------------------------------------------------- */

    /**
     * @notice RouxEditionCoCreate storage
     * @custom:storage-location erc7201:rouxEditionCoCreate.rouxEditionCoCreateStorage
     * @param addWindowStart add window start
     * @param addWindowEnd add window end
     * @param maxAddsPerAddress max adds per address
     * @param addsPerAddress adds per address
     * @param allowListEnabled allowlist enabled
     * @param allowedAddresses allowed addresses
     */
    struct RouxEditionCoCreateStorage {
        uint40 addWindowStart;
        uint40 addWindowEnd;
        uint32 maxAddsPerAddress;
        mapping(address => uint32) addsPerAddress;
        bool allowListEnabled;
        LibBitmap.Bitmap allowedAddresses;
    }

    /* ------------------------------------------------- */
    /* constructor                                       */
    /* ------------------------------------------------- */

    /**
     * @notice constructor
     * @param editionFactory edition factory
     * @param collectionFactory collection factory
     * @param controller controller
     * @param registry registry
     */
    constructor(
        address editionFactory,
        address collectionFactory,
        address controller,
        address registry
    )
        BaseRouxEdition(editionFactory, collectionFactory, controller, registry)
    { }

    /* ------------------------------------------------- */
    /* initializer                                       */
    /* ------------------------------------------------- */

    /**
     * @notice initialize RouxEditionCoCreate
     * @param params encoded parameters
     */
    function initialize(bytes calldata params) external override initializer {
        // call parent initialize first
        _initialize(params);

        // get storage
        RouxEditionCoCreateStorage storage $$ = _storageCoCreate();

        // set default values
        $$.addWindowStart = uint40(block.timestamp);
        $$.addWindowEnd = uint40(block.timestamp + 14 days);
        $$.maxAddsPerAddress = 1;
    }

    /* ------------------------------------------------- */
    /* storage                                           */
    /* ------------------------------------------------- */

    /**
     * @notice get RouxEditionCoCreate storage location
     * @return $ RouxEditionCoCreate storage location
     */
    function _storageCoCreate() internal pure returns (RouxEditionCoCreateStorage storage $) {
        assembly {
            $.slot := ROUX_EDITION_CO_CREATE_STORAGE_SLOT
        }
    }

    /* ------------------------------------------------- */
    /* view                                              */
    /* ------------------------------------------------- */

    /// @inheritdoc IRouxEdition
    function editionType() external pure override returns (EditionData.EditionType) {
        return EditionData.EditionType.CoCreate;
    }

    /**
     * @notice is allowlist enabled
     * @return allowlist enabled
     */
    function isAllowlistEnabled() external view returns (bool) {
        return _storageCoCreate().allowListEnabled;
    }

    /**
     * @notice is allowlisted
     * @param account account
     * @return allowlisted
     */
    function isAllowlisted(address account) external view returns (bool) {
        RouxEditionCoCreateStorage storage $$ = _storageCoCreate();
        return !$$.allowListEnabled || $$.allowedAddresses.get(uint256(uint160(account)));
    }

    /**
     * @notice get add window
     * @return add window start
     * @return add window end
     */
    function addWindow() external view returns (uint40, uint40) {
        RouxEditionCoCreateStorage storage $$ = _storageCoCreate();
        return ($$.addWindowStart, $$.addWindowEnd);
    }

    /**
     * @notice get max adds per address
     * @return max adds per address
     */
    function maxAddsPerAddress() external view returns (uint32) {
        return _storageCoCreate().maxAddsPerAddress;
    }

    /**
     * @notice get adds per address
     * @param account account
     * @return adds per address
     */
    function getAddsPerAddress(address account) external view returns (uint32) {
        return _storageCoCreate().addsPerAddress[account];
    }

    /* ------------------------------------------------- */
    /* write                                             */
    /* ------------------------------------------------- */

    /// @inheritdoc IRouxEdition
    function add(EditionData.AddParams calldata p) external override nonReentrant returns (uint256) {
        RouxEditionCoCreateStorage storage $$ = _storageCoCreate();

        // check add window
        if (block.timestamp < $$.addWindowStart || block.timestamp > $$.addWindowEnd) {
            revert ErrorsLib.RouxEditionCoCreate_AddWindowClosed();
        }

        // check allowlist
        if ($$.allowListEnabled && !$$.allowedAddresses.get(uint256(uint160(msg.sender)))) {
            revert ErrorsLib.RouxEditionCoCreate_NotAllowed();
        }

        // check max adds per address
        if ($$.addsPerAddress[msg.sender] >= $$.maxAddsPerAddress) {
            revert ErrorsLib.RouxEditionCoCreate_MaxAddsPerAddressReached();
        }

        // update adds per address
        $$.addsPerAddress[msg.sender]++;

        return _add(p);
    }

    /* ------------------------------------------------- */
    /* admin                                             */
    /* ------------------------------------------------- */

    /**
     * @notice enable allowlist
     * @param enable enable
     */
    function enableAllowlist(bool enable) external onlyOwner {
        _storageCoCreate().allowListEnabled = enable;

        emit EventsLib.CoCreateAllowlistEnabled(enable);
    }

    /**
     * @notice add to allowlist
     * @param addresses addresses
     */
    function addToAllowlist(address[] calldata addresses) external onlyOwner {
        RouxEditionCoCreateStorage storage $$ = _storageCoCreate();
        for (uint256 i = 0; i < addresses.length; ++i) {
            $$.allowedAddresses.set(uint256(uint160(addresses[i])));
        }
    }

    /**
     * @notice remove from allowlist
     * @param account account
     */
    function removeFromAllowlist(address account) external onlyOwner {
        _storageCoCreate().allowedAddresses.unset(uint256(uint160(account)));
    }

    /**
     * @notice update add window
     * @param addWindowStart add window start
     * @param addWindowEnd add window end
     */
    function updateAddWindow(uint40 addWindowStart, uint40 addWindowEnd) external onlyOwner {
        RouxEditionCoCreateStorage storage $$ = _storageCoCreate();
        if (addWindowStart >= addWindowEnd) {
            revert ErrorsLib.RouxEditionCoCreate_InvalidAddWindow();
        }

        $$.addWindowStart = addWindowStart;
        $$.addWindowEnd = addWindowEnd;
    }

    /**
     * @notice update max adds per address
     * @param maxAddsPerAddress_ max adds per address
     */
    function updateMaxAddsPerAddress(uint32 maxAddsPerAddress_) external onlyOwner {
        _storageCoCreate().maxAddsPerAddress = maxAddsPerAddress_;
    }

    /// @dev collections not allowed for co-create editions
    function setCollection(address, bool) external view override onlyOwner {
        revert ErrorsLib.RouxEditionCoCreate_NotAllowed();
    }
}
