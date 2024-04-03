// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { IRouxCreatorFactory } from "src/interfaces/IRouxCreatorFactory.sol";
import { IRouxCreator } from "src/interfaces/IRouxCreator.sol";

contract RouxCreatorFactory is IRouxCreatorFactory, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /* -------------------------------------------- */
    /* constants                                    */
    /* -------------------------------------------- */

    /**
     * @notice RouxCreatorFactory storage slot
     * @dev keccak256(abi.encode(uint256(keccak256("erc7201:rouxCreatorFactory")) - 1)) & ~bytes32(uint256(0xff));
     */
    bytes32 internal constant ROUX_CREATOR_FACTORY_STORAGE_SLOT =
        0x24504c471aa12fa2df69897858cc7dcb056c8474b1cbbf9fd320f90e6b17aa00;

    /* -------------------------------------------- */
    /* structures                                   */
    /* -------------------------------------------- */

    struct RouxCreatorFactoryStorage {
        EnumerableSet.AddressSet _tokens;
        address _creatorBeacon;
        address _owner;
        mapping(address => bool) _allowlist;
    }

    /* -------------------------------------------- */
    /* constructor                                  */
    /* -------------------------------------------- */

    constructor(address creatorBeacon) {
        RouxCreatorFactoryStorage storage $ = _storage();

        $._creatorBeacon = creatorBeacon;

        _initializeOwner(msg.sender);
    }

    /* -------------------------------------------- */
    /* storage                                      */
    /* -------------------------------------------- */

    /**
     * @notice Get RouxCreatorFactory storage location
     * @return $ RouxCreatorFactory storage location
     */
    function _storage() internal pure returns (RouxCreatorFactoryStorage storage $) {
        assembly {
            $.slot := ROUX_CREATOR_FACTORY_STORAGE_SLOT
        }
    }

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    function isCreator(address token) external view returns (bool) {
        RouxCreatorFactoryStorage storage $ = _storage();

        return $._tokens.contains(token);
    }

    function getCreators() external view returns (address[] memory) {
        RouxCreatorFactoryStorage storage $ = _storage();

        return $._tokens.values();
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    function create() external returns (address) {
        RouxCreatorFactoryStorage storage $ = _storage();

        if (!$._allowlist[msg.sender]) revert OnlyAllowlist();

        address creatorInstance = address(new BeaconProxy($._creatorBeacon, abi.encodeWithSignature("initialize()")));

        IRouxCreator(creatorInstance).initializeCreator(msg.sender);
        Ownable(creatorInstance).transferOwnership(msg.sender);

        $._tokens.add(creatorInstance);

        emit NewCreator(creatorInstance);

        return creatorInstance;
    }

    /* -------------------------------------------- */
    /* admin                                        */
    /* -------------------------------------------- */

    function addAllowlist(address[] memory accounts) external onlyOwner {
        RouxCreatorFactoryStorage storage $ = _storage();

        for (uint256 i = 0; i < accounts.length; i++) {
            $._allowlist[accounts[i]] = true;
        }
    }

    function removeAllowlist(address account) external onlyOwner {
        RouxCreatorFactoryStorage storage $ = _storage();

        $._allowlist[account] = false;
    }
}
