// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

import { ICollectionFactory } from "./interfaces/ICollectionFactory.sol";

contract CollectionFactory is ICollectionFactory {
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
        EnumerableSet.AddressSet _collections;
        address _collectionImplementation;
        address _owner;
    }

    /* -------------------------------------------- */
    /* constructor                                  */
    /* -------------------------------------------- */

    constructor(address collectionImplementation_) {
        CollectionFactoryStorage storage $ = _storage();

        $._collectionImplementation = collectionImplementation_;
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

        address collectionInstance = Clones.clone($._collectionImplementation);
        Address.functionCall(collectionInstance, abi.encodeWithSignature("initialize(bytes)", params));

        $._collections.add(collectionInstance);

        emit NewCollection(collectionInstance);

        return collectionInstance;
    }

    function updateImplementation(address newImpl) external {
        CollectionFactoryStorage storage $ = _storage();

        if (msg.sender != $._owner) revert OnlyOwner();
        $._collectionImplementation = newImpl;
    }
}
