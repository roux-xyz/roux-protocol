// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { Ownable } from "solady/auth/Ownable.sol";

import { ICollectionFactory } from "src/interfaces/ICollectionFactory.sol";
import { ICollection } from "src/interfaces/ICollection.sol";

import { CollectionData } from "src/types/DataTypes.sol";

contract CollectionFactory is ICollectionFactory, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /* -------------------------------------------- */
    /* constants                                    */
    /* -------------------------------------------- */

    /**
     * @notice CollectionFactory storage slot
     * @dev keccak256(abi.encode(uint256(keccak256("erc7201:collectionFactory")) - 1)) & ~bytes32(uint256(0xff));
     */
    bytes32 internal constant COLLECTION_FACTORY_STORAGE_SLOT =
        0x3bee54bf8dcf3815b00f55fc51902a7f2123547f0c25caf07819e74a6fab0700;

    /* -------------------------------------------- */
    /* structures                                   */
    /* -------------------------------------------- */

    struct CollectionFactoryStorage {
        bool _initialized;
        EnumerableSet.AddressSet _collections;
        address _collectionImplementation;
        mapping(address => bool) _allowlist;
    }

    /* -------------------------------------------- */
    /* immutable state                              */
    /* -------------------------------------------- */

    address internal immutable _singleEditionCollectionBeacon;

    address internal immutable _multiEditionCollectionBeacon;

    /* -------------------------------------------- */
    /* constructor                                  */
    /* -------------------------------------------- */

    constructor(address singleEditionCollectionBeacon, address multiEditionCollectionBeacon) {
        CollectionFactoryStorage storage $ = _storage();

        /* disable initialization of implementation contract */
        require(!$._initialized, "Already initialized");
        $._initialized = true;

        _singleEditionCollectionBeacon = singleEditionCollectionBeacon;
        _multiEditionCollectionBeacon = multiEditionCollectionBeacon;

        _initializeOwner(msg.sender);
        renounceOwnership();
    }

    /* -------------------------------------------- */
    /* initializer                                  */
    /* -------------------------------------------- */

    /**
     * @notice Initialize CollectionFactory
     */
    function initialize(address admin) external {
        CollectionFactoryStorage storage $ = _storage();

        require(!$._initialized, "Already initialized");
        $._initialized = true;

        // Set owner of proxy
        _initializeOwner(admin);
    }

    /* -------------------------------------------- */
    /* storage                                      */
    /* -------------------------------------------- */

    /**
     * @notice Get CollectionFactoryStorage storage location
     * @return $ CollectionFactory storage location
     */
    function _storage() internal pure returns (CollectionFactoryStorage storage $) {
        assembly {
            $.slot := COLLECTION_FACTORY_STORAGE_SLOT
        }
    }

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    function isCollection(address token) external view returns (bool) {
        CollectionFactoryStorage storage $ = _storage();

        return $._collections.contains(token);
    }

    function getCollections() external view returns (address[] memory) {
        CollectionFactoryStorage storage $ = _storage();

        return $._collections.values();
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    function create(CollectionData.CollectionType collectionType, bytes calldata params) external returns (address) {
        CollectionFactoryStorage storage $ = _storage();

        address beacon;
        if (collectionType == CollectionData.CollectionType.SingleEdition) {
            beacon = _singleEditionCollectionBeacon;
        } else if (collectionType == CollectionData.CollectionType.MultiEdition) {
            beacon = _multiEditionCollectionBeacon;
        } else {
            revert InvalidCollectionType();
        }

        address collectionInstance =
            address(new BeaconProxy(beacon, abi.encodeWithSignature("initialize(bytes)", params)));

        Ownable(collectionInstance).transferOwnership(msg.sender);

        $._collections.add(collectionInstance);

        emit NewCollection(collectionType, collectionInstance);

        return collectionInstance;
    }

    /* -------------------------------------------- */
    /* Admin                                        */
    /* -------------------------------------------- */

    // TODO: update create to use?
    function addAllowlist(address[] memory accounts) external onlyOwner {
        CollectionFactoryStorage storage $ = _storage();

        for (uint256 i = 0; i < accounts.length; i++) {
            $._allowlist[accounts[i]] = true;
        }
    }

    function removeAllowlist(address account) external onlyOwner {
        CollectionFactoryStorage storage $ = _storage();

        $._allowlist[account] = false;
    }

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
