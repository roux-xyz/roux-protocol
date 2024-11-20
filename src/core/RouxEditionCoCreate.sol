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
 * @title roux edition co-cocreate
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
    /* structures                                    */
    /* ------------------------------------------------- */

    /**
     * @notice RouxEditionCoCreate storage
     * @custom:storage-location erc7201:rouxEditionCoCreate.rouxEditionCoCreateStorage
     * @param enabled enabled
     * @param allowedAddresses allowed addresses
     */
    struct RouxEditionCoCreateStorage {
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

    /* ------------------------------------------------- */
    /* write                                             */
    /* ------------------------------------------------- */

    /// @inheritdoc IRouxEdition
    function add(EditionData.AddParams calldata p) external override nonReentrant returns (uint256) {
        RouxEditionCoCreateStorage storage $$ = _storageCoCreate();

        if ($$.allowListEnabled && !$$.allowedAddresses.get(uint256(uint160(msg.sender)))) {
            revert ErrorsLib.RouxEditionCoCreate_NotAllowed();
        }

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
}
