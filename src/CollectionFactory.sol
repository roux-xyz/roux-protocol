// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

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
     * @notice constructor
     * @param singleEditionCollectionBeacon single edition collection beacon
     * @param multiEditionCollectionBeacon multi edition collection beacon
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
     * @notice Get CollectionFactoryStorage storage location
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

    /// @inheritdoc ICollectionFactory
    function isCollection(address collection) external view returns (bool) {
        return _storage().collections.get(uint256(uint160(collection)));
    }

    /* ------------------------------------------------- */
    /* write                                             */
    /* ------------------------------------------------- */

    /// @inheritdoc ICollectionFactory
    function create(CollectionData.CollectionType collectionType, bytes calldata params) external returns (address) {
        // disable multi edition collections for now
        // if (collectionType == CollectionData.CollectionType.MultiEdition) {
        //     revert("Multi edition collections are disabled");
        // }

        CollectionFactoryStorage storage $ = _storage();

        // set which collection beacon to create
        address beacon;
        if (collectionType == CollectionData.CollectionType.SingleEdition) {
            beacon = _singleEditionCollectionBeacon;
        } else if (collectionType == CollectionData.CollectionType.MultiEdition) {
            beacon = _multiEditionCollectionBeacon;
        } else {
            revert ErrorsLib.CollectionFactory_InvalidCollectionType();
        }

        // create collection instance
        address collectionInstance =
            address(new BeaconProxy(beacon, abi.encodeWithSignature("initialize(bytes)", params)));

        // set curator
        ICollection(collectionInstance).setCurator(msg.sender);

        // transfer ownership to caller
        Ownable(collectionInstance).transferOwnership(msg.sender);

        // add to collections mapping
        $.collections.set(uint256(uint160(collectionInstance)));

        // emit event
        if (collectionType == CollectionData.CollectionType.SingleEdition) {
            emit EventsLib.NewSingleEditionCollection(collectionInstance);
        } else {
            emit EventsLib.NewMultiEditionCollection(collectionInstance);
        }

        return collectionInstance;
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
}
