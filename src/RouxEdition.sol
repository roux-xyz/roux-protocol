// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { IRouxEditionFactory } from "src/interfaces/IRouxEditionFactory.sol";
import { ICollectionFactory } from "src/interfaces/ICollectionFactory.sol";
import { IController } from "src/interfaces/IController.sol";
import { IRegistry } from "src/interfaces/IRegistry.sol";
import { IEditionExtension } from "src/interfaces/IEditionExtension.sol";
import { ICollection } from "src/interfaces/ICollection.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { DEFAULT_TOKEN_URI } from "src/libraries/ConstantsLib.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { ERC1155 } from "solady/tokens/ERC1155.sol";
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ReentrancyGuard } from "solady/utils/ReentrancyGuard.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { Initializable } from "solady/utils/Initializable.sol";

import { EditionData } from "src/types/DataTypes.sol";

/**
 * @title Roux Edition
 * @author maks pazuniak (@maks-p)
 * @custom:version 0.1
 */
contract RouxEdition is IRouxEdition, ERC1155, ERC165, Initializable, OwnableRoles, ReentrancyGuard {
    using SafeCastLib for uint256;
    using SafeTransferLib for address;

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

    /* ------------------------------------------------- */
    /* immutable state                                   */
    /* ------------------------------------------------- */

    /// @notice registry
    IRegistry internal immutable _registry;

    /// @notice controller
    IController internal immutable _controller;

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
     * @param editionFactory edition factory
     * @param collectionFactory collection factory
     * @param collections mapping of enabled collections
     * @param tokens mapping of token id to token data
     */
    struct RouxEditionStorage {
        uint256 tokenId;
        string contractURI;
        IRouxEditionFactory editionFactory;
        ICollectionFactory collectionFactory;
        mapping(uint256 collectionId => mapping(address collection => bool enable)) collections;
        mapping(uint256 tokenId => EditionData.TokenData tokenData) tokens;
    }

    /* ------------------------------------------------- */
    /* constructor                                       */
    /* ------------------------------------------------- */

    /**
     * @notice constructor
     * @param controller controller
     * @param registry registry
     * @param currency_ currency
     */
    constructor(address controller, address registry, address currency_) {
        // disable initializers
        _disableInitializers();

        // set owner
        _initializeOwner(msg.sender);

        // set controller
        _controller = IController(controller);

        // set registry
        _registry = IRegistry(registry);

        // set currency
        _currency = currency_;

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

        // set edition factory
        $.editionFactory = IRouxEditionFactory(msg.sender);

        // set collection factory
        $.collectionFactory = ICollectionFactory(IRouxEditionFactory(msg.sender).collectionFactory());

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
        string memory currentUri = _storage().tokens[id].uri;

        // if current uri is set, return it
        if (bytes(currentUri).length > 0) {
            return currentUri;
        } else {
            // otherwise return default uri
            return DEFAULT_TOKEN_URI;
        }
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
    function isExtension(uint256 id, address extension) external view returns (bool) {
        if (extension == address(0)) revert ErrorsLib.RouxEdition_InvalidExtension();

        return _storage().tokens[id].extensions[extension];
    }

    /// @inheritdoc IRouxEdition
    function isCollection(uint256 collectionId, address collection) external view returns (bool) {
        return _storage().collections[collectionId][collection];
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
        EditionData.TokenData storage d = _storage().tokens[id];

        uint256 cost;
        if (extension == address(0)) {
            // gated mints require a valid extension
            if (d.mintParams.gate) revert ErrorsLib.RouxEdition_GatedMint();
            cost = d.mintParams.defaultPrice * quantity;
        } else {
            // validate extension is registered by edition
            if (!d.extensions[extension]) revert ErrorsLib.RouxEdition_InvalidExtension();

            // approve mint and get cost of mint
            cost = IEditionExtension(extension).approveMint({
                id: id,
                quantity: quantity,
                operator: msg.sender,
                account: to,
                data: data
            });
        }

        // mint
        _mintWithTransfers(to, id, quantity, cost, referrer, "");
    }

    /// @inheritdoc IRouxEdition
    function collectionSingleMint(
        address to,
        uint256[] memory ids,
        uint256 totalAmount,
        bytes calldata /*  data */
    )
        external
        payable
        nonReentrant
    {
        RouxEditionStorage storage $ = _storage();

        // encode collection ids
        uint256 collectionId = _encodeCollectionId(ids);

        // validate caller
        if (!$.collections[collectionId][msg.sender]) revert ErrorsLib.RouxEdition_InvalidCaller();

        // transfer payment to edition
        _currency.safeTransferFrom(msg.sender, address(this), totalAmount);

        // validate tokens + disburse funds
        uint256 derivedPrice = totalAmount / ids.length;
        uint256 currentValue = totalAmount;
        for (uint256 i = 0; i < ids.length; i++) {
            // cache id
            uint256 id = ids[i];

            // update total supply
            $.tokens[id].totalSupply++;

            // calculate funds disbursement
            uint256 allocatedValue = currentValue < derivedPrice ? currentValue : derivedPrice;
            currentValue -= allocatedValue;

            // send funds to controller - referrer was handled in collection `mint` function
            if (allocatedValue > 0) {
                _controller.disburse({ id: id, amount: allocatedValue, referrer: address(0) });
            }
        }

        // set quantities array
        uint256[] memory quantities = new uint256[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            quantities[i] = 1;
        }

        // mint
        _batchMint(to, ids, quantities, "");
    }

    /// @inheritdoc IRouxEdition
    function collectionMultiMint(
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    )
        external
        payable
        nonReentrant
    {
        RouxEditionStorage storage $ = _storage();

        // validate caller is a multi-edition collection
        if (!$.collectionFactory.isCollection(msg.sender)) revert ErrorsLib.RouxEdition_InvalidCaller();

        // mint
        _mintWithTransfers(to, id, 1, amount, address(0), data);
    }

    /* ------------------------------------------------- */
    /* admin                                             */
    /* ------------------------------------------------- */

    /// @inheritdoc IRouxEdition
    function add(EditionData.AddParams calldata p) external onlyOwner nonReentrant returns (uint256) {
        RouxEditionStorage storage $ = _storage();

        uint256 id = ++$.tokenId;

        EditionData.TokenData storage d = $.tokens[id];

        if (p.creator == address(0) || p.maxSupply == 0) {
            revert ErrorsLib.RouxEdition_InvalidParams();
        }

        // set mint params
        d.mintParams = EditionData.MintParams({ defaultPrice: p.defaultPrice.toUint128(), gate: p.gate });

        // set token data
        d.uri = p.tokenUri;
        d.creator = p.creator;
        d.maxSupply = p.maxSupply == 0 ? type(uint128).max : p.maxSupply.toUint128();

        // set controller data ~ funds recipient
        _controller.setControllerData(id, p.fundsRecipient, p.profitShare.toUint16());

        // optionally set registry data
        if (p.parentEdition != address(0) && p.parentTokenId != 0) {
            _setRegistryData(id, p.parentEdition, p.parentTokenId);
        }

        // optionally add extension ~ enables extension by default
        if (p.extension != address(0)) {
            _setExtension(id, p.extension, true, p.options);
        }

        // mint token to creator
        _unsafeMint(p.creator, id, 1, "");

        emit EventsLib.TokenAdded(id);

        return id;
    }

    /**
     * @notice update uri
     * @param id token id to update
     * @param newUri new uri
     *
     * @dev once a fork has been created, the uri is frozen and cannot be udpated.
     *      - to prevent a malicious user from "freezing" an unrevealed token, we only
     *        revert if a current uri has been set
     */
    function updateUri(uint256 id, string memory newUri) external onlyOwner {
        // current uri
        string memory currentUri = _storage().tokens[id].uri;

        // verify fork of existing metadata has not already been created
        if (bytes(currentUri).length > 0 && _registry.hasChild(address(this), id)) {
            revert ErrorsLib.RouxEdition_UriFrozen();
        }

        _storage().tokens[id].uri = newUri;

        emit URI(newUri, id);
    }

    /**
     * @notice update contract uri
     * @param newContractUri new contract uri
     */
    function updateContractUri(string memory newContractUri) external onlyOwner {
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
        IEditionExtension(extension).setMintParams(id, params);
    }

    /**
     * @notice set collection
     * @param collectionId encoded collection id
     * @param collection collection address
     * @param enable enable or disable collection
     *
     * @dev bypases validation that token is ungated and exists; frontends should
     *      validate that token exists before calling this function
     */
    function setCollection(
        uint256 collectionId,
        address collection,
        bool enable
    )
        external
        onlyOwner
        returns (uint256)
    {
        // validate collection id
        if (collectionId == 0) revert ErrorsLib.RouxEdition_InvalidParams();

        // validate collection
        if (enable) _validateCollection(collection);

        // enable or disable collection
        _storage().collections[collectionId][collection] = enable;

        emit EventsLib.CollectionSet(collection, collectionId, enable);

        return collectionId;
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
     */
    function disableGate(uint256 id) external onlyOwner {
        _storage().tokens[id].mintParams.gate = false;

        emit EventsLib.GateDisabled(id);
    }

    /* ------------------------------------------------- */
    /* erc165 interface                                */
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
     * @notice internal mint with transfers
     * @param to token receiver
     * @param id token id
     * @param quantity number of tokens to mint
     * @param amount amount
     * @param referrer referrer
     * @param data additional data
     * @dev validates, transfers payments in and to controller
     */
    function _mintWithTransfers(
        address to,
        uint256 id,
        uint256 quantity,
        uint256 amount,
        address referrer,
        bytes memory data
    )
        internal
    {
        // validate mint
        _validateMint(id, quantity);

        // transfer payment to edition
        _currency.safeTransferFrom(msg.sender, address(this), amount);

        // send funds to controller
        if (amount > 0) _controller.disburse(id, amount, referrer);

        // mint
        _unsafeMint(to, id, quantity, data);
    }

    /**
     * @notice internal mint function
     * @param to token receiver
     * @param id token id
     * @param quantity number of tokens to mint
     * @param data additional data
     *
     * @dev unvalidated mint function to update total supply before calling erc1155 mint
     */
    function _unsafeMint(address to, uint256 id, uint256 quantity, bytes memory data) internal {
        // increment supply
        _storage().tokens[id].totalSupply += quantity.toUint128();

        // call erc1155 mint
        _mint(to, id, quantity, data);
    }

    /**
     * @notice set registry data
     * @param id token id
     * @param parentEdition parent edition
     * @param parentTokenId parent token id
     */
    function _setRegistryData(uint256 id, address parentEdition, uint256 parentTokenId) internal {
        // revert if not an edition or not a valid token, or edition is self
        if (
            !_storage().editionFactory.isEdition(parentEdition) || !IRouxEdition(parentEdition).exists(parentTokenId)
                || parentEdition == address(this)
        ) {
            revert ErrorsLib.RouxEdition_InvalidAttribution();
        }

        // set registry data
        _registry.setRegistryData(id, parentEdition, parentTokenId);
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
        // validate extension if enabling
        if (enable) _validateExtension(extension);

        // set extension
        _storage().tokens[id].extensions[extension] = enable;

        // set mint params if provided
        if (options.length > 0) IEditionExtension(extension).setMintParams(id, options);

        // emit event
        emit EventsLib.ExtensionSet(extension, id, enable);
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
     * @notice validate extension
     * @param extension extension
     */
    function _validateExtension(address extension) internal view {
        // validate extension is not zero
        if (extension == address(0)) revert ErrorsLib.RouxEdition_InvalidExtension();

        // validate extension interface support
        if (!IEditionExtension(extension).supportsInterface(type(IEditionExtension).interfaceId)) {
            revert ErrorsLib.RouxEdition_InvalidExtension();
        }
    }

    /**
     * @notice validate extension
     * @param collection extension
     */
    function _validateCollection(address collection) internal view {
        // validate extension is not zero
        if (collection == address(0)) revert ErrorsLib.RouxEdition_InvalidCollection();

        // validate extension interface support
        if (!ICollection(collection).supportsInterface(type(ICollection).interfaceId)) {
            revert ErrorsLib.RouxEdition_InvalidCollection();
        }
    }

    /**
     * @notice encode batch id
     * @param ids token ids
     */
    function _encodeCollectionId(uint256[] memory ids) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(ids)));
    }
}
