// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { IRouxEdition } from "src/core/interfaces/IRouxEdition.sol";
import { IRouxEditionFactory } from "src/core/interfaces/IRouxEditionFactory.sol";
import { ICollectionFactory } from "src/core/interfaces/ICollectionFactory.sol";
import { IController } from "src/core/interfaces/IController.sol";
import { IRegistry } from "src/core/interfaces/IRegistry.sol";
import { ICollection } from "src/core/interfaces/ICollection.sol";
import { IExtension } from "src/periphery/interfaces/IExtension.sol";
import { Collection } from "src/core/abstracts/Collection.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { ERC1155 } from "solady/tokens/ERC1155.sol";
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ReentrancyGuard } from "solady/utils/ReentrancyGuard.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { TokenUriLib } from "src/libraries/TokenUriLib.sol";
import { Initializable } from "solady/utils/Initializable.sol";
import { LibBitmap } from "solady/utils/LibBitmap.sol";
import { EditionData } from "src/types/DataTypes.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { Base32 } from "src/libraries/Base32.sol";
import { DEFAULT_TOKEN_URI } from "src/libraries/ConstantsLib.sol";

/**
 * last mechanical art
 *
 * 3/4 oz mezcal
 * 3/4 oz cynar
 * 3/4 oz campari
 * 3/4 oz punt e mes
 *
 * stir, strain, up
 * garnish with orange peel
 */

/**
 * @title roux edition
 * @author roux
 * @custom:version 1.0
 * @custom:security-contact mp@roux.app
 */
