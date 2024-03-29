// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { IRouxCreatorFactory } from "src/interfaces/IRouxCreatorFactory.sol";

contract RouxCreatorFactory is IRouxCreatorFactory {
    using EnumerableSet for EnumerableSet.AddressSet;

    /* -------------------------------------------- */
    /* state                                        */
    /* -------------------------------------------- */

    EnumerableSet.AddressSet internal _tokens;
    address internal _creatorImplementation;
    address internal _owner;
    mapping(address => bool) internal _allowlist;

    /* -------------------------------------------- */
    /* constructor                                  */
    /* -------------------------------------------- */

    constructor(address creatorImplementation_) {
        _creatorImplementation = creatorImplementation_;
        _owner = msg.sender;
    }

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    function isCreator(address token) external view returns (bool) {
        return _tokens.contains(token);
    }

    function getCreators() external view returns (address[] memory) {
        return _tokens.values();
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */
    function create(bytes calldata params) external returns (address) {
        if (!_allowlist[msg.sender]) revert OnlyAllowlist();

        address creatorInstance = Clones.clone(_creatorImplementation);
        Address.functionCall(creatorInstance, abi.encodeWithSignature("initialize(bytes)", params));

        _tokens.add(creatorInstance);

        emit NewCreator(creatorInstance);

        return creatorInstance;
    }

    /* -------------------------------------------- */
    /* admin                                        */
    /* -------------------------------------------- */

    function addAllowlist(address[] memory accounts) external {
        if (msg.sender != _owner) revert OnlyOwner();

        for (uint256 i = 0; i < accounts.length; i++) {
            _allowlist[accounts[i]] = true;
        }
    }

    function removeAllowlist(address account) external {
        if (msg.sender != _owner) revert OnlyOwner();
        _allowlist[account] = false;
    }

    function updateImplementation(address newImpl) external {
        if (msg.sender != _owner) revert OnlyOwner();
        _creatorImplementation = newImpl;
    }
}
