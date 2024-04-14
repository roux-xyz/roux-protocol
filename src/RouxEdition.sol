// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC1155 } from "solady/tokens/ERC1155.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { IRouxEditionFactory } from "src/interfaces/IRouxEditionFactory.sol";
import { IRouxAdministrator } from "src/interfaces/IRouxAdministrator.sol";

contract RouxEdition is IRouxEdition, ERC1155, OwnableRoles {
    /* -------------------------------------------- */
    /* constants                                    */
    /* -------------------------------------------- */

    /**
     * @notice RouxEdition storage slot
     * @dev keccak256(abi.encode(uint256(keccak256("rouxEdition.rouxEditionStorage")) - 1)) & ~bytes32(uint256(0xff));
     */
    bytes32 internal constant ROUX_CREATOR_STORAGE_SLOT =
        0xef2f5668c8b56b992983464f11901aec8635a37d61a520221ade259ca1a88200;

    /**
     * @notice implementation version
     */
    string public constant IMPLEMENTATION_VERSION = "1.0";

    /**
     * @notice basis point scale
     */
    uint256 internal constant BASIS_POINT_SCALE = 10_000;

    /**
     * @notice attribution manager
     */
    IRouxAdministrator internal immutable _administrator;

    /* -------------------------------------------- */
    /* structures                                   */
    /* -------------------------------------------- */
    /**
     * @notice sale data
     */
    struct TokenSaleData {
        uint128 price;
        uint96 gap;
        uint64 maxSupply;
        uint40 mintStart;
        uint40 mintEnd;
        uint16 maxMintable;
    }

    /**
     * @notice token data
     * @dev profitShare represents share that child receives from primary sale
     */
    struct TokenData {
        uint64 totalSupply;
        string uri;
        TokenSaleData saleData;
    }

    /**
     * @notice RouxEdition storage
     * @custom:storage-location erc7201:rouxEdition.rouxEditionStorage
     *
     * @param _initialized whether the contract has been initialized
     * @param _creator creator of the contract
     * @param _tokenId current token id
     * @param _tokens mapping of token id to token data
     */
    struct RouxEditionStorage {
        bool _initialized;
        IRouxEditionFactory _factory;
        address _creator;
        uint256 _tokenId;
        mapping(uint256 tokenId => TokenData tokenData) _tokens;
    }

    /* -------------------------------------------- */
    /* constructor                                  */
    /* -------------------------------------------- */

    constructor(address administrator) {
        // disable initialization of implementation contract
        _storage()._initialized = true;

        // set attribution manager
        _administrator = IRouxAdministrator(administrator);
    }

    /* -------------------------------------------- */
    /* initializer                                  */
    /* -------------------------------------------- */

    function initialize() external {
        RouxEditionStorage storage $ = _storage();

        // initialize
        require(!$._initialized, "Already initialized");
        $._initialized = true;

        // set factory
        $._factory = IRouxEditionFactory(msg.sender);

        // factory transfers ownership to caller after initialization
        _initializeOwner(msg.sender);
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
            $.slot := ROUX_CREATOR_STORAGE_SLOT
        }
    }

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    /**
     * @inheritdoc IRouxEdition
     */
    function creator() external view returns (address) {
        return _storage()._creator;
    }

    /**
     * @inheritdoc IRouxEdition
     */
    function currentToken() external view returns (uint256) {
        return _storage()._tokenId;
    }

    /**
     * @inheritdoc IRouxEdition
     */
    function implementationVersion() external pure returns (string memory) {
        return IMPLEMENTATION_VERSION;
    }

    /**
     * @inheritdoc IRouxEdition
     */
    function totalSupply(uint256 id) external view override returns (uint256) {
        return _storage()._tokens[id].totalSupply;
    }

    /**
     * @inheritdoc IRouxEdition
     */
    function price(uint256 id) external view returns (uint256) {
        return _storage()._tokens[id].saleData.price;
    }

    /**
     * @inheritdoc IRouxEdition
     */
    function maxSupply(uint256 id) external view returns (uint256) {
        return _storage()._tokens[id].saleData.maxSupply;
    }

    /**
     * @inheritdoc IRouxEdition
     */
    function uri(uint256 id) public view override(IRouxEdition, ERC1155) returns (string memory) {
        return _storage()._tokens[id].uri;
    }

    /**
     * @inheritdoc IRouxEdition
     */
    function attribution(uint256 id) external view returns (address, uint256) {
        (address parentEdition, uint256 parentTokenId) = _administrator.attribution(address(this), id);

        return (parentEdition, parentTokenId);
    }

    /**
     * @inheritdoc IRouxEdition
     */
    function exists(uint256 id) external view returns (bool) {
        return id != 0 && id <= _storage()._tokenId;
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /**
     * @inheritdoc IRouxEdition
     */
    function mint(address to, uint256 id, uint64 quantity) external payable {
        // get storage
        RouxEditionStorage storage $ = _storage();

        // verify token id
        if (id == 0 || id > $._tokenId) revert InvalidTokenId();

        // verify mint is active
        if (block.timestamp < $._tokens[id].saleData.mintStart) revert MintNotStarted();
        if (block.timestamp > $._tokens[id].saleData.mintEnd) revert MintEnded();

        // verify quantity does not exceed max supply
        if (quantity + $._tokens[id].totalSupply > $._tokens[id].saleData.maxSupply) revert MaxSupplyExceeded();

        // verify quantity does not exceed max mintable by single address
        if (balanceOf(to, id) + quantity > $._tokens[id].saleData.maxMintable) revert MaxMintableExceeded();

        // verify sufficient funds
        if (msg.value < $._tokens[id].saleData.price * quantity) revert InsufficientFunds();

        // update total quantity
        _storage()._tokens[id].totalSupply += quantity;

        // mint
        _mint(to, id, quantity, "");

        // distribute funds via administrator
        _administrator.disburseMint{ value: msg.value }(id);
    }

    /* -------------------------------------------- */
    /* admin | onlyOwner                            */
    /* -------------------------------------------- */

    /**
     * @notice add a token to the contract
     * @param maxSupply_ max supply of the token
     * @param price_ price of the token
     * @param mintStart mint start
     * @param mintDuration mint duration
     * @param tokenUri token uri
     * @param fundsRecipient_ funds recipient - set in administrator
     * @param parentEdition parent edition - set in administrator
     * @param parentTokenId parent token id - set in administrator
     * @param profitShare profit share - set in administrator
     */
    function add(
        uint64 maxSupply_,
        uint128 price_,
        uint40 mintStart,
        uint40 mintDuration,
        string memory tokenUri,
        address fundsRecipient_,
        address parentEdition,
        uint256 parentTokenId,
        uint16 profitShare
    )
        external
        onlyOwner
        returns (uint256)
    {
        RouxEditionStorage storage $ = _storage();

        // if fork, price must be at least equal to parent
        if (parentEdition != address(0) && price_ < RouxEdition(parentEdition).price(parentTokenId)) {
            revert InvalidPrice();
        }

        // increment token id
        uint256 id = ++$._tokenId;

        // set token sale data
        TokenData storage d = $._tokens[id];
        d.saleData.maxSupply = maxSupply_;
        d.saleData.price = price_;
        d.saleData.mintStart = mintStart;
        d.saleData.mintEnd = mintStart + mintDuration;
        d.saleData.maxMintable = type(uint16).max;

        // set token uri
        d.uri = tokenUri;

        // set administration data
        _setAdministrationData(id, parentEdition, parentTokenId, fundsRecipient_, profitShare);

        emit TokenAdded(id, parentEdition, parentTokenId);

        return id;
    }

    /**
     * @notice update uri
     * @param id token id to update
     * @param newUri new uri
     */
    function updateUri(uint256 id, string memory newUri) external onlyOwner {
        _storage()._tokens[id].uri = newUri;

        emit URI(newUri, id);
    }

    /**
     * @inheritdoc IRouxEdition
     */
    function setCreator(address creator_) external onlyOwner {
        RouxEditionStorage storage $ = _storage();

        if ($._creator != address(0)) revert CreatorAlreadySet();
        $._creator = creator_;
    }

    /* -------------------------------------------- */
    /* internal                                     */
    /* -------------------------------------------- */

    /**
     * @notice set administration data
     * @param tokenId token id
     * @param parentEdition parent edition
     * @param parentTokenId parent token id
     * @param fundsRecipient funds recipient
     * @param profitShare profit share
     *
     * @dev sets administration data on the administrator
     */
    function _setAdministrationData(
        uint256 tokenId,
        address parentEdition,
        uint256 parentTokenId,
        address fundsRecipient,
        uint16 profitShare
    )
        internal
    {
        // check if parent edition has been provided
        if (parentEdition != address(0)) {
            // revert if parent is the same contract, not an edition, or not a valid token
            if (
                !_storage()._factory.isCreator(parentEdition) || !IRouxEdition(parentEdition).exists(parentTokenId)
                    || parentEdition == address(this)
            ) {
                revert InvalidAttribution();
            }
        }

        // set administration data via administrator
        _administrator.setAdministrationData(tokenId, parentEdition, parentTokenId, fundsRecipient, profitShare);
    }
}
