// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IRouxEditionFactory } from "src/interfaces/IRouxEditionFactory.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";

import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";

import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { ReentrancyGuard } from "solady/utils/ReentrancyGuard.sol";
import { LibBitmap } from "solady/utils/LibBitmap.sol";
import { Initializable } from "solady/utils/Initializable.sol";

/**
 * @title roux edition factory
 * @author roux
 * @custom:version 0.1
 * @custom:security-contact mp@roux.app
 */
contract RouxEditionFactory is IRouxEditionFactory, Initializable, Ownable, ReentrancyGuard {
    using LibBitmap for LibBitmap.Bitmap;

    /* -------------------------------------------- */
    /* constants                                    */
    /* -------------------------------------------- */

    /**
     * @notice RouxEditionFactory storage slot
     * @dev keccak256(abi.encode(uint256(keccak256("rouxEditionFactory.rouxEditionFactoryStorage")) - 1)) &
     *      ~bytes32(uint256(0xff));
     */
    bytes32 internal constant ROUX_EDITION_FACTORY_STORAGE_SLOT =
        0x13ea773dc95198298e0d9b6bbd2aef489fb654cd1810ac18d17a86ab80293a00;

    /* -------------------------------------------- */
    /* structures                                   */
    /* -------------------------------------------- */

    /**
     * @notice RouxEdition storage
     * @custom:storage-location erc7201:rouxEditionFactory.rouxEditionFactoryStorage
     * @param editions set of editions
     * @param owner owner of the contract
     * @param enableAllowlist whether to enable allowlist
     * @param allowlist allowlist of editions
     */
    struct RouxEditionFactoryStorage {
        LibBitmap.Bitmap editions;
        address owner;
        bool enableAllowlist;
        mapping(address => bool) allowlist;
    }

    /* -------------------------------------------- */
    /* immutable state                              */
    /* -------------------------------------------- */

    /// @notice edition beacon
    address internal immutable _editionBeacon;

    /* -------------------------------------------- */
    /* constructor                                  */
    /* -------------------------------------------- */

    /**
     * @notice constructor
     * @param editionBeacon edition beacon
     */
    constructor(address editionBeacon) {
        // disable initialization of implementation contract
        _disableInitializers();

        // set edition beacon
        _editionBeacon = editionBeacon;

        // renounce ownership of implementation contract
        _initializeOwner(msg.sender);
        renounceOwnership();
    }

    /* -------------------------------------------- */
    /* initializer                                  */
    /* -------------------------------------------- */

    /// @notice initialize RouxEditionFactory
    function initialize() external initializer {
        // set owner of proxy
        _initializeOwner(msg.sender);
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
            $.slot := ROUX_EDITION_FACTORY_STORAGE_SLOT
        }
    }

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    /// @inheritdoc IRouxEditionFactory
    function isEdition(address edition) external view returns (bool) {
        return _storage().editions.get(uint256(uint160(edition)));
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @inheritdoc IRouxEditionFactory
    function create(bytes calldata params) external nonReentrant returns (address) {
        RouxEditionFactoryStorage storage $ = _storage();

        // check allowlist
        if ($.enableAllowlist && !$.allowlist[msg.sender]) revert ErrorsLib.RouxEdition_OnlyAllowlist();

        // create edition instance
        address editionInstance =
            address(new BeaconProxy(_editionBeacon, abi.encodeWithSignature("initialize(bytes)", params)));

        // transfer ownership to caller
        Ownable(editionInstance).transferOwnership(msg.sender);

        // add to editions mapping
        $.editions.set(uint256(uint160(editionInstance)));

        // emit event
        emit EventsLib.NewEdition(editionInstance);

        return editionInstance;
    }

    /* -------------------------------------------- */
    /* admin                                        */
    /* -------------------------------------------- */

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
        RouxEditionFactoryStorage storage $ = _storage();

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