contract RouxEdition is IRouxEdition, ERC1155, ERC165, Initializable, OwnableRoles, ReentrancyGuard {
    using SafeCastLib for uint256;
    using SafeTransferLib for address;
    using LibBitmap for LibBitmap.Bitmap;
    using TokenUriLib for bytes32;
    /* ------------------------------------------------- */
    /* constants                                         */
    /* ------------------------------------------------- */

    /**
     * @notice RouxEdition storage slot
     * @dev keccak256(abi.encode(uint256(keccak256("rouxEdition.rouxEditionStorage")) - 1)) &
     * ~bytes32(uint256(0xff));
     */
    bytes32 internal constant ROUX_EDITION_STORAGE_SLOT =
        0xef2f5668c8b56b992983464f11901aec8635a37d61a520221ade259ca1a88200;

    /// @notice roles
    uint256 private constant URI_SETTER_ROLE = 1;

    /* ------------------------------------------------- */
    /* immutable state                                   */
    /* ------------------------------------------------- */

    /// @notice registry
    IRegistry internal immutable _registry;

    /// @notice controller
    IController internal immutable _controller;

    /// @notice edition factory
    IRouxEditionFactory internal immutable _editionFactory;

    /// @notice collection factory
    ICollectionFactory internal immutable _collectionFactory;

    /**
     * @notice base currency
     * @dev see note {Controller-_currency}
     */
    address internal immutable _currency;

    /* ------------------------------------------------- */
    /* structures                                        */
    /* ------------------------------------------------- */

    /**
     * @notice RouxEdition storage
     * @custom:storage-location erc7201:rouxEdition.rouxEditionStorages
     * @param tokenId current token id
     * @param contractURI contract uri
     * @param collections mapping of enabled collections
     * @param tokens mapping of token id to token data
     */
    struct RouxEditionStorage {
        uint256 tokenId;
        string contractURI;
        LibBitmap.Bitmap collections;
        mapping(uint256 tokenId => EditionData.TokenData tokenData) tokens;
    }

    /* ------------------------------------------------- */
    /* constructor                                       */
    /* ------------------------------------------------- */

    /**
     * @notice constructor
     * @param controller controller
     * @param registry registry
     */
    constructor(address editionFactory, address collectionFactory, address controller, address registry) {
        // disable initializers
        _disableInitializers();

        // factory will transfer ownership to its caller
        _initializeOwner(msg.sender);

        _editionFactory = IRouxEditionFactory(editionFactory);
        _collectionFactory = ICollectionFactory(collectionFactory);
        _controller = IController(controller);
        _registry = IRegistry(registry);
        _currency = IController(_controller).currency();

        // renounce ownership of implementation contract
        renounceOwnership();
    }

    /* ------------------------------------------------- */
    /* initializer                                       */
    /* ------------------------------------------------- */

    /**
     * @notice initialize RouxEdition
     * @param params encoded parameters
     */
    function initialize(bytes calldata params) external initializer nonReentrant {
        RouxEditionStorage storage $ = _storage();

        // editionFactory transfers ownership to caller after initialization
        _initializeOwner(msg.sender);

        // approve controller
        _currency.safeApprove(address(_controller), type(uint256).max);

        // decode params
        string memory contractURI_ = abi.decode(params, (string));

        // set contract uri
        $.contractURI = contractURI_;
    }

    /* ------------------------------------------------- */
    /* storage                                           */
    /* ------------------------------------------------- */

    /**
     * @notice get RouxEdition storage location
     * @return $ RouxEdition storage location
     */
    function _storage() internal pure returns (RouxEditionStorage storage $) {
        assembly {
            $.slot := ROUX_EDITION_STORAGE_SLOT
        }
    }

    /* ------------------------------------------------- */
    /* view                                              */
    /* ------------------------------------------------- */

    /// @inheritdoc IRouxEdition
    function creator(uint256 id) external view returns (address) {
        return _storage().tokens[id].creator;
    }

    /// @inheritdoc IRouxEdition
    function currentToken() external view returns (uint256) {
        return _storage().tokenId;
    }

    /// @inheritdoc IRouxEdition
    function currency() external view returns (address) {
        return address(_currency);
    }

    /// @inheritdoc IRouxEdition
    function totalSupply(uint256 id) external view override returns (uint256) {
        return _storage().tokens[id].totalSupply;
    }

    /// @inheritdoc IRouxEdition
    function maxSupply(uint256 id) external view returns (uint256) {
        return _storage().tokens[id].maxSupply;
    }

    /// @inheritdoc IRouxEdition
    function uri(uint256 id) public view override(IRouxEdition, ERC1155) returns (string memory) {
        // get length
        uint256 urisLength = _storage().tokens[id].uris.length;

        // if current uri is set, return it
        if (urisLength > 0) {
            bytes32 digest = _storage().tokens[id].uris[urisLength - 1];
            return digest.generateTokenUri();
        } else {
            // otherwise return default uri
            return DEFAULT_TOKEN_URI;
        }
    }

    /// @inheritdoc IRouxEdition
    function uri(uint256 id, uint256 index) external view returns (string memory) {
        // get length
        uint256 urisLength = _storage().tokens[id].uris.length;

        // if current uri is set, return it
        if (urisLength > 0) {
            bytes32 digest = _storage().tokens[id].uris[index];
            return digest.generateTokenUri();
        } else {
            // otherwise return default uri
            return DEFAULT_TOKEN_URI;
        }
    }

    /// @inheritdoc IRouxEdition
    function currentUriIndex(uint256 id) external view returns (uint256) {
        return _storage().tokens[id].uris.length - 1;
    }

    /// @inheritdoc IRouxEdition
    function contractURI() external view override returns (string memory) {
        return _storage().contractURI;
    }

    /// @inheritdoc IRouxEdition
    function exists(uint256 id) external view returns (bool) {
        return _exists(id);
    }

    /// @inheritdoc IRouxEdition
    function isRegisteredExtension(uint256 id, address extension) external view returns (bool) {
        return _isRegisteredExtension(id, extension);
    }

    /// @inheritdoc IRouxEdition
    function isRegisteredCollection(address collection) external view returns (bool) {
        return _isRegisteredCollection(collection);
    }

    /// @inheritdoc IRouxEdition
    function defaultPrice(uint256 id) external view returns (uint128) {
        return _storage().tokens[id].mintParams.defaultPrice;
    }

    /// @inheritdoc IRouxEdition
    function isGated(uint256 id) external view returns (bool) {
        return _storage().tokens[id].mintParams.gate;
    }

    /// @inheritdoc IRouxEdition
    function defaultMintParams(uint256 id) external view returns (EditionData.MintParams memory) {
        return _storage().tokens[id].mintParams;
    }

    /// @inheritdoc IRouxEdition
    function multiCollectionMintEligible(uint256 id, address currency_) external view returns (bool) {
        EditionData.TokenData storage d = _storage().tokens[id];

        return _exists(id) && !d.mintParams.gate && currency_ == _currency;
    }

    /// @inheritdoc IRouxEdition
    function hasParent(uint256 id) external view returns (bool) {
        return _storage().tokens[id].hasParent;
    }

    /* ------------------------------------------------- */
    /* write                                             */
    /* ------------------------------------------------- */

    /// @inheritdoc IRouxEdition
    function mint(
        address to,
        uint256 id,
        uint256 quantity,
        address extension,
        address referrer,
        bytes calldata data
    )
        external
        payable
        nonReentrant
    {
        // validate and process mint
        uint256 price = _preProcessDirectMint(to, id, quantity, extension);

        if (price > 0) {
            // transfer payment to edition
            _currency.safeTransferFrom(msg.sender, address(this), price);

            // send funds to controller
            _controller.disburse({ edition: address(this), id: id, amount: price, referrer: referrer });
        }

        _mint(to, id, quantity, data);
    }

    /// @inheritdoc IRouxEdition
    function batchMint(
        address to,
        uint256[] calldata ids,
        uint256[] calldata quantities,
        address[] calldata extensions,
        address referrer,
        bytes calldata data
    )
        external
        payable
        nonReentrant
    {
        // validate array lengths
        if (ids.length != quantities.length || ids.length != extensions.length) {
            revert ErrorsLib.RouxEdition_InvalidParams();
        }

        // initialize vars
        uint256 totalPrice;
        uint256[] memory prices = new uint256[](ids.length);

        // process mints to validate and get total prices
        for (uint256 i = 0; i < ids.length; ++i) {
            prices[i] = _preProcessDirectMint(to, ids[i], quantities[i], extensions[i]);
            totalPrice += prices[i];
        }

        if (totalPrice > 0) {
            // transfer payment to edition
            _currency.safeTransferFrom(msg.sender, address(this), totalPrice);

            // disburse funds to controller
            for (uint256 i = 0; i < ids.length; ++i) {
                if (prices[i] > 0) {
                    _controller.disburse({ edition: address(this), id: ids[i], amount: prices[i], referrer: referrer });
                }
            }
        }

        _batchMint(to, ids, quantities, data);
    }

    /// @inheritdoc IRouxEdition
    function collectionSingleMint(
        address to,
        uint256[] memory ids,
        bytes calldata /*  data */
    )
        external
        payable
        nonReentrant
    {
        // validate caller
        if (!_isRegisteredCollection(msg.sender)) revert ErrorsLib.RouxEdition_InvalidCaller();

        // create quantities array + update total supply
        uint256[] memory quantities = new uint256[](ids.length);
        for (uint256 i = 0; i < ids.length; ++i) {
            quantities[i] = 1;
            _incrementTotalSupply(ids[i], 1);
        }

        _batchMint(to, ids, quantities, "");
    }

    /// @inheritdoc IRouxEdition
    function collectionMultiMint(address to, uint256 id, bytes calldata /* data */ ) external payable nonReentrant {
        // validate caller is collection
        if (!_collectionFactory.isCollection(msg.sender)) revert ErrorsLib.RouxEdition_InvalidCaller();

        _validateMint(id, 1);
        _incrementTotalSupply(id, 1);

        _mint(to, id, 1, "");
    }

    /// @inheritdoc IRouxEdition
    function adminMint(address to, uint256 id, uint256 quantity, bytes calldata data) external nonReentrant onlyOwner {
        // revert if fork
        if (_storage().tokens[id].hasParent) revert ErrorsLib.RouxEdition_HasParent();

        _validateMint(id, quantity);
        _incrementTotalSupply(id, quantity);

        _mint(to, id, quantity, data);
    }

    /// @inheritdoc IRouxEdition
    function adminBatchMint(
        address to,
        uint256[] memory ids,
        uint256[] memory quantities,
        bytes calldata data
    )
        external
        nonReentrant
        onlyOwner
    {
        // validate array lengths
        if (ids.length != quantities.length) {
            revert ErrorsLib.RouxEdition_InvalidParams();
        }

        for (uint256 i = 0; i < ids.length; ++i) {
            // revert if fork
            if (_storage().tokens[ids[i]].hasParent) revert ErrorsLib.RouxEdition_HasParent();

            _validateMint(ids[i], quantities[i]);
            _incrementTotalSupply(ids[i], quantities[i]);
        }

        _batchMint(to, ids, quantities, data);
    }

    /* ------------------------------------------------- */
    /* admin                                             */
    /* ------------------------------------------------- */

    /// @inheritdoc IRouxEdition
    function add(EditionData.AddParams calldata p) external onlyOwner nonReentrant returns (uint256) {
        RouxEditionStorage storage $ = _storage();

        uint256 id = ++$.tokenId;

        EditionData.TokenData storage d = $.tokens[id];

        if (p.maxSupply == 0) {
            revert ErrorsLib.RouxEdition_InvalidParams();
        }

        // set mint params
        d.mintParams = EditionData.MintParams({ defaultPrice: p.defaultPrice.toUint128(), gate: p.gate });

        // push uri to uri array
        d.uris.push(p.ipfsHash);

        // set token data
        d.maxSupply = p.maxSupply.toUint128();
        d.creator = msg.sender;

        // set controller data
        _controller.setControllerData(id, p.fundsRecipient, p.profitShare.toUint16());

        // optionally set registry data
        if (p.parentEdition != address(0) && p.parentTokenId != 0) {
            d.hasParent = true;
            _setRegistryData(id, p.parentEdition, p.parentTokenId);
        }

        // optionally add extension ~ enables extension by default
        if (p.extension != address(0)) {
            _setExtension(id, p.extension, true, p.options);
        }

        // mint token to creator ~ increment supply
        _incrementTotalSupply(id, 1);

        // mint token to creator
        _mint(msg.sender, id, 1, "");

        emit EventsLib.TokenAdded(id);

        return id;
    }

    /**
     * a
     * @notice update uri
     * @param id token id to update
     * @param ipfsHash new uri
     */
    function updateUri(uint256 id, bytes32 ipfsHash) external onlyOwnerOrRoles(URI_SETTER_ROLE) {
        _storage().tokens[id].uris.push(ipfsHash);

        emit URI(ipfsHash.generateTokenUri(), id);
    }

    /**
     * @notice update contract uri
     * @param newContractUri new contract uri
     */
    function updateContractUri(string memory newContractUri) external onlyOwnerOrRoles(URI_SETTER_ROLE) {
        _storage().contractURI = newContractUri;

        emit EventsLib.ContractURIUpdated(newContractUri);
    }

    /**
     * @notice sets or unsets an extension for an edition
     * @param id token id
     * @param extension extension address
     * @param enable enable or disable extension
     * @param options optional mint params
     */
    function setExtension(
        uint256 id,
        address extension,
        bool enable,
        bytes memory options
    )
        external
        onlyOwner
        nonReentrant
    {
        _setExtension(id, extension, enable, options);
    }

    /**
     * @notice update mint params for an edition extension
     * @param id token id
     * @param extension extension address
     * @param params updated extension mint params
     */
    function updateExtensionParams(
        uint256 id,
        address extension,
        bytes calldata params
    )
        external
        onlyOwner
        nonReentrant
    {
        // set sales params via extension
        IExtension(extension).setMintParams(id, params);
    }

    /**
     * @notice set collection
     * @param collection collection address
     * @param enable enable or disable collection
     *
     * @dev bypasses validation that token is ungated and exists; frontends should
     *      validate that token exists before calling this function as convenience
     */
    function setCollection(address collection, bool enable) external onlyOwner {
        if (enable) {
            // validate extension is not zero
            if (collection == address(0)) revert ErrorsLib.RouxEdition_InvalidCollection();

            // owner of the collection must be the caller (safety check)
            if (Collection(collection).owner() != msg.sender) revert ErrorsLib.RouxEdition_InvalidCollection();

            // validate extension interface support
            if (!ICollection(collection).supportsInterface(type(ICollection).interfaceId)) {
                revert ErrorsLib.RouxEdition_InvalidCollection();
            }

            // set collection
            _storage().collections.set(uint256(uint160(collection)));
        } else {
            // unset collection
            _storage().collections.unset(uint256(uint160(collection)));
        }
        emit EventsLib.CollectionSet(collection, enable);
    }

    /**
     * @notice update default price
     * @param id token id
     * @param newDefaultprice new default price
     */
    function updateDefaultPrice(uint256 id, uint256 newDefaultprice) external onlyOwner {
        // update default price
        _storage().tokens[id].mintParams.defaultPrice = newDefaultprice.toUint128();

        emit EventsLib.DefaultPriceUpdated(id, newDefaultprice);
    }

    /**
     * @notice update funds recipient
     * @param id token id
     * @param newFundsRecipient new funds recipient
     */
    function updateFundsRecipient(uint256 id, address newFundsRecipient) external onlyOwner {
        _controller.setFundsRecipient(id, newFundsRecipient);
    }

    /**
     * @notice update profit share
     * @param id token id
     * @param newProfitShare new profit share
     */
    function updateProfitShare(uint256 id, uint256 newProfitShare) external onlyOwner {
        _controller.setProfitShare(id, newProfitShare.toUint16());
    }

    /**
     * @notice gate mint
     * @param id token id
     *
     * @dev cannot be undone
     */
    function disableGate(uint256 id) external onlyOwner {
        _storage().tokens[id].mintParams.gate = false;

        emit EventsLib.GateDisabled(id);
    }

    /* ------------------------------------------------- */
    /* erc165 interface                                  */
    /* ------------------------------------------------- */

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, ERC165) returns (bool) {
        return interfaceId == type(IRouxEdition).interfaceId || interfaceId == type(IERC1155).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /* ------------------------------------------------- */
    /* internal                                          */
    /* ------------------------------------------------- */

    /**
     * @notice preprocess direct mint
     * @param to token receiver
     * @param id token id
     * @param quantity quantity
     * @param extension extension
     */
    function _preProcessDirectMint(
        address to,
        uint256 id,
        uint256 quantity,
        address extension
    )
        internal
        returns (uint256)
    {
        _validateMint(id, quantity);
        _incrementTotalSupply(id, quantity);

        return _getPrice(to, id, quantity, extension);
    }

    /**
     * @notice internal function to validate mint
     * @param id token id
     * @param quantity number of tokens to mint
     */
    function _validateMint(uint256 id, uint256 quantity) internal view {
        EditionData.TokenData storage d = _storage().tokens[id];

        // validate token exists
        if (!_exists(id)) revert ErrorsLib.RouxEdition_InvalidTokenId();

        // validate max supply
        if (quantity + d.totalSupply > d.maxSupply) {
            revert ErrorsLib.RouxEdition_MaxSupplyExceeded();
        }
    }

    /**
     * @notice compute price
     * @param to token receiver
     * @param id token id
     * @param quantity quantity
     * @param extension extension
     * @return price
     */
    function _getPrice(address to, uint256 id, uint256 quantity, address extension) internal returns (uint256 price) {
        EditionData.TokenData storage d = _storage().tokens[id];

        if (extension == address(0)) {
            // standard mint w/o extension
            if (d.mintParams.gate) revert ErrorsLib.RouxEdition_GatedMint();
            price = d.mintParams.defaultPrice * quantity;
        } else {
            // mint w/ extension - check if extension is registered
            if (!_isRegisteredExtension(id, extension)) revert ErrorsLib.RouxEdition_InvalidExtension();

            price = IExtension(extension).approveMint({
                id: id,
                quantity: quantity,
                operator: msg.sender,
                account: to,
                data: ""
            });
        }
    }

    /**
     * @notice increment total supply
     * @param id token id
     * @param quantity quantity
     */
    function _incrementTotalSupply(uint256 id, uint256 quantity) internal {
        _storage().tokens[id].totalSupply += quantity.toUint128();
    }

    /**
     * @notice set registry data
     * @param id token id
     * @param parentEdition parent edition
     * @param parentTokenId parent token id
     */
    function _setRegistryData(uint256 id, address parentEdition, uint256 parentTokenId) internal {
        // revert if not an edition or not a valid token
        if (!_editionFactory.isEdition(parentEdition) || !IRouxEdition(parentEdition).exists(parentTokenId)) {
            revert ErrorsLib.RouxEdition_InvalidAttribution();
        }

        // get current index
        uint256 idx = IRouxEdition(parentEdition).currentUriIndex(parentTokenId);

        // set registry data
        _registry.setRegistryData(id, parentEdition, parentTokenId, idx);
    }

    /**
     * @notice verify token exists
     * @param id token id
     */
    function _exists(uint256 id) internal view returns (bool) {
        return id != 0 && id <= _storage().tokenId;
    }

    /**
     * @notice internal function to set or update extension
     * @param id token id
     * @param extension extension
     * @param enable enable or disable extension
     * @param options optional mint params
     */
    function _setExtension(uint256 id, address extension, bool enable, bytes memory options) internal {
        // set extension
        if (enable) {
            // validate extension is not zero
            if (extension == address(0)) revert ErrorsLib.RouxEdition_InvalidExtension();

            // validate extension interface support
            if (!IExtension(extension).supportsInterface(type(IExtension).interfaceId)) {
                revert ErrorsLib.RouxEdition_InvalidExtension();
            }

            // set extension
            _storage().tokens[id].extensions.set(uint256(uint160(extension)));
        } else {
            // unset extension
            _storage().tokens[id].extensions.unset(uint256(uint160(extension)));
        }

        // set mint params if provided
        if (options.length > 0) IExtension(extension).setMintParams(id, options);

        // emit event
        emit EventsLib.ExtensionSet(extension, id, enable);
    }

    /**
     * @notice check if collection is registered
     * @param collection collection address
     * @return true if collection is registered
     */
    function _isRegisteredCollection(address collection) internal view returns (bool) {
        return _storage().collections.get(uint256(uint160(collection)));
    }

    /**
     * @notice check if extension is registered
     * @param id token id
     * @param extension extension address
     * @return true if extension is registered
     */
    function _isRegisteredExtension(uint256 id, address extension) internal view returns (bool) {
        return _storage().tokens[id].extensions.get(uint256(uint160(extension)));
    }
}
