// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ERC721 } from "solady/tokens/ERC721.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ReentrancyGuard } from "solady/utils/ReentrancyGuard.sol";

import { IERC6551Registry } from "erc6551/interfaces/IERC6551Registry.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { ICollection } from "src/interfaces/ICollection.sol";
import { IRouxEditionFactory } from "src/interfaces/IRouxEditionFactory.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IController } from "src/interfaces/IController.sol";
import { ICollectionExtension } from "src/interfaces/ICollectionExtension.sol";

import { CollectionData } from "src/types/DataTypes.sol";

/**
 * @title Single Edition Collection
 * @author Roux
 */
abstract contract Collection is ICollection, ERC721, OwnableRoles, ReentrancyGuard {
    /* -------------------------------------------- */
    /* constants                                    */
    /* -------------------------------------------- */

    /**
     * @notice collection storage slot
     * @dev keccak256(abi.encode(uint256(keccak256("collection.collectionStorage")) - 1)) & ~bytes32(uint256(0xff));
     */
    bytes32 internal constant COLLECTION_STORAGE_SLOT =
        0x241c1d52679111588d51f8db5132d54ddcf0f237a8a14f5a3086ef7e730b9300;

    /**
     * @notice implementation version
     */
    string public constant IMPLEMENTATION_VERSION = "1.0";

    /* -------------------------------------------- */
    /* immutable state                              */
    /* -------------------------------------------- */

    /**
     * @notice erc6551 registry
     */
    IERC6551Registry immutable _erc6551Registry;

    /**
     * @notice initial account implementation
     */
    address immutable _accountImplementation;

    /**
     * @notice edition factory
     */
    IRouxEditionFactory immutable _rouxEditionFactory;

    /* -------------------------------------------- */
    /* structures                                   */
    /* -------------------------------------------- */

    /**
     * @notice Collection storage
     * @custom:storage-location erc7201:collection.collectionStorage
     * @param initialized whether the contract has been initialized
     * @param name collection name
     * @param symbol collection symbol
     * @param curator curator address
     * @param tokenIds current token ID counter
     * @param uri collection URI
     * @param currency currency address
     * @param itemTargets target edition addresses
     * @param itemIds array of item IDs in the collection
     * @param extensions mapping of extension addresses to their enabled status
     * @param gate whether to gate minting
     */
    struct CollectionStorage {
        bool initialized;
        string name;
        string symbol;
        address curator;
        uint256 tokenIds;
        string uri;
        address currency;
        address[] itemTargets;
        uint256[] itemIds;
        mapping(address extension => bool enable) extensions;
        bool gate;
    }

    /* -------------------------------------------- */
    /* constructor                                  */
    /* -------------------------------------------- */

    /**
     * @notice constructor
     * @param erc6551registry registry
     * @param accountImplementation initial erc6551 account implementation
     * @param rouxEditionFactory roux edition factory
     */
    constructor(address erc6551registry, address accountImplementation, address rouxEditionFactory) {
        // disable initialization of implementation contract
        _collectionStorage().initialized = true;

        // set erc6551 registry
        _erc6551Registry = IERC6551Registry(erc6551registry);

        // set initial erc6551 account implementation
        _accountImplementation = accountImplementation;

        // set roux edition factory
        _rouxEditionFactory = IRouxEditionFactory(rouxEditionFactory);
    }

    /* -------------------------------------------- */
    /* initializer                                  */
    /* -------------------------------------------- */

    /**
     * @notice initialize collection
     * @param params encoded parameters
     */
    function initialize(bytes calldata params) external nonReentrant {
        CollectionStorage storage $ = _collectionStorage();

        require(!$.initialized, "Already initialized");
        $.initialized = true;

        // factory will transfer ownership to its caller
        _initializeOwner(msg.sender);

        // initialize collection
        _createCollection(params);
    }

    /* -------------------------------------------- */
    /* storage                                      */
    /* -------------------------------------------- */

    /**
     * @notice Get Collection storage location
     * @return $ Collection storage location
     */
    function _collectionStorage() internal pure returns (CollectionStorage storage $) {
        assembly {
            $.slot := COLLECTION_STORAGE_SLOT
        }
    }

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    /**
     * @notice Get implementation version
     * @return implementation version
     */
    function implementationVersion() external pure returns (string memory) {
        return IMPLEMENTATION_VERSION;
    }

    /**
     * @notice Get collection name
     * @return collection name
     */
    function name() public view override returns (string memory) {
        return _collectionStorage().name;
    }

    /**
     * @notice Get collection symbol
     * @return collection symbol
     */
    function symbol() public view override returns (string memory) {
        return _collectionStorage().symbol;
    }

    /**
     * @notice Get token URI
     * @return token URI
     */
    function tokenURI(uint256) public view override returns (string memory) {
        return _collectionStorage().uri;
    }

    /**
     * @inheritdoc ICollection
     */
    function collection() external view returns (address[] memory itemTargets, uint256[] memory itemIds) {
        CollectionStorage storage $ = _collectionStorage();

        itemTargets = $.itemTargets;
        itemIds = $.itemIds;
    }

    /**
     * @inheritdoc ICollection
     */
    function curator() external view returns (address) {
        return _collectionStorage().curator;
    }

    /**
     * @inheritdoc ICollection
     */
    function currency() external view returns (address) {
        return _collectionStorage().currency;
    }

    /**
     * @inheritdoc ICollection
     */
    function price() external view virtual returns (uint256);

    /**
     * @notice Get total supply
     * @return total supply
     */
    function totalSupply() external view returns (uint256) {
        return _collectionStorage().tokenIds;
    }

    /**
     * @notice Check if token exists
     * @param tokenId_ token ID to check
     * @return whether token exists
     */
    function exists(uint256 tokenId_) external view returns (bool) {
        return _exists(tokenId_);
    }

    /**
     * @inheritdoc ICollection
     */
    function isExtension(address extension_) external view returns (bool) {
        return _collectionStorage().extensions[extension_];
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /**
     * @inheritdoc ICollection
     */
    function mint(address to, address extension, bytes calldata data) public payable virtual returns (uint256);

    /* -------------------------------------------- */
    /* admin                                        */
    /* -------------------------------------------- */

    /**
     * @inheritdoc ICollection
     */
    function setExtension(address extension, bool enable, bytes calldata options) external onlyOwner {
        CollectionStorage storage $ = _collectionStorage();

        // validate extension is not zero
        if (extension == address(0)) revert InvalidExtension();

        // validate extension interface support
        if (!ICollectionExtension(extension).supportsInterface(type(ICollectionExtension).interfaceId)) {
            revert InvalidExtension();
        }

        // set extension
        $.extensions[extension] = enable;

        // update mint params
        if (enable && options.length > 0) {
            ICollectionExtension(extension).setCollectionMintParams(options);
        }

        emit ExtensionSet(extension, enable);
    }

    /**
     * @inheritdoc ICollection
     */
    function updateExtensionMintParams(address extension, bytes calldata options) external onlyOwner {
        CollectionStorage storage $ = _collectionStorage();

        // must be enabled to update mint params
        if (!$.extensions[extension]) revert InvalidExtension();

        // call extension with updated params
        ICollectionExtension(extension).setCollectionMintParams(options);
    }

    /**
     * @inheritdoc ICollection
     */
    function updateMintParams(bytes calldata mintParams) external virtual;

    /**
     * @inheritdoc ICollection
     */
    function gateMint(bool gate) external onlyOwner {
        _collectionStorage().gate = gate;
    }

    /* -------------------------------------------- */
    /* erc165 interface                           */
    /* -------------------------------------------- */

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, IERC165) returns (bool) {
        return interfaceId == type(ICollection).interfaceId || super.supportsInterface(interfaceId);
    }

    /* -------------------------------------------- */
    /* internal functions                           */
    /* -------------------------------------------- */

    /**
     * @notice initialize collection
     * @param params encoded parameters
     */
    function _createCollection(bytes calldata params) internal virtual;
}
