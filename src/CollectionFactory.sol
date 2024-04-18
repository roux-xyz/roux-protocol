// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { Ownable } from "solady/auth/Ownable.sol";

import { ICollectionFactory } from "./interfaces/ICollectionFactory.sol";
import { Collection } from "src/Collection.sol";

/**
 * @title Collection Factory
 * @author Roux
 */
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

    address internal immutable _collectionBeacon;

    /* -------------------------------------------- */
    /* constructor                                  */
    /* -------------------------------------------- */

    constructor(address collectionBeacon) {
        CollectionFactoryStorage storage $ = _storage();

        /* disable initialization of implementation contract */
        require(!$._initialized, "Already initialized");
        $._initialized = true;

        _collectionBeacon = collectionBeacon;

        _initializeOwner(msg.sender);
        renounceOwnership();
    }

    /* -------------------------------------------- */
    /* initializer                                  */
    /* -------------------------------------------- */

    /**
     * @notice Initialize CollectionFactory
     */
    function initialize() external {
        CollectionFactoryStorage storage $ = _storage();

        require(!$._initialized, "Already initialized");
        $._initialized = true;

        /* Set owner of proxy */
        _initializeOwner(msg.sender);
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

    function create(bytes calldata params) external returns (address) {
        CollectionFactoryStorage storage $ = _storage();

        if (!$._allowlist[msg.sender]) revert OnlyAllowlist();

        address collectionInstance =
            address(new BeaconProxy(_collectionBeacon, abi.encodeWithSignature("initialize(bytes)", params)));

        Collection(collectionInstance).initializeCurator(msg.sender);
        Ownable(collectionInstance).transferOwnership(msg.sender);

        $._collections.add(collectionInstance);

        emit NewCollection(collectionInstance);

        return collectionInstance;
    }

    /* -------------------------------------------- */
    /* Admin                                        */
    /* -------------------------------------------- */

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
