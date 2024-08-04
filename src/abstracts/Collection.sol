// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IERC6551Registry } from "erc6551/interfaces/IERC6551Registry.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { ICollection } from "src/interfaces/ICollection.sol";
import { IRouxEditionFactory } from "src/interfaces/IRouxEditionFactory.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IController } from "src/interfaces/IController.sol";
import { ICollectionExtension } from "src/interfaces/ICollectionExtension.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { ERC721 } from "solady/tokens/ERC721.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ReentrancyGuard } from "solady/utils/ReentrancyGuard.sol";
import { Initializable } from "solady/utils/Initializable.sol";
import { CollectionData } from "src/types/DataTypes.sol";
import { LibBitmap } from "solady/utils/LibBitmap.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";

/**
 * @title Collection
 * @custom:version 1.0
 */
abstract contract Collection is ICollection, ERC721, Initializable, OwnableRoles, ReentrancyGuard {
    using LibBitmap for LibBitmap.Bitmap;
    /* ------------------------------------------------- */
    /* constants                                         */
    /* ------------------------------------------------- */

    /**
     * @notice collection storage slot
     * @dev keccak256(abi.encode(uint256(keccak256("collection.collectionStorage")) - 1)) & ~bytes32(uint256(0xff));
     */
    bytes32 internal constant COLLECTION_STORAGE_SLOT =
        0x241c1d52679111588d51f8db5132d54ddcf0f237a8a14f5a3086ef7e730b9300;

    /* ------------------------------------------------- */
    /* immutable state                                   */
    /* ------------------------------------------------- */

    /// @notice erc6551 registry
    IERC6551Registry immutable _erc6551Registry;

    /// @notice erc6551 account implementation
    address immutable _accountImplementation;

    /// @notice edition factory
    IRouxEditionFactory immutable _editionFactory;

    /// @notice controller
    IController immutable _controller;

    /* ------------------------------------------------- */
    /* structures                                        */
    /* ------------------------------------------------- */

    /**
     * @notice collection storage
     * @custom:storage-location erc7201:collection.collectionStorage
     * @param curator curator address
     * @param name collection name
     * @param symbol collection symbol
     * @param tokenIds current token ID counter
     * @param uri collection URI
     * @param currency currency address
     * @param gate whether to gate minting
     * @param extensions bitmap of extension addresses to their enabled status
     */
    struct CollectionStorage {
        address curator;
        string name;
        string symbol;
        uint256 tokenIds;
        string uri;
        address currency;
        bool gate;
        LibBitmap.Bitmap extensions;
    }

    /* ------------------------------------------------- */
    /* constructor                                       */
    /* ------------------------------------------------- */

    /**
     * @notice constructor
     * @param erc6551registry erc6551 registry
     * @param accountImplementation erc6551 account implementation
     * @param editionFactory roux edition factory
     * @param controller controller
     */
    constructor(address erc6551registry, address accountImplementation, address editionFactory, address controller) {
        // disable initialization of implementation contract
        _disableInitializers();

        _erc6551Registry = IERC6551Registry(erc6551registry);
        _accountImplementation = accountImplementation;
        _editionFactory = IRouxEditionFactory(editionFactory);
        _controller = IController(controller);
    }

    /* ------------------------------------------------- */
    /* storage                                           */
    /* ------------------------------------------------- */

    /**
     * @notice get collection storage location
     * @return $ Collection storage location
     */
    function _collectionStorage() internal pure returns (CollectionStorage storage $) {
        assembly {
            $.slot := COLLECTION_STORAGE_SLOT
        }
    }

    /* ------------------------------------------------- */
    /* view                                              */
    /* ------------------------------------------------- */

    /// @dev see {ERC721-name}
    function name() public view override returns (string memory) {
        return _collectionStorage().name;
    }

    /// @dev see {ERC721-symbol}
    function symbol() public view override returns (string memory) {
        return _collectionStorage().symbol;
    }

    /// @dev see {ERC721-tokenURI}
    function tokenURI(uint256 /* id */ ) public view override returns (string memory) {
        return _collectionStorage().uri;
    }

    /// @inheritdoc ICollection
    function contractURI() external view override returns (string memory) {
        return _collectionStorage().uri;
    }

    /// @inheritdoc ICollection
    function collection() external view virtual returns (address[] memory itemTargets, uint256[] memory itemIds);

    /// @inheritdoc ICollection
    function curator() external view returns (address) {
        return _collectionStorage().curator;
    }

    /// @inheritdoc ICollection
    function currency() external view returns (address) {
        return _collectionStorage().currency;
    }

    /// @inheritdoc ICollection
    function price() external view virtual returns (uint256);

    /// @inheritdoc ICollection
    function totalSupply() external view returns (uint256) {
        return _collectionStorage().tokenIds;
    }

    /// @inheritdoc ICollection
    function isRegisteredExtension(address extension_) external view returns (bool) {
        return _isRegisteredExtension(extension_);
    }

    /// @inheritdoc ICollection
    function isGated() external view returns (bool) {
        return _collectionStorage().gate;
    }

    /* ------------------------------------------------- */
    /* write                                             */
    /* ------------------------------------------------- */

    /// @inheritdoc ICollection
    function mint(
        address to,
        address extension,
        address referrer,
        bytes calldata data
    )
        external
        virtual
        returns (uint256);

    /* ------------------------------------------------- */
    /* admin                                             */
    /* ------------------------------------------------- */

    /// @inheritdoc ICollection
    function setCurator(address curator_) external onlyOwner {
        CollectionStorage storage $ = _collectionStorage();

        if ($.curator == address(0)) {
            $.curator = curator_;
        } else {
            revert ErrorsLib.Collection_CuratorAlreadySet();
        }
    }

    /**
     * @notice sets or unsets an extension for a collection
     * @param extension extension address
     * @param enable enable or disable extension
     * @param options optional mint params
     */
    function setExtension(address extension, bool enable, bytes calldata options) external onlyOwner {
        CollectionStorage storage $ = _collectionStorage();

        // set extension
        if (enable) {
            // validate extension is not zero
            if (extension == address(0)) revert ErrorsLib.Collection_InvalidExtension();

            // validate extension interface support
            if (!ICollectionExtension(extension).supportsInterface(type(ICollectionExtension).interfaceId)) {
                revert ErrorsLib.Collection_InvalidExtension();
            }
            $.extensions.set(uint256(uint160(extension)));
        } else {
            $.extensions.unset(uint256(uint160(extension)));
        }

        // update mint params
        if (enable && options.length > 0) {
            ICollectionExtension(extension).setCollectionMintParams(options);
        }

        emit EventsLib.ExtensionSet(extension, enable);
    }

    /**
     * @notice updates the mint parameters for a collection extension
     * @param extension extension address
     * @param params updated extension mint params
     */
    function updateExtensionParams(address extension, bytes calldata params) external onlyOwner {
        // validate extension is registered
        if (!_collectionStorage().extensions.get(uint256(uint160(extension)))) {
            revert ErrorsLib.Collection_InvalidExtension();
        }

        // call extension with updated params
        ICollectionExtension(extension).setCollectionMintParams(params);
    }

    /**
     * @notice update uri
     * @param newUri new uri
     */
    function updateUri(string calldata newUri) external onlyOwner {
        _collectionStorage().uri = newUri;

        emit EventsLib.UriUpdated(newUri);
    }

    /**
     * @dev Enables or disables gated minting for this collection.
     * @param gate True to enable gated minting, false to disable it.
     */
    function gateMint(bool gate) external onlyOwner {
        _collectionStorage().gate = gate;
    }

    /* ------------------------------------------------- */
    /* internal                                          */
    /* ------------------------------------------------- */

    /**
     * @notice mint tba
     * @param to address to mint to
     * @param id token id
     * @param salt erc6551 salt
     */
    function _mintTba(address to, uint256 id, bytes32 salt) internal returns (address) {
        // mint collection nft
        _mint(to, id);

        // create erc6551 token bound account
        address account = _erc6551Registry.createAccount(_accountImplementation, salt, block.chainid, address(this), id);

        // emit event
        emit EventsLib.CollectionMinted(id, to, account);

        return account;
    }

    /**
     * @notice check if extension is registered
     * @param extension extension address
     * @return true if extension is valid
     */
    function _isRegisteredExtension(address extension) internal view returns (bool) {
        return _collectionStorage().extensions.get(uint256(uint160(extension)));
    }

    /* ------------------------------------------------- */
    /* erc165 interface                                */
    /* ------------------------------------------------- */

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, IERC165) returns (bool) {
        return interfaceId == type(ICollection).interfaceId || super.supportsInterface(interfaceId);
    }
}
