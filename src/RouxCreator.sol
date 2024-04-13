// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC1155 } from "solady/tokens/ERC1155.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { IRouxCreator } from "src/interfaces/IRouxCreator.sol";
import { IRouxCreatorFactory } from "src/interfaces/IRouxCreatorFactory.sol";
import { IRouxAdministrator } from "src/interfaces/IRouxAdministrator.sol";

contract RouxCreator is IRouxCreator, ERC1155, OwnableRoles {
    /* -------------------------------------------- */
    /* constants                                    */
    /* -------------------------------------------- */

    /**
     * @notice RouxCreator storage slot
     * @dev keccak256(abi.encode(uint256(keccak256("erc7201:rouxCreator")) - 1)) & ~bytes32(uint256(0xff));
     */
    bytes32 internal constant ROUX_CREATOR_STORAGE_SLOT =
        0xb58054ed73afeea56f113b62f99d32ce889cc871485db9295a43d8f4bffd7800;

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
     * @notice RouxCreator storage
     * @custom:storage-location erc7201:rouxCreator
     *
     * @param _initialized whether the contract has been initialized
     * @param _creator creator of the contract
     * @param _tokenId current token id
     * @param _tokens mapping of token id to token data
     */
    struct RouxCreatorStorage {
        bool _initialized;
        IRouxCreatorFactory _factory;
        address _creator;
        uint256 _tokenId;
        mapping(uint256 tokenId => TokenData tokenData) _tokens;
    }

    /* -------------------------------------------- */
    /* constructor                                  */
    /* -------------------------------------------- */

    constructor(address administrator) {
        /* disable initialization of implementation contract */
        _storage()._initialized = true;

        /* set attribution manager */
        _administrator = IRouxAdministrator(administrator);
    }

    /* -------------------------------------------- */
    /* initializer                                  */
    /* -------------------------------------------- */

    function initialize() external {
        RouxCreatorStorage storage $ = _storage();

        require(!$._initialized, "Already initialized");
        $._initialized = true;

        /* set factory */
        $._factory = IRouxCreatorFactory(msg.sender);

        /* factory will transfer ownership to caller */
        _initializeOwner(msg.sender);
    }

    /* -------------------------------------------- */
    /* storage                                      */
    /* -------------------------------------------- */

    /**
     * @notice get RouxCreator storage location
     * @return $ RouxCreator storage location
     */
    function _storage() internal pure returns (RouxCreatorStorage storage $) {
        assembly {
            $.slot := ROUX_CREATOR_STORAGE_SLOT
        }
    }

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    function creator() external view returns (address) {
        return _storage()._creator;
    }

    function currentToken() external view returns (uint256) {
        return _storage()._tokenId;
    }

    function implementationVersion() external pure returns (string memory) {
        return IMPLEMENTATION_VERSION;
    }

    function totalSupply(uint256 id) external view override returns (uint256) {
        return _storage()._tokens[id].totalSupply;
    }

    function price(uint256 id) external view returns (uint256) {
        return _storage()._tokens[id].saleData.price;
    }

    function maxSupply(uint256 id) external view returns (uint256) {
        return _storage()._tokens[id].saleData.maxSupply;
    }

    function uri(uint256 id) public view override(IRouxCreator, ERC1155) returns (string memory) {
        return _storage()._tokens[id].uri;
    }

    function attribution(uint256 id) external view returns (address, uint256) {
        (address parentEdition, uint256 parentTokenId) = _administrator.attribution(address(this), id);

        return (parentEdition, parentTokenId);
    }

    function exists(uint256 id) external view returns (bool) {
        return id != 0 && id <= _storage()._tokenId;
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    function mint(address to, uint256 id, uint64 quantity) external payable {
        RouxCreatorStorage storage $ = _storage();

        if (id == 0 || id > $._tokenId) revert InvalidTokenId();

        if (block.timestamp < $._tokens[id].saleData.mintStart) revert MintNotStarted();
        if (block.timestamp > $._tokens[id].saleData.mintEnd) revert MintEnded();

        if (quantity + $._tokens[id].totalSupply > $._tokens[id].saleData.maxSupply) revert MaxSupplyExceeded();
        if (balanceOf(to, id) + quantity > $._tokens[id].saleData.maxMintable) revert MaxMintableExceeded();

        if (msg.value < $._tokens[id].saleData.price * quantity) revert InsufficientFunds();

        // update total quantity
        _storage()._tokens[id].totalSupply += quantity;

        _mint(to, id, quantity, "");

        // distribute funds
        _administrator.disburseMint{ value: msg.value }(id);
    }

    /* -------------------------------------------- */
    /* admin | onlyOwner                            */
    /* -------------------------------------------- */

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
        RouxCreatorStorage storage $ = _storage();

        // if fork, price must be at least equal to parent
        if (parentEdition != address(0) && price_ < RouxCreator(parentEdition).price(parentTokenId)) {
            revert InvalidParam();
        }

        uint256 id = ++$._tokenId;

        TokenData storage d = $._tokens[id];
        d.saleData.maxSupply = maxSupply_;
        d.saleData.price = price_;
        d.saleData.mintStart = mintStart;
        d.saleData.mintEnd = mintStart + mintDuration;
        d.saleData.maxMintable = type(uint16).max;

        d.uri = tokenUri;

        _setAdministrationData(id, parentEdition, parentTokenId, fundsRecipient_, profitShare);

        emit TokenAdded(id, parentEdition, parentTokenId);

        return id;
    }

    function updatePrice(uint256 id, uint128 price_) external onlyOwner {
        _storage()._tokens[id].saleData.price = price_;
    }

    function updateUri(uint256 id, string memory newUri) external onlyOwner {
        _storage()._tokens[id].uri = newUri;

        emit URI(newUri, id);
    }

    function updateAdministrationData(
        uint256 id,
        address parentEdition,
        uint256 parentTokenId,
        address fundsRecipient,
        uint16 profitShare
    )
        external
        onlyOwner
    {
        _setAdministrationData(id, parentEdition, parentTokenId, fundsRecipient, profitShare);
    }

    function setCreator(address creator_) external onlyOwner {
        RouxCreatorStorage storage $ = _storage();

        if ($._creator != address(0)) revert CreatorAlreadySet();
        $._creator = creator_;
    }

    /* -------------------------------------------- */
    /* internal                                     */
    /* -------------------------------------------- */

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
            // revert if parent is the same contract, not an edition or not a valid token
            if (
                !_storage()._factory.isCreator(parentEdition) || !IRouxCreator(parentEdition).exists(parentTokenId)
                    || parentEdition == address(this)
            ) {
                revert InvalidAttribution();
            }
        }

        _administrator.setAdministrationData(tokenId, parentEdition, parentTokenId, fundsRecipient, profitShare);
    }
}
