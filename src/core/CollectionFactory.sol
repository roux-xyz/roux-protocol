// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { ICollectionFactory } from "src/core/interfaces/ICollectionFactory.sol";
import { ICollection } from "src/core/interfaces/ICollection.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { ReentrancyGuard } from "solady/utils/ReentrancyGuard.sol";
import { LibBitmap } from "solady/utils/LibBitmap.sol";
import { Initializable } from "solady/utils/Initializable.sol";
import { CollectionData } from "src/types/DataTypes.sol";
import { SingleEditionCollection } from "src/core/SingleEditionCollection.sol";
import { MultiEditionCollection } from "src/core/MultiEditionCollection.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";

/**
 * @title collection factory
 * @author roux
 * @custom:security-contact security@roux.app
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

    /// @notice version
    string public constant VERSION = "1.0";

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
     * @param deployerNonce mapping of deployer to nonce
     * @param totalCollections total number of collections
     */
    struct CollectionFactoryStorage {
        LibBitmap.Bitmap collections;
        mapping(address => uint256) deployerNonce;
        uint256 totalCollections;
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

    /// @inheritdoc ICollectionFactory
    function totalCollections() external view returns (uint256) {
        return _storage().totalCollections;
    }

    /* ------------------------------------------------- */
    /* write                                             */
    /* ------------------------------------------------- */

    /**
     * @notice create new single edition collection
     * @param params parameters for creating the single edition collection
     * @return collectionInstance the address of the newly created collection
     */
    function createSingle(CollectionData.SingleEditionCreateParams calldata params) external returns (address) {
        CollectionFactoryStorage storage $ = _storage();

        // get and increment the deployer's nonce
        uint256 nonce = $.deployerNonce[msg.sender]++;

        // calculate salt using msg.sender and their nonce
        bytes32 salt = keccak256(abi.encodePacked(msg.sender, nonce));

        // create initialization data for the proxy
        bytes memory initData = abi.encodeWithSelector(SingleEditionCollection.initialize.selector, params);

        // prepare the bytecode for the BeaconProxy contract
        bytes memory proxyBytecode =
            abi.encodePacked(type(BeaconProxy).creationCode, abi.encode(_singleEditionCollectionBeacon, initData));

        // deploy the proxy using Create2
        address collectionInstance = Create2.deploy(0, salt, proxyBytecode);

        // process the creation (set curator, transfer ownership, register the collection)
        _processCreate(collectionInstance);

        // increment total collections
        $.totalCollections++;

        // emit event for the new collection
        emit EventsLib.NewSingleEditionCollection(collectionInstance);

        return collectionInstance;
    }

    /**
     * @notice creates a new multi-edition collection
     * @param params parameters for creating the multi-edition collection
     * @return collectionInstance the address of the newly created collection
     */
    function createMulti(CollectionData.MultiEditionCreateParams calldata params) external returns (address) {
        CollectionFactoryStorage storage $ = _storage();

        // get and increment the deployer's nonce
        uint256 nonce = $.deployerNonce[msg.sender]++;

        // calculate salt using msg.sender and their nonce
        bytes32 salt = keccak256(abi.encodePacked(msg.sender, nonce));

        // create initialization data for the proxy
        bytes memory initData = abi.encodeWithSelector(MultiEditionCollection.initialize.selector, params);

        // prepare the bytecode for the BeaconProxy contract
        bytes memory proxyBytecode =
            abi.encodePacked(type(BeaconProxy).creationCode, abi.encode(_multiEditionCollectionBeacon, initData));

        // deploy the proxy using Create2
        address collectionInstance = Create2.deploy(0, salt, proxyBytecode);

        // process the creation (set curator, transfer ownership, register the collection)
        _processCreate(collectionInstance);

        // increment total collections
        $.totalCollections++;

        // emit event for the new collection
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
