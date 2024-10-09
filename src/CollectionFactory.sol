// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { ICollectionFactory } from "src/interfaces/ICollectionFactory.sol";
import { ICollection } from "src/interfaces/ICollection.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { ReentrancyGuard } from "solady/utils/ReentrancyGuard.sol";
import { LibBitmap } from "solady/utils/LibBitmap.sol";
import { Initializable } from "solady/utils/Initializable.sol";
import { CollectionData } from "src/types/DataTypes.sol";
import { SingleEditionCollection } from "src/SingleEditionCollection.sol";
import { MultiEditionCollection } from "src/MultiEditionCollection.sol";

/**
 * @title collection factory
 * @author roux
 * @custom:version 1.0
 * @custom:security-contact mp@roux.app
 */
contract CollectionFactory is ICollectionFactory, Initializable, Ownable, ReentrancyGuard {
    using LibBitmap for LibBitmap.Bitmap;

    /* ------------------------------------------------- */
    /* constants                                         */
    /* ------------------------------------------------- */

    /**
     * @notice CollectionFactory storage slot
     * @dev keccak256(abi.encode(uint256(keccak256("collectionFactory.collectionFactoryStorage")) - 1)) &
     * ~bytes32(uint256(0xff));
     */
    bytes32 internal constant COLLECTION_FACTORY_STORAGE_SLOT =
        0xfee14c31ff75da4316c29dbb9be5262c4ac5f24d7a6cf9c42a613a69199feb00;

    /* ------------------------------------------------- */
    /* immutable state                                   */
    /* ------------------------------------------------- */

    /// @notice single edition collection beacon
    address internal immutable _singleEditionCollectionBeacon;

    /// @notice multi edition collection beacon
    address internal immutable _multiEditionCollectionBeacon;

    /* ------------------------------------------------- */
    /* structures                                        */
    /* ------------------------------------------------- */

    /**
     * @notice CollectionFactory storage
     * @custom:storage-location erc7201:collectionFactory.collectionFactoryStorage
     * @param collections set of collections
     */
    struct CollectionFactoryStorage {
        LibBitmap.Bitmap collections;
    }

    /* ------------------------------------------------- */
    /* constructor                                       */
    /* ------------------------------------------------- */

    /**
     * @notice Initializes the CollectionFactory with the given beacons.
     * @param singleEditionCollectionBeacon Beacon address for single edition collections.
     * @param multiEditionCollectionBeacon Beacon address for multi-edition collections.
     */
    constructor(address singleEditionCollectionBeacon, address multiEditionCollectionBeacon) {
        // disable initialization of implementation contract
        _disableInitializers();

        // set single edition collection beacon
        _singleEditionCollectionBeacon = singleEditionCollectionBeacon;

        // set multi edition collection beacon
        _multiEditionCollectionBeacon = multiEditionCollectionBeacon;

        // renounce ownership of implementation contract
        _initializeOwner(msg.sender);
        renounceOwnership();
    }

    /* ------------------------------------------------- */
    /* initializer                                       */
    /* ------------------------------------------------- */

    /// @notice initialize CollectionFactory
    function initialize() external initializer {
        // set owner of proxy
        _initializeOwner(msg.sender);
    }

    /* ------------------------------------------------- */
    /* storage                                           */
    /* ------------------------------------------------- */

    /**
     * @notice get CollectionFactoryStorage storage location
     * @return $ CollectionFactory storage location
     */
    function _storage() internal pure returns (CollectionFactoryStorage storage $) {
        assembly {
            $.slot := COLLECTION_FACTORY_STORAGE_SLOT
        }
    }

    /* ------------------------------------------------- */
    /* view                                              */
    /* ------------------------------------------------- */

    /**
     * @notice checks if an address is a collection created by this factory
     * @param collection The address to check
     * @return true if the address is a collection, false otherwise
     */
    function isCollection(address collection) external view returns (bool) {
        return _storage().collections.get(uint256(uint160(collection)));
    }

    /* ------------------------------------------------- */
    /* write                                             */
    /* ------------------------------------------------- */

    /**
     * @notice create new single edition collection
     * @param params parameters for creating the single edition collection
     * @return collectionInstance the address of the newly created collection
     */
    function createSingle(CollectionData.SingleEditionCreateParams calldata params)
        external
        returns (address collectionInstance)
    {
        // create the collection instance using the single edition beacon
        collectionInstance = address(
            new BeaconProxy(
                _singleEditionCollectionBeacon,
                abi.encodeWithSelector(SingleEditionCollection.initialize.selector, params)
            )
        );

        // set curator, transfer ownership to the caller, and register the new collection
        _processCreate(collectionInstance);

        // emit an event for the new collection
        emit EventsLib.NewSingleEditionCollection(collectionInstance);

        return collectionInstance;
    }

    /**
     * @notice creates a new multi-edition collection
     * @param params parameters for creating the multi-edition collection
     * @return collectionInstance the address of the newly created collection
     */
    function createMulti(CollectionData.MultiEditionCreateParams calldata params)
        external
        returns (address collectionInstance)
    {
        // create the collection instance using the multi-edition beacon
        collectionInstance = address(
            new BeaconProxy(
                _multiEditionCollectionBeacon,
                abi.encodeWithSelector(MultiEditionCollection.initialize.selector, params)
            )
        );

        // set curator, transfer ownership to the caller, and register the new collection
        _processCreate(collectionInstance);

        // emit an event for the new collection
        emit EventsLib.NewMultiEditionCollection(collectionInstance);

        return collectionInstance;
    }

    /* ------------------------------------------------- */
    /* proxy                                             */
    /* ------------------------------------------------- */

    /**
     * @notice gets the implementation address of the proxy
     * @return the implementation address
     */
    function getImplementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    /**
     * @notice upgrades the proxy to a new implementation
     * @param newImplementation the new implementation address
     * @param data optional data to call on the new implementation
     */
    function upgradeToAndCall(address newImplementation, bytes calldata data) external onlyOwner {
        ERC1967Utils.upgradeToAndCall(newImplementation, data);
    }

    /* ------------------------------------------------- */
    /* internal                                          */
    /* ------------------------------------------------- */

    /**
     * @notice process create calls
     */
    function _processCreate(address collectionInstance) internal {
        CollectionFactoryStorage storage $ = _storage();

        // set the curator and transfer ownership to the caller
        ICollection(collectionInstance).setCurator(msg.sender);
        Ownable(collectionInstance).transferOwnership(msg.sender);

        // register the new collection
        $.collections.set(uint256(uint160(collectionInstance)));
    }
}
