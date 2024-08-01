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

import { CollectionData } from "src/types/DataTypes.sol";

/**
 * @title Collection Factory
 * @custom:version 0.1
 */
contract CollectionFactory is ICollectionFactory, Ownable, ReentrancyGuard {
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
     * @param initialized whether the contract has been initialized
     * @param collectionImplementation collection implementation
     * @param collections set of collections
     * @param allowlist allowlist of collections
     * @param enableAllowlist whether to enable allowlist
     */
    struct CollectionFactoryStorage {
        bool initialized;
        address collectionImplementation;
        LibBitmap.Bitmap collections;
        mapping(address => bool) allowlist;
        bool enableAllowlist;
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
        CollectionFactoryStorage storage $ = _storage();

        // disable initialization of implementation contract
        require(!$.initialized, "Already initialized");
        $.initialized = true;

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
    function initialize() external {
        CollectionFactoryStorage storage $ = _storage();

        require(!$.initialized, "Already initialized");
        $.initialized = true;

        // set owner of proxy
        _initializeOwner(msg.sender);

        // enable allowlist
        $.enableAllowlist = true;
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

        // verify allowlist
        if ($.enableAllowlist && !$.allowlist[msg.sender]) revert ErrorsLib.CollectionFactory_OnlyAllowlist();

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

    /* ------------------------------------------------- */
    /* Admin                                             */
    /* ------------------------------------------------- */

    /**
     * @notice set allowlist to enabled or disabled
     * @param enable whether to enable allowlist
     */
    function setAllowlist(bool enable) external onlyOwner {
        _storage().enableAllowlist = enable;
    }

    /**
     * @notice add accounts to allowlist
     * @param accounts accounts to add to allowlist
     */
    function addAllowlist(address[] memory accounts) external onlyOwner {
        CollectionFactoryStorage storage $ = _storage();

        for (uint256 i = 0; i < accounts.length; i++) {
            $.allowlist[accounts[i]] = true;
        }
    }

    /**
     * @notice remove account from allowlist
     * @param account  acuount to remove from allowlist
     */
    function removeAllowlist(address account) external onlyOwner {
        _storage().allowlist[account] = false;
    }

    /* -------------------------------------------- */
    /* proxy | danger zone                          */
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
