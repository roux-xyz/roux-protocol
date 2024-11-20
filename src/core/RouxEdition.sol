// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { BaseRouxEdition } from "src/core/abstracts/BaseRouxEdition.sol";
import { IRouxEdition } from "src/core/interfaces/IRouxEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { Collection } from "src/core/abstracts/Collection.sol";
import { ICollection } from "src/core/interfaces/ICollection.sol";
import { LibBitmap } from "solady/utils/LibBitmap.sol";

/**
 * last mechanical art
 *
 * 3/4 oz mezcal
 * 3/4 oz cynar
 * 3/4 oz campari
 * 3/4 oz punt e mes
 *
 * stir, strain, up
 * garnish with orange peel
 */

/**
 * @title roux edition
 * @author roux
 * @custom:security-contact security@roux.app
 */
contract RouxEdition is BaseRouxEdition {
    using LibBitmap for LibBitmap.Bitmap;

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
    /* view                                              */
    /* ------------------------------------------------- */

    /// @inheritdoc IRouxEdition
    function editionType() external pure override returns (EditionData.EditionType) {
        return EditionData.EditionType.Standard;
    }

    /* ------------------------------------------------- */
    /* admin                                             */
    /* ------------------------------------------------- */

    /// @inheritdoc IRouxEdition
    function add(EditionData.AddParams calldata p) external override onlyOwner nonReentrant returns (uint256) {
        return _add(p);
    }

    /**
     * @notice set collection
     * @param collection collection address
     * @param enable enable or disable collection
     *
     * @dev bypasses validation that token is ungated and exists; frontends should
     *      validate that token exists before calling this function as convenience
     */
    function setCollection(address collection, bool enable) external override onlyOwner {
        if (enable) {
            // validate extension is not zero
            if (collection == address(0)) revert ErrorsLib.RouxEdition_InvalidCollection();

            // owner of the collection must be the caller (safety check)
            if (Collection(collection).owner() != msg.sender) revert ErrorsLib.RouxEdition_InvalidCollection();

            // validate extension interface support
            if (!ICollection(collection).supportsInterface(type(ICollection).interfaceId)) {
                revert ErrorsLib.RouxEdition_InvalidCollection();
            }

            // set collection
            _storage().collections.set(uint256(uint160(collection)));
        } else {
            // unset collection
            _storage().collections.unset(uint256(uint160(collection)));
        }
        emit EventsLib.CollectionSet(collection, enable);
    }
}
