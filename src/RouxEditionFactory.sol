// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { Ownable } from "solady/auth/Ownable.sol";

import { IRouxEditionFactory } from "src/interfaces/IRouxEditionFactory.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";

/**
 * @title Roux Edition Factory
 * @author Roux
 */
contract RouxEditionFactory is IRouxEditionFactory, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /* -------------------------------------------- */
    /* constants                                    */
    /* -------------------------------------------- */

    /**
     * @notice RouxEditionFactory storage slot
     * @dev keccak256(abi.encode(uint256(keccak256("rouxEditionFactory.rouxEditionFactoryStorage")) - 1)) &
     *      ~bytes32(uint256(0xff));
     */
    bytes32 internal constant ROUX_EDITION_STORAGE_SLOT =
        0x13ea773dc95198298e0d9b6bbd2aef489fb654cd1810ac18d17a86ab80293a00;

    /* -------------------------------------------- */
    /* structures                                   */
    /* -------------------------------------------- */

    /**
     * @notice RouxEdition storage
     * @custom:storage-location erc7201:rouxEditionFactory.rouxEditionFactoryStorage
     *
     * @param initialized whether the contract has been initialized
     * @param editions set of editions
     * @param owner owner of the contract
     * @param enableAllowlist whether to enable allowlist
     * @param allowlist allowlist of editions
     */
    struct RouxEditionFactoryStorage {
        bool initialized;
        EnumerableSet.AddressSet editions;
        address owner;
        bool enableAllowlist;
        mapping(address => bool) allowlist;
    }

    /* -------------------------------------------- */
    /* immutable state                              */
    /* -------------------------------------------- */

    address internal immutable _editionBeacon;

    /* -------------------------------------------- */
    /* constructor                                  */
    /* -------------------------------------------- */

    constructor(address editionBeacon) {
        RouxEditionFactoryStorage storage $ = _storage();

        /* disable initialization of implementation contract */
        require(!$.initialized, "Already initialized");
        $.initialized = true;

        _editionBeacon = editionBeacon;

        /* renounce ownership of implementation contract */
        _initializeOwner(msg.sender);
        renounceOwnership();
    }

    /* -------------------------------------------- */
    /* initializer                                  */
    /* -------------------------------------------- */

    /**
     * @notice initialize RouxEditionFactory
     */
    function initialize() external {
        RouxEditionFactoryStorage storage $ = _storage();

        require(!$.initialized, "Already initialized");
        $.initialized = true;

        /* Set owner of proxy */
        _initializeOwner(msg.sender);

        /* enable allowlist */
        $.enableAllowlist = true;
    }

    /* -------------------------------------------- */
    /* storage                                      */
    /* -------------------------------------------- */

    /**
     * @notice get RouxEditionFactory storage location
     * @return $ RouxEditionFactory storage location
     */
    function _storage() internal pure returns (RouxEditionFactoryStorage storage $) {
        assembly {
            $.slot := ROUX_EDITION_STORAGE_SLOT
        }
    }

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    function isEdition(address token) external view returns (bool) {
        return _storage().editions.contains(token);
    }

    function getEditions() external view returns (address[] memory) {
        return _storage().editions.values();
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    function create(bytes calldata params) external returns (address) {
        RouxEditionFactoryStorage storage $ = _storage();

        // verify allowlist
        if ($.enableAllowlist && !$.allowlist[msg.sender]) revert OnlyAllowlist();

        // create edition instance
        address editionInstance =
            address(new BeaconProxy(_editionBeacon, abi.encodeWithSignature("initialize(bytes)", params)));

        // transfer ownership to caller
        Ownable(editionInstance).transferOwnership(msg.sender);

        // add to editions set
        $.editions.add(editionInstance);

        emit NewEdition(editionInstance);

        return editionInstance;
    }

    /* -------------------------------------------- */
    /* admin                                        */
    /* -------------------------------------------- */

    function setAllowlist(bool enable) external onlyOwner {
        _storage().enableAllowlist = enable;
    }

    function addAllowlist(address[] memory accounts) external onlyOwner {
        RouxEditionFactoryStorage storage $ = _storage();

        for (uint256 i = 0; i < accounts.length; i++) {
            $.allowlist[accounts[i]] = true;
        }
    }

    function removeAllowlist(address account) external onlyOwner {
        _storage().allowlist[account] = false;
    }

    /* -------------------------------------------- */
    /* proxy | danger zone                          */
    /* -------------------------------------------- */

    /**
     * @notice get proxy implementation
     * @return implementation address
     *
     * @dev do not remove this function
     */
    function getImplementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    /**
     * @notice upgrade proxy
     * @param newImplementation new implementation contract
     * @param data optional calldata
     *
     * @dev do not remove this function
     */
    function upgradeToAndCall(address newImplementation, bytes calldata data) external onlyOwner {
        ERC1967Utils.upgradeToAndCall(newImplementation, data);
    }
}
