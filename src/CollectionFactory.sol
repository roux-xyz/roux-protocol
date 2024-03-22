// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

import { ICollectionFactory } from "./interfaces/ICollectionFactory.sol";

contract CollectionFactory is ICollectionFactory {
    using EnumerableSet for EnumerableSet.AddressSet;

    /* -------------------------------------------- */
    /* state                                        */
    /* -------------------------------------------- */

    EnumerableSet.AddressSet internal _collections;
    address internal _collectionImplementation;
    address internal _owner;

    /* -------------------------------------------- */
    /* constructor                                  */
    /* -------------------------------------------- */

    constructor(address collectionImplementation_) {
        _collectionImplementation = collectionImplementation_;
    }

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    function isCollection(address token) external view returns (bool) {
        return _collections.contains(token);
    }

    function getCollections() external view returns (address[] memory) {
        return _collections.values();
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    function create(bytes calldata params) external returns (address) {
        address collectionInstance = Clones.clone(_collectionImplementation);
        Address.functionCall(collectionInstance, abi.encodeWithSignature("initialize(bytes)", params));

        _collections.add(collectionInstance);

        emit NewCollection(collectionInstance);

        return collectionInstance;
    }

    function updateImplementation(address newImpl) external {
        if (msg.sender != _owner) revert OnlyOwner();
        _collectionImplementation = newImpl;
    }
}
