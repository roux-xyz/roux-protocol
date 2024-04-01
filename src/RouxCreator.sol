// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { IRouxCreator } from "src/interfaces/IRouxCreator.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract RouxCreator is IRouxCreator, ERC1155 {
    using SafeCast for uint256;

    /* -------------------------------------------- */
    /* structures                                   */
    /* -------------------------------------------- */

    struct TokenData {
        uint64 totalSupply;
        uint64 maxSupply;
        uint128 price;
        uint256 attribution;
        string uri;
    }

    /* -------------------------------------------- */
    /* state                                        */
    /* -------------------------------------------- */

    bool internal _initialized;

    address internal _owner;

    address internal _creator;

    uint256 internal _tokenId;

    mapping(uint256 => TokenData) internal _tokens;

    /* -------------------------------------------- */
    /* constructor                                  */
    /* -------------------------------------------- */

    constructor() ERC1155("") {
        /* disable initialization of implementation contract */
        _initialized = true;
    }

    /* -------------------------------------------- */
    /* initializer                                  */
    /* -------------------------------------------- */

    function initialize(bytes calldata params) external {
        require(!_initialized, "Already initialized");
        _initialized = true;

        (address owner_) = abi.decode(params, (address));

        _owner = owner_;
        _creator = owner_;
    }

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    function creator() external view returns (address) {
        return _creator;
    }

    function owner() external view returns (address) {
        return _owner;
    }

    function tokenCount() external view returns (uint256) {
        return _tokenId;
    }

    function totalSupply(uint256 id) external view override returns (uint256) {
        return _tokens[id].totalSupply;
    }

    function price(uint256 id) external view returns (uint256) {
        return _tokens[id].price;
    }

    function maxSupply(uint256 id) external view returns (uint256) {
        return _tokens[id].maxSupply;
    }

    function uri(uint256 id) public view override(IRouxCreator, ERC1155) returns (string memory) {
        return _tokens[id].uri;
    }

    function attribution(uint256 id) external view returns (address, uint96) {
        return _decodeAttribution(_tokens[id].attribution);
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    function mint(address to, uint256 id, uint256 quantity_) external payable {
        uint64 _quantity = quantity_.toUint64();

        if (id == 0 || id > _tokenId) revert InvalidTokenId();
        if (_quantity + _tokens[id].totalSupply > _tokens[id].maxSupply) revert MaxSupplyExceeded();
        if (msg.value < _tokens[id].price * _quantity) revert InsufficientFunds();

        // update total quantity
        _tokens[id].totalSupply += _quantity;

        _mint(to, id, _quantity, "");
    }

    /* -------------------------------------------- */
    /* admin                                        */
    /* -------------------------------------------- */

    // @notice add a new token id to the contract
    function add(uint256 maxSupply_, uint256 price_, string memory tokenUri) external returns (uint256) {
        if (msg.sender != _owner) revert OnlyOwner();

        return _add(maxSupply_, price_, tokenUri, 0);
    }

    function add(
        uint256 maxSupply_,
        uint256 price_,
        string memory tokenUri,
        address parentContract,
        uint96 parentId
    )
        external
        returns (uint256)
    {
        if (msg.sender != _owner) revert OnlyOwner();
        uint256 attribution_ = _encodeAttribution(parentContract, parentId);

        return _add(maxSupply_, price_, tokenUri, attribution_);
    }

    function updateUri(uint256 id, string memory newUri) external {
        if (msg.sender != _owner) revert OnlyOwner();

        _tokens[id].uri = newUri;

        emit URI(newUri, id);
    }

    function withdraw() external {
        if (msg.sender != _owner) revert OnlyOwner();

        (bool success,) = payable(msg.sender).call{ value: address(this).balance }("");
        if (!success) revert TransferFailed();
    }

    function updateOwner(address newOwner) external {
        if (msg.sender != _owner) revert OnlyOwner();
        _owner = newOwner;
    }

    /* -------------------------------------------- */
    /* internal                                     */
    /* -------------------------------------------- */

    function _add(
        uint256 maxSupply_,
        uint256 price_,
        string memory tokenUri,
        uint256 attribution_
    )
        internal
        returns (uint256)
    {
        uint64 _maxSupply = maxSupply_.toUint64();
        uint128 _price = price_.toUint128();

        uint256 id = ++_tokenId;

        _tokens[id] = TokenData({
            maxSupply: _maxSupply,
            totalSupply: 0,
            price: _price,
            uri: tokenUri,
            attribution: attribution_
        });

        emit TokenAdded(id);

        return id;
    }

    function _encodeAttribution(address creator_, uint96 tokenId_) internal pure returns (uint256) {
        return uint256(uint160(creator_)) << 96 | tokenId_;
    }

    function _decodeAttribution(uint256 attribution_) internal pure returns (address, uint96) {
        return (address(uint160(attribution_ >> 96)), uint96(attribution_));
    }
}
