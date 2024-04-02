// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { IRouxCreator } from "src/interfaces/IRouxCreator.sol";

contract RouxCreator is IRouxCreator, ERC1155 {
    /* -------------------------------------------- */
    /* constants                                    */
    /* -------------------------------------------- */

    /**
     * @notice RouxCreator storage slot
     * @dev keccak256(abi.encode(uint256(keccak256("erc7201:rouxCreator")) - 1)) & ~bytes32(uint256(0xff));
     */
    bytes32 internal constant ROUX_CREATOR_STORAGE_SLOT =
        0xb58054ed73afeea56f113b62f99d32ce889cc871485db9295a43d8f4bffd7800;

    /* -------------------------------------------- */
    /* structures                                   */
    /* -------------------------------------------- */

    struct TokenData {
        uint64 totalSupply;
        uint64 maxSupply;
        uint128 price;
        uint40 mintStart;
        uint32 mintDuration;
        uint256 attribution;
        string uri;
    }

    /**
     * @notice RouxCreator storage
     * @custom:storage-location erc7201:rouxCreatorStorage
     *
     * @param _initialized Whether the contract has been initialized
     * @param _owner The owner of the contract
     * @param _creator The creator of the contract
     * @param _tokenId The current token id
     * @param _tokens The token data
     */
    struct RouxCreatorStorage {
        bool _initialized;
        address _owner;
        address _creator;
        uint256 _tokenId;
        mapping(uint256 => TokenData) _tokens;
    }

    /* -------------------------------------------- */
    /* constructor                                  */
    /* -------------------------------------------- */

    constructor() ERC1155("") {
        RouxCreatorStorage storage $ = _storage();

        /* disable initialization of implementation contract */
        $._initialized = true;
    }

    /* -------------------------------------------- */
    /* initializer                                  */
    /* -------------------------------------------- */

    function initialize(bytes calldata params) external {
        RouxCreatorStorage storage $ = _storage();

        require(!$._initialized, "Already initialized");
        $._initialized = true;

        (address owner_) = abi.decode(params, (address));

        $._owner = owner_;
        $._creator = owner_;
    }

    /* -------------------------------------------- */
    /* storage                                      */
    /* -------------------------------------------- */

    /**
     * @notice Get RouxCreator storage location
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
        RouxCreatorStorage storage $ = _storage();

        return $._creator;
    }

    function owner() external view returns (address) {
        RouxCreatorStorage storage $ = _storage();

        return $._owner;
    }

    function tokenCount() external view returns (uint256) {
        RouxCreatorStorage storage $ = _storage();

        return $._tokenId;
    }

    function totalSupply(uint256 id) external view override returns (uint256) {
        RouxCreatorStorage storage $ = _storage();

        return $._tokens[id].totalSupply;
    }

    function price(uint256 id) external view returns (uint256) {
        RouxCreatorStorage storage $ = _storage();

        return $._tokens[id].price;
    }

    function maxSupply(uint256 id) external view returns (uint256) {
        RouxCreatorStorage storage $ = _storage();

        return $._tokens[id].maxSupply;
    }

    function uri(uint256 id) public view override(IRouxCreator, ERC1155) returns (string memory) {
        RouxCreatorStorage storage $ = _storage();

        return $._tokens[id].uri;
    }

    function attribution(uint256 id) external view returns (address, uint96) {
        RouxCreatorStorage storage $ = _storage();

        return _decodeAttribution($._tokens[id].attribution);
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    function mint(address to, uint256 id, uint64 quantity_) external payable {
        RouxCreatorStorage storage $ = _storage();

        _validateMint(id, quantity_);

        // update total quantity
        $._tokens[id].totalSupply += quantity_;

        _mint(to, id, quantity_, "");
    }

    /* -------------------------------------------- */
    /* admin                                        */
    /* -------------------------------------------- */

    // @notice add a new token id to the contract
    function add(
        uint64 maxSupply_,
        uint128 price_,
        uint40 mintStart,
        uint32 mintDuration,
        string memory tokenUri
    )
        external
        returns (uint256)
    {
        RouxCreatorStorage storage $ = _storage();

        if (msg.sender != $._owner) revert OnlyOwner();

        return _add({
            maxSupply_: maxSupply_,
            price_: price_,
            tokenUri: tokenUri,
            mintStart: mintStart,
            mintDuration: mintDuration,
            attribution_: 0
        });
    }

    function add(
        uint64 maxSupply_,
        uint128 price_,
        uint40 mintStart,
        uint32 mintDuration,
        string memory tokenUri,
        address parentContract,
        uint96 parentId
    )
        external
        returns (uint256)
    {
        RouxCreatorStorage storage $ = _storage();

        if (msg.sender != $._owner) revert OnlyOwner();
        uint256 attribution_ = _encodeAttribution(parentContract, parentId);

        return _add({
            maxSupply_: maxSupply_,
            price_: price_,
            tokenUri: tokenUri,
            mintStart: mintStart,
            mintDuration: mintDuration,
            attribution_: attribution_
        });
    }

    function updateUri(uint256 id, string memory newUri) external {
        RouxCreatorStorage storage $ = _storage();

        if (msg.sender != $._owner) revert OnlyOwner();

        $._tokens[id].uri = newUri;

        emit URI(newUri, id);
    }

    function withdraw() external {
        RouxCreatorStorage storage $ = _storage();

        if (msg.sender != $._owner) revert OnlyOwner();

        (bool success,) = payable(msg.sender).call{ value: address(this).balance }("");
        if (!success) revert TransferFailed();
    }

    function updateOwner(address newOwner) external {
        RouxCreatorStorage storage $ = _storage();

        if (msg.sender != $._owner) revert OnlyOwner();
        $._owner = newOwner;
    }

    /* -------------------------------------------- */
    /* internal                                     */
    /* -------------------------------------------- */

    function _add(
        uint64 maxSupply_,
        uint128 price_,
        string memory tokenUri,
        uint40 mintStart,
        uint32 mintDuration,
        uint256 attribution_
    )
        internal
        returns (uint256)
    {
        RouxCreatorStorage storage $ = _storage();

        uint256 id = ++$._tokenId;

        $._tokens[id] = TokenData({
            maxSupply: maxSupply_,
            totalSupply: 0,
            price: price_,
            uri: tokenUri,
            mintStart: mintStart,
            mintDuration: mintDuration,
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

    function _validateMint(uint256 id, uint64 quantity) internal view {
        RouxCreatorStorage storage $ = _storage();

        if (id == 0 || id > $._tokenId) revert InvalidTokenId();

        if (block.timestamp < $._tokens[id].mintStart) revert MintNotStarted();
        if (block.timestamp > $._tokens[id].mintStart + $._tokens[id].mintDuration) revert MintEnded();

        if (quantity + $._tokens[id].totalSupply > $._tokens[id].maxSupply) revert MaxSupplyExceeded();
        if (msg.value < $._tokens[id].price * quantity) revert InsufficientFunds();
    }
}
