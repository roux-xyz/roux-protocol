// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { IRouxEditionFactory } from "src/core/interfaces/IRouxEditionFactory.sol";
import { IRouxEdition } from "src/core/interfaces/IRouxEdition.sol";
import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { ReentrancyGuard } from "solady/utils/ReentrancyGuard.sol";
import { LibBitmap } from "solady/utils/LibBitmap.sol";
import { Initializable } from "solady/utils/Initializable.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";

/**
 * campari martini
 *
 * 3 oz campari
 * pinch of salt
 *
 * stir / strain / up / garnish with orange twist
 */

/**
 * @title roux edition factory
 * @author roux
 * @custom:security-contact security@roux.app
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

    /// @notice version
    string public constant VERSION = "1.0";

    /* -------------------------------------------- */
    /* structures                                   */
    /* -------------------------------------------- */

    /**
     * @notice RouxEdition storage
     * @custom:storage-location erc7201:rouxEditionFactory.rouxEditionFactoryStorage
     * @param editions set of editions
     * @param deployerNonce mapping of deployer to nonce
     * @param totalEditions total number of editions
     */
    struct RouxEditionFactoryStorage {
        LibBitmap.Bitmap editions;
        mapping(address => uint256) deployerNonce;
        uint256 totalEditions;
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

    /// @inheritdoc IRouxEditionFactory
    function totalEditions() external view returns (uint256) {
        return _storage().totalEditions;
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @inheritdoc IRouxEditionFactory
    function create(bytes calldata params) external nonReentrant returns (address) {
        RouxEditionFactoryStorage storage $ = _storage();

        // get and increment the deployer's nonce
        uint256 nonce = $.deployerNonce[msg.sender]++;

        // calculate salt using msg.sender and their nonce
        bytes32 salt = keccak256(abi.encodePacked(msg.sender, nonce));

        // create initialization data for the proxy
        bytes memory initData = abi.encodeWithSignature("initialize(bytes)", params);

        // deploy proxy using Create2
        address editionInstance = Create2.deploy(
            0, salt, abi.encodePacked(type(BeaconProxy).creationCode, abi.encode(_editionBeacon, initData))
        );

        // transfer ownership to caller
        Ownable(editionInstance).transferOwnership(msg.sender);

        // add to editions mapping
        $.editions.set(uint256(uint160(editionInstance)));

        // increment total editions
        $.totalEditions++;

        // emit event
        emit EventsLib.NewEdition(editionInstance);

        return editionInstance;
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
