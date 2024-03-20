// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { IRouxCreator } from "src/interfaces/IRouxCreator.sol";

contract RouxCreator is IRouxCreator, ERC1155 {
    /* -------------------------------------------- */
    /* structures                                   */
    /* -------------------------------------------- */

    struct TokenData {
        uint256 maxSupply;
        uint256 totalSupply;
        uint256 price;
        string uri;
    }

    /* -------------------------------------------- */
    /* state                                        */
    /* -------------------------------------------- */

    bool internal _initialized;

    address internal _owner;

    uint256 internal _tokenIds;

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
    }

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    function owner() external view returns (address) {
        return _owner;
    }

    function totalSupply(uint256 id) public view override returns (uint256) {
        return _tokens[id].totalSupply;
    }

    function uri(uint256 id) public view override(IRouxCreator, ERC1155) returns (string memory) {
        return _tokens[id].uri;
    }

    function price(uint256 id) external view returns (uint256) {
        return _tokens[id].price;
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    function mint(address to, uint256 id, uint256 quantity) external payable {
        if (id == 0 || id > _tokenIds) revert InvalidTokenId();
        if (quantity + _tokens[id].totalSupply > _tokens[id].maxSupply) revert MaxSupplyExceeded();
        if (msg.value < _tokens[id].price * quantity) revert InsufficientFunds();

        _tokens[id].totalSupply += quantity;

        _mint(to, id, quantity, "");
    }

    /* -------------------------------------------- */
    /* admin                                        */
    /* -------------------------------------------- */

    // @notice add a new token id to the contract
    // @supply maxSupply of the token
    function add(uint256 maxSupply, uint256 price_, string memory tokenUri) external returns (uint256) {
        if (msg.sender != _owner) revert OnlyOwner();
        return _add(maxSupply, price_, tokenUri);
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

    /* -------------------------------------------- */
    /* internal                                     */
    /* -------------------------------------------- */

    function _add(uint256 maxSupply, uint256 price_, string memory tokenUri) internal returns (uint256) {
        uint256 id = ++_tokenIds;
        _tokens[id] = TokenData({ maxSupply: maxSupply, totalSupply: 0, price: price_, uri: tokenUri });

        emit TokenAdded(id);

        return id;
    }
}
