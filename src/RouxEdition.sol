// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { ERC1155 } from "solady/tokens/ERC1155.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { ReentrancyGuard } from "solady/utils/ReentrancyGuard.sol";

import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { IRouxEditionFactory } from "src/interfaces/IRouxEditionFactory.sol";
import { IController } from "src/interfaces/IController.sol";
import { IRegistry } from "src/interfaces/IRegistry.sol";
import { IEditionMinter } from "src/interfaces/IEditionMinter.sol";

/**
 * @title Roux Edition
 * @author Roux
 */
contract RouxEdition is IRouxEdition, ERC1155, OwnableRoles, ReentrancyGuard {
    using SafeCast for uint256;

    /* -------------------------------------------- */
    /* constants                                    */
    /* -------------------------------------------- */

    /**
     * @notice RouxEdition storage slot
     * @dev keccak256(abi.encode(uint256(keccak256("rouxEdition.rouxEditionStorage")) - 1)) & ~bytes32(uint256(0xff));
     */
    bytes32 internal constant ROUX_EDITION_STORAGE_SLOT =
        0xef2f5668c8b56b992983464f11901aec8635a37d61a520221ade259ca1a88200;

    /**
     * @notice implementation version
     */
    string public constant IMPLEMENTATION_VERSION = "0.1";

    /* -------------------------------------------- */
    /* immutable state                              */
    /* -------------------------------------------- */

    /**
     * @notice registry
     */
    IRegistry internal immutable _registry;

    /**
     * @notice controller
     */
    IController internal immutable _controller;

    /* -------------------------------------------- */
    /* structures                                   */
    /* -------------------------------------------- */

    /**
     * @notice RouxEdition storage
     * @custom:storage-location erc7201:rouxEdition.rouxEditionStorage
     *
     * @param initialized whether the contract has been initialized
     * @param factory roux edition factory
     * @param tokenId current token id
     * @param contractURI contract uri
     * @param tokens mapping of token id to token data
     */
    struct RouxEditionStorage {
        bool initialized;
        IRouxEditionFactory factory;
        uint256 tokenId;
        string contractURI;
        mapping(uint256 batchId => mapping(address batchMinter => bool enable)) batchMinters;
        mapping(uint256 tokenId => TokenData tokenData) tokens;
    }

    /* -------------------------------------------- */
    /* constructor                                  */
    /* -------------------------------------------- */

    /**
     * @notice constructor
     * @param controller controller
     * @param registry registry
     */
    constructor(address controller, address registry) {
        // disable initialization of implementation contract
        _storage().initialized = true;

        // set owner
        _initializeOwner(msg.sender);

        // set controller
        _controller = IController(controller);

        // set registry
        _registry = IRegistry(registry);

        // renounce ownership of implementation contract
        renounceOwnership();
    }

    /* -------------------------------------------- */
    /* initializer                                  */
    /* -------------------------------------------- */

    /**
     * @notice initialize RouxEdition
     * @param contractURI_ contract uri
     */
    function initialize(string memory contractURI_) external nonReentrant {
        RouxEditionStorage storage $ = _storage();

        // initialize
        require(!$.initialized, "Already initialized");
        $.initialized = true;

        // factory transfers ownership to caller after initialization
        _initializeOwner(msg.sender);

        // set factory
        $.factory = IRouxEditionFactory(msg.sender);

        // set contract uri
        $.contractURI = contractURI_;
    }

    /* -------------------------------------------- */
    /* storage                                      */
    /* -------------------------------------------- */

    /**
     * @notice get RouxEdition storage location
     * @return $ RouxEdition storage location
     */
    function _storage() internal pure returns (RouxEditionStorage storage $) {
        assembly {
            $.slot := ROUX_EDITION_STORAGE_SLOT
        }
    }

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    /**
     * @inheritdoc IRouxEdition
     */
    function creator(uint256 id) external view returns (address) {
        return _storage().tokens[id].creator;
    }

    /**
     * @inheritdoc IRouxEdition
     */
    function currentToken() external view returns (uint256) {
        return _storage().tokenId;
    }

    /**
     * @inheritdoc IRouxEdition
     */
    function totalSupply(uint256 id) external view override returns (uint256) {
        return _storage().tokens[id].totalSupply;
    }

    /**
     * @inheritdoc IRouxEdition
     */
    function uri(uint256 id) public view override(IRouxEdition, ERC1155) returns (string memory) {
        return _storage().tokens[id].uri;
    }

    /**
     * @inheritdoc IRouxEdition
     */
    function contractURI() external view override returns (string memory) {
        return _storage().contractURI;
    }

    /**
     * @inheritdoc IRouxEdition
     */
    function exists(uint256 id) external view returns (bool) {
        return _exists(id);
    }

    /**
     * @inheritdoc IRouxEdition
     */
    function isMinter(uint256 id, address minter) external view returns (bool) {
        return _storage().tokens[id].minters[minter];
    }

    /**
     * @inheritdoc IRouxEdition
     */
    function isBatchMinter(uint256 batchId, address minter) external view returns (bool) {
        return _storage().batchMinters[batchId][minter];
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /**
     * @inheritdoc IRouxEdition
     */
    function mint(address to, uint256 id, uint256 quantity, bytes calldata /*  data */ ) external nonReentrant {
        RouxEditionStorage storage $ = _storage();

        // validate caller
        if (!$.tokens[id].minters[msg.sender]) revert InvalidCaller();

        // verify token exists
        if (!_exists(id)) revert InvalidTokenId();

        // validate max supply
        if (quantity + $.tokens[id].totalSupply > $.tokens[id].maxSupply) revert MaxSupplyExceeded();

        // mint
        _mint(to, id, quantity, "");
    }

    /**
     * @inheritdoc IRouxEdition
     */
    function batchMint(
        address to,
        uint256[] memory ids,
        uint256[] memory quantities,
        bytes calldata /*  data */
    )
        external
        nonReentrant
    {
        RouxEditionStorage storage $ = _storage();

        // encode batch id
        uint256 batchId = _encodeBatchId(ids);

        // validate caller
        if (!$.batchMinters[batchId][msg.sender]) revert InvalidCaller();

        // validate tokens
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];

            // verify token exists
            if (!_exists(id)) revert InvalidTokenId();

            // validate max supply
            if (quantities[i] + $.tokens[id].totalSupply > $.tokens[id].maxSupply) revert MaxSupplyExceeded();
        }

        // mint
        _batchMint(to, ids, quantities, "");
    }

    /* -------------------------------------------- */
    /* admin | onlyOwner                            */
    /* -------------------------------------------- */

    /**
     * @inheritdoc IRouxEdition
     */
    function add(
        string memory tokenUri,
        address creator_,
        uint256 maxSupply,
        address fundsRecipient,
        uint256 profitShare,
        address parentEdition,
        uint256 parentTokenId,
        address minter,
        bytes memory options
    )
        external
        onlyOwner
        nonReentrant
        returns (uint256)
    {
        return _add(
            tokenUri, creator_, maxSupply, fundsRecipient, profitShare, parentEdition, parentTokenId, minter, options
        );
    }

    /**
     * @notice update uri
     * @param id token id to update
     * @param newUri new uri
     */
    function updateUri(uint256 id, string memory newUri) external onlyOwner {
        _storage().tokens[id].uri = newUri;

        emit URI(newUri, id);
    }

    /**
     * @notice update contract uri
     * @param newContractUri new contract uri
     */
    function updateContractUri(string memory newContractUri) external onlyOwner {
        _storage().contractURI = newContractUri;

        emit ContractURIUpdated();
    }

    /**
     * @notice add minter
     * @param id token id
     * @param minter minter address
     * @param enable enable or disable minter
     * @param options optional mint params
     */
    function setMinter(uint256 id, address minter, bool enable, bytes memory options) external onlyOwner nonReentrant {
        _setMinter(id, minter, enable);

        // set mint params if provided
        if (options.length > 0) _setMintParams(id, minter, options);
    }

    /**
     * @notice add batch minter
     * @param batchId batchId (encoded token ids)
     * @param minter minter address
     * @param enable enable or disable batch minter
     * @param options optional mint params
     *
     * @dev derive batchId using `uint256(keccak256(abi.encode(tokenIds)))`
     */
    function setBatchMinter(
        uint256 batchId,
        address minter,
        bool enable,
        bytes memory options
    )
        external
        onlyOwner
        nonReentrant
    {
        // validate minter
        _validateMinter(minter);

        // set batch minter
        _storage().batchMinters[batchId][minter] = enable;

        // set mint params if provided
        if (options.length > 0) _setMintParams(batchId, minter, options);

        // emit event
        emit BatchMinterAdded(minter);
    }

    /**
     * @notice update mint params
     */
    function updateMintParams(uint256 id, address minter, bytes calldata params) external onlyOwner nonReentrant {
        // set sales params via minter
        _setMintParams(id, minter, params);
    }

    /**
     * @notice update controller data
     */
    function updateControllerData(
        uint256 id,
        address newFundsRecipient,
        uint256 newProfitShare
    )
        external
        onlyOwner
        nonReentrant
    {
        // set controller data
        _setControllerData(id, newFundsRecipient, newProfitShare);
    }

    /* -------------------------------------------- */
    /* internal | core                              */
    /* -------------------------------------------- */

    /**
     * @notice internal function to add token
     * @param tokenUri token uri
     * @param creator_ creator
     * @param maxSupply max supply
     * @param fundsRecipient funds recipient
     * @param profitShare profit share
     * @param parentEdition parent edition - zero if original
     * @param parentTokenId parent token id - zero if original
     * @param minter minter - must be provided to add token
     * @param options additional options - mint params
     *
     * @dev makes external calls to set controller and set registry (if attribution included)
     *      sets optional mint params, if provided
     *      mints token to creator
     */
    function _add(
        string memory tokenUri,
        address creator_,
        uint256 maxSupply,
        address fundsRecipient,
        uint256 profitShare,
        address parentEdition,
        uint256 parentTokenId,
        address minter,
        bytes memory options
    )
        internal
        returns (uint256)
    {
        RouxEditionStorage storage $ = _storage();

        // increment token id
        uint256 id = ++$.tokenId;

        // get storage pointer
        TokenData storage d = $.tokens[id];

        // validate params (fundsRecipient and profitShare validated in Controller)
        if (
            creator_ == address(0) || maxSupply == 0 || (parentEdition != address(0) && parentTokenId == 0)
                || (parentEdition == address(0) && parentTokenId != 0)
        ) revert InvalidParams();

        // set token data
        d.uri = tokenUri;
        d.creator = creator_;
        d.maxSupply = maxSupply.toUint128();

        // set controller data
        _setControllerData(id, fundsRecipient, profitShare);

        // optionally add minter
        if (minter != address(0)) _setMinter(id, minter, true);

        // optionally set registry data
        if (parentEdition != address(0) && parentTokenId != 0) _setRegistryData(id, parentEdition, parentTokenId);

        // set optional params in minter if provided - not all minters will require this
        if (options.length > 0) _setMintParams(id, minter, options);

        // mint token to creator
        _mint(creator_, id, 1, "");

        emit TokenAdded(id);

        return id;
    }

    /**
     * @notice set administrator data
     * @param id token id
     * @param parentEdition parent edition
     * @param parentTokenId parent token id
     *
     * @dev sets administrator data on the administrator
     */
    function _setRegistryData(uint256 id, address parentEdition, uint256 parentTokenId) internal {
        // revert if not an edition or not a valid token
        if (!_storage().factory.isEdition(parentEdition) || !IRouxEdition(parentEdition).exists(parentTokenId)) {
            revert InvalidAttribution();
        }

        // set registry data
        _registry.setRegistryData(id, parentEdition, parentTokenId);
    }

    /**
     * @notice set mint params
     * @param id token id
     * @param options minter options
     */
    function _setMintParams(uint256 id, address minter, bytes memory options) internal {
        // set sales params via minter
        IEditionMinter(minter).setMintParams(id, options);
    }

    function _setControllerData(uint256 id, address fundsRecipient, uint256 profitShare) internal {
        // set controller data
        _controller.setControllerData(id, fundsRecipient, profitShare.toUint16());
    }

    /**
     * @notice verify token exists
     * @param id token id
     */
    function _exists(uint256 id) internal view returns (bool) {
        return id != 0 && id <= _storage().tokenId;
    }

    /**
     * @notice internal function to mint
     * @param to token receiver
     * @param id token id
     * @param quantity number of tokens to mint
     * @param data additional data
     *
     * @dev updates total supply
     */
    function _mint(address to, uint256 id, uint256 quantity, bytes memory data) internal override {
        // update total quantity
        _storage().tokens[id].totalSupply += quantity.toUint128();

        // mint
        super._mint(to, id, quantity, data);
    }

    /**
     * @notice internal function to batch mint
     * @param to token receiver
     * @param ids array of token ids
     * @param quantities array of token quantities
     * @param data additional data
     */
    function _batchMint(
        address to,
        uint256[] memory ids,
        uint256[] memory quantities,
        bytes memory data
    )
        internal
        override
    {
        // update total supply
        for (uint256 i = 0; i < ids.length; i++) {
            _storage().tokens[ids[i]].totalSupply += quantities[i].toUint128();
        }

        // mint
        super._batchMint(to, ids, quantities, data);
    }

    /**
     * @notice internal function to add minter
     * @param id token id
     * @param minter minter
     * @param enable enable or disable minter
     */
    function _setMinter(uint256 id, address minter, bool enable) internal {
        // validate minter if enabling
        if (enable) _validateMinter(minter);

        // set minter
        _storage().tokens[id].minters[minter] = enable;

        // emit event
        emit MinterAdded(minter, id);
    }

    /* -------------------------------------------- */
    /* internal | utility                           */
    /* -------------------------------------------- */

    /**
     * @notice validate minter
     * @param minter minter
     */
    function _validateMinter(address minter) internal view {
        // validate minter is not zero
        if (minter == address(0)) revert InvalidMinter();

        // validate minter interface support
        if (!IEditionMinter(minter).supportsInterface(type(IEditionMinter).interfaceId)) revert InvalidMinter();
    }

    /**
     * @notice encode batch id
     * @param ids token ids
     */
    function _encodeBatchId(uint256[] memory ids) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(ids)));
    }
}
