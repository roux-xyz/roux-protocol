// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { IRegistry } from "src/interfaces/IRegistry.sol";

import { Initializable } from "solady/utils/Initializable.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ReentrancyGuard } from "solady/utils/ReentrancyGuard.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { LibBitmap } from "solady/utils/LibBitmap.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { MAX_CHILDREN } from "src/libraries/ConstantsLib.sol";

/**
 * @title registry
 * @author roux
 * @custom:version 1.0
 * @custom:security-contact mp@roux.app
 */
contract Registry is IRegistry, Initializable, OwnableRoles, ReentrancyGuard {
    using LibBitmap for LibBitmap.Bitmap;

    /* ------------------------------------------------- */
    /* constants                                         */
    /* ------------------------------------------------- */

    /**
     * @notice Registry storage slot
     * @dev keccak256(abi.encode(uint256(keccak256("rouxRegistry.rouxRegistryStorage")) - 1)) & ~bytes32(uint256(0xff));
     */
    bytes32 internal constant ROUX_REGISTRY_STORAGE_SLOT =
        0x526b27153fa869a204893bc4926da2a9c5dc034df85df1046d3f9c814a26d100;

    /* ------------------------------------------------- */
    /* structures                                        */
    /* ------------------------------------------------- */

    /**
     * @notice registry data
     * @param parentEdition parent edition
     * @param parentTokenId parent token id
     * @param index index
     */
    struct RegistryData {
        address parentEdition;
        uint256 parentTokenId;
        uint256 index;
    }

    /**
     * @notice roux registry storage
     * @custom:storage-location erc7201:rouxRegistry.rouxRegistryStorage
     * @param registryData edition to token id to registry data
     */
    struct RouxRegistryStorage {
        mapping(address edition => mapping(uint256 tokenId => RegistryData)) registryData;
    }

    /* ------------------------------------------------- */
    /* constructor                                       */
    /* ------------------------------------------------- */

    constructor() {
        // disable initialization of implementation contract
        _disableInitializers();

        // renounce ownership of implementation contract
        _initializeOwner(msg.sender);
        renounceOwnership();
    }

    /* ------------------------------------------------- */
    /* initializer                                       */
    /* ------------------------------------------------- */

    function initialize() external initializer nonReentrant {
        // set owner of the proxy
        _initializeOwner(msg.sender);
    }

    /* ------------------------------------------------- */
    /* storage                                           */
    /* ------------------------------------------------- */

    /**
     * @notice get roux registry storage location
     * @return $ Roux registry storage location
     */
    function _storage() internal pure returns (RouxRegistryStorage storage $) {
        assembly {
            $.slot := ROUX_REGISTRY_STORAGE_SLOT
        }
    }

    /* ------------------------------------------------- */
    /* view                                              */
    /* ------------------------------------------------- */

    /// @inheritdoc IRegistry
    function attribution(address edition, uint256 tokenId) external view returns (address, uint256, uint256) {
        RouxRegistryStorage storage $ = _storage();

        address parentEdition = $.registryData[edition][tokenId].parentEdition;
        uint256 parentTokenId = $.registryData[edition][tokenId].parentTokenId;
        uint256 index = $.registryData[edition][tokenId].index;

        return (parentEdition, parentTokenId, index);
    }

    /// @inheritdoc IRegistry
    function root(address edition, uint256 tokenId) external view returns (address, uint256, uint256) {
        // pass 0 as starting depth
        return _root(edition, tokenId, 0);
    }

    /* ------------------------------------------------- */
    /* write                                             */
    /* ------------------------------------------------- */

    /// @inheritdoc IRegistry
    function setRegistryData(
        uint256 tokenId,
        address parentEdition,
        uint256 parentTokenId,
        uint256 index
    )
        external
        nonReentrant
    {
        RouxRegistryStorage storage $ = _storage();

        // get current depth of parent edition and tokenId
        (,, uint256 depth) = _root(parentEdition, parentTokenId, 0);

        // revert if addition would exceed max depth
        if (depth + 1 > MAX_CHILDREN) revert ErrorsLib.Registry_MaxDepthExceeded();

        // set administrator data for edition + token id
        RegistryData storage d = $.registryData[msg.sender][tokenId];

        d.parentEdition = parentEdition;
        d.parentTokenId = parentTokenId;
        d.index = index;

        // emit event
        emit EventsLib.RegistryUpdated(msg.sender, tokenId, parentEdition, parentTokenId);
    }

    /* ------------------------------------------------- */
    /* proxy | danger zone                               */
    /* ------------------------------------------------- */

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

    /* ------------------------------------------------- */
    /* internal                                          */
    /* ------------------------------------------------- */

    /**
     * @notice get root edition for a given edition
     * @param edition edition
     * @param tokenId token id
     * @param depth depth, should always be called with 0
     * @return edition if current edition is root, otherwise parent edition
     * @return token id if current edition is root, otherwise parent token id
     * @return depth zero-indexed depth eg the root token has a depth of 0, its parent has a depth of 1, etc
     *
     * @dev used to compute the root of an attribution tree
     *      - depth is incremented on each subsequent call
     */
    function _root(address edition, uint256 tokenId, uint256 depth) internal view returns (address, uint256, uint256) {
        // get storage
        RouxRegistryStorage storage $ = _storage();

        // if root, return edition and tokenId
        if ($.registryData[edition][tokenId].parentEdition == address(0)) {
            return (edition, tokenId, depth);
        } else {
            // if not root, recursively call this function with parent data, incrementing depth
            return _root(
                $.registryData[edition][tokenId].parentEdition, $.registryData[edition][tokenId].parentTokenId, ++depth
            );
        }
    }
}
