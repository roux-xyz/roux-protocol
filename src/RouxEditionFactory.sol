// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { Ownable } from "solady/auth/Ownable.sol";

import { IRouxEditionFactory } from "src/interfaces/IRouxEditionFactory.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";

contract RouxEditionFactory is IRouxEditionFactory, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /* -------------------------------------------- */
    /* constants                                    */
    /* -------------------------------------------- */

    /**
     * @notice RouxEditionFactory storage slot
     * @dev keccak256(abi.encode(uint256(keccak256("erc7201:RouxEditionFactory")) - 1)) & ~bytes32(uint256(0xff));
     */
    bytes32 internal constant ROUX_CREATOR_FACTORY_STORAGE_SLOT =
        0x24504c471aa12fa2df69897858cc7dcb056c8474b1cbbf9fd320f90e6b17aa00;

    /* -------------------------------------------- */
    /* structures                                   */
    /* -------------------------------------------- */

    /**
     * @notice RouxEdition storage
     * @custom:storage-location erc7201:RouxEditionFactory
     *
     * @param _initialized whether the contract has been initialized
     * @param _tokens set of edition tokens
     * @param _owner owner of the contract
     * @param _enableAllowlist whether to enable allowlist
     * @param _allowlist allowlist of editions
     */
    struct RouxEditionFactoryStorage {
        bool _initialized;
        EnumerableSet.AddressSet _tokens;
        address _owner;
        bool _enableAllowlist;
        mapping(address => bool) _allowlist;
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
        require(!$._initialized, "Already initialized");
        $._initialized = true;

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

        require(!$._initialized, "Already initialized");
        $._initialized = true;

        /* Set owner of proxy */
        _initializeOwner(msg.sender);

        /* enable allowlist */
        $._enableAllowlist = true;
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
            $.slot := ROUX_CREATOR_FACTORY_STORAGE_SLOT
        }
    }

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    function isCreator(address token) external view returns (bool) {
        return _storage()._tokens.contains(token);
    }

    function getCreators() external view returns (address[] memory) {
        return _storage()._tokens.values();
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    function create() external returns (address) {
        RouxEditionFactoryStorage storage $ = _storage();

        if ($._enableAllowlist && !$._allowlist[msg.sender]) revert OnlyAllowlist();

        address editionInstance = address(new BeaconProxy(_editionBeacon, abi.encodeWithSignature("initialize()")));

        IRouxEdition(editionInstance).setCreator(msg.sender);
        Ownable(editionInstance).transferOwnership(msg.sender);

        $._tokens.add(editionInstance);

        emit NewCreator(editionInstance);

        return editionInstance;
    }

    /* -------------------------------------------- */
    /* admin                                        */
    /* -------------------------------------------- */

    function setAllowlist(bool enable) external onlyOwner {
        _storage()._enableAllowlist = enable;
    }

    function addAllowlist(address[] memory accounts) external onlyOwner {
        RouxEditionFactoryStorage storage $ = _storage();

        for (uint256 i = 0; i < accounts.length; i++) {
            $._allowlist[accounts[i]] = true;
        }
    }

    function removeAllowlist(address account) external onlyOwner {
        _storage()._allowlist[account] = false;
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
