// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { IRegistry } from "src/interfaces/IRegistry.sol";

/**
 * @title Roux Registry
 * @author Roux
 */
contract Registry is IRegistry, OwnableRoles {
    /* -------------------------------------------- */
    /* constants                                    */
    /* -------------------------------------------- */

    /**
     * @notice Controller storage slot
     * @dev keccak256(abi.encode(uint256(keccak256("rouxRegistry.rouxRegistryStorage")) - 1)) & ~bytes32(uint256(0xff));
     */
    bytes32 internal constant ROUX_REGISTRY_STORAGE_SLOT =
        0x526b27153fa869a204893bc4926da2a9c5dc034df85df1046d3f9c814a26d100;

    /**
     * @notice maximum depth of attribution tree
     */
    uint256 internal constant MAX_DEPTH = 8;

    /* -------------------------------------------- */
    /* structures                                   */
    /* -------------------------------------------- */

    /**
     * @notice roux registry storage
     * @custom:storage-location erc7201:rouxRegistry.rouxRegistryStorage
     */
    struct RouxRegistryStorage {
        bool initialized;
        mapping(address edition => mapping(uint256 tokenId => RegistryData)) registryData;
    }

    /* -------------------------------------------- */
    /* constructor                                  */
    /* -------------------------------------------- */

    constructor() {
        // disable initialization of implementation contract
        _storage().initialized = true;

        // renounce ownership of implementation contract
        _initializeOwner(msg.sender);
        renounceOwnership();
    }

    /* -------------------------------------------- */
    /* initializer                                  */
    /* -------------------------------------------- */

    function initialize() external {
        // initialize
        require(!_storage().initialized, "Already initialized");
        _storage().initialized = true;

        // set owner of the proxy
        _initializeOwner(msg.sender);
    }

    /* -------------------------------------------- */
    /* storage                                      */
    /* -------------------------------------------- */

    /**
     * @notice get roux registry storage location
     * @return $ Roux registry storage location
     */
    function _storage() internal pure returns (RouxRegistryStorage storage $) {
        assembly {
            $.slot := ROUX_REGISTRY_STORAGE_SLOT
        }
    }

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    /**
     * @inheritdoc IRegistry
     */
    function attribution(address edition, uint256 tokenId) external view returns (address, uint256) {
        RouxRegistryStorage storage $ = _storage();

        address parentEdition = $.registryData[edition][tokenId].parentEdition;
        uint256 parentTokenId = $.registryData[edition][tokenId].parentTokenId;

        return (parentEdition, parentTokenId);
    }

    /**
     * @inheritdoc IRegistry
     */
    function root(address edition, uint256 tokenId) external view returns (address, uint256, uint256) {
        // pass 0 as starting depth
        return _root(edition, tokenId, 0);
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /**
     * @inheritdoc IRegistry
     */
    function setRegistryData(uint256 tokenId, address parentEdition, uint256 parentTokenId) external {
        // get current depth of parent edition and tokenId
        (,, uint256 depth) = _root(parentEdition, parentTokenId, 0);

        // revert if addition exceeds max depth
        if (depth + 1 > MAX_DEPTH) revert MaxDepthExceeded();

        // set administrator data for edition + token id
        RegistryData storage d = _storage().registryData[msg.sender][tokenId];

        d.parentEdition = parentEdition;
        d.parentTokenId = parentTokenId;

        // emit event
        emit RegistryUpdated(msg.sender, tokenId, parentEdition, parentTokenId);
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

    /* -------------------------------------------- */
    /* internal                                     */
    /* -------------------------------------------- */

    /**
     * @notice get root edition for a given edition
     * @param edition edition
     * @param tokenId token id
     * @param depth depth, should always be called with 0
     * @return edition if current edition is root, otherwise parent edition
     * @return token id if current edition is root, otherwise parent token id
     * @return depth
     *
     * @dev used to compute the root of an attribution tree
     *      depth is incremented on each subsequent call
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
