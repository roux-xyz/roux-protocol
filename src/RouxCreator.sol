// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC1155 } from "solady/tokens/ERC1155.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { IRouxCreator } from "src/interfaces/IRouxCreator.sol";

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

    /* -------------------------------------------- */
    /* structures                                   */
    /* -------------------------------------------- */

    /**
     * @notice token data
     * @param totalSupply total supply
     * @param maxSupply maximum supply
     * @param price price
     * @param mintStart mint start time
     * @param mintEnd mint end time
     * @param attributionContract contract address for attribution
     * @param attributionId token id for attribution
     */
    struct TokenData {
        uint64 totalSupply;
        uint64 maxSupply;
        uint128 price;
        uint40 mintStart;
        uint40 mintEnd;
        address attributionContract;
        uint256 attributionId;
        string uri;
    }

    /**
     * @notice RouxCreator storage
     * @custom:storage-location erc7201:rouxCreatorStorage
     *
     * @param _initialized whether the contract has been initialized
     * @param _creator creator of the contract
     * @param _tokenId current token id
     * @param _tokens mapping of token id to token data
     */
    struct RouxCreatorStorage {
        bool _initialized;
        address _creator;
        uint256 _tokenId;
        mapping(uint256 tokenId => TokenData tokenData) _tokens;
    }

    /* -------------------------------------------- */
    /* constructor                                  */
    /* -------------------------------------------- */

    constructor() {
        /* disable initialization of implementation contract */
        _storage()._initialized = true;
    }

    /* -------------------------------------------- */
    /* initializer                                  */
    /* -------------------------------------------- */

    function initialize() external {
        RouxCreatorStorage storage $ = _storage();

        require(!$._initialized, "Already initialized");
        $._initialized = true;

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

    function tokenCount() external view returns (uint256) {
        return _storage()._tokenId;
    }

    function implementationVersion() external pure returns (string memory) {
        return IMPLEMENTATION_VERSION;
    }

    function totalSupply(uint256 id) external view override returns (uint256) {
        return _storage()._tokens[id].totalSupply;
    }

    function price(uint256 id) external view returns (uint256) {
        return _storage()._tokens[id].price;
    }

    function maxSupply(uint256 id) external view returns (uint256) {
        return _storage()._tokens[id].maxSupply;
    }

    function uri(uint256 id) public view override(IRouxCreator, ERC1155) returns (string memory) {
        return _storage()._tokens[id].uri;
    }

    function attribution(uint256 id) external view returns (address, uint256) {
        RouxCreatorStorage storage $ = _storage();

        return ($._tokens[id].attributionContract, $._tokens[id].attributionId);
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    function mint(address to, uint256 id, uint64 quantity) external payable {
        _validateMint(id, quantity);

        // update total quantity
        _storage()._tokens[id].totalSupply += quantity;

        _mint(to, id, quantity, "");
    }

    /* -------------------------------------------- */
    /* admin                                        */
    /* -------------------------------------------- */

    function add(
        uint64 maxSupply_,
        uint128 price_,
        uint40 mintStart,
        uint40 mintDuration,
        string memory tokenUri,
        address attributionContract,
        uint256 attributionId
    )
        external
        onlyOwner
        returns (uint256)
    {
        RouxCreatorStorage storage $ = _storage();

        uint256 id = ++$._tokenId;

        TokenData storage d = $._tokens[id];
        d.maxSupply = maxSupply_;
        d.price = price_;
        d.uri = tokenUri;
        d.mintStart = mintStart;
        d.mintEnd = mintStart + mintDuration;

        if (attributionContract != address(0) && attributionId != 0) {
            d.attributionContract = attributionContract;
            d.attributionId = attributionId;
        }

        emit TokenAdded(id, attributionContract, attributionId);

        return id;
    }

    function updateUri(uint256 id, string memory newUri) external onlyOwner {
        _storage()._tokens[id].uri = newUri;

        emit URI(newUri, id);
    }

    function initializeCreator(address creator_) external onlyOwner {
        RouxCreatorStorage storage $ = _storage();

        if ($._creator != address(0)) revert CreatorAlreadyInitialized();
        $._creator = creator_;
    }

    function withdraw() external onlyOwner {
        (bool success,) = payable(msg.sender).call{ value: address(this).balance }("");
        if (!success) revert TransferFailed();
    }
    /* -------------------------------------------- */
    /* internal                                     */
    /* -------------------------------------------- */

    function _validateMint(uint256 id, uint64 quantity) internal view {
        RouxCreatorStorage storage $ = _storage();

        if (id == 0 || id > $._tokenId) revert InvalidTokenId();

        if (block.timestamp < $._tokens[id].mintStart) revert MintNotStarted();
        if (block.timestamp > $._tokens[id].mintEnd) revert MintEnded();

        if (quantity + $._tokens[id].totalSupply > $._tokens[id].maxSupply) revert MaxSupplyExceeded();
        if (msg.value < $._tokens[id].price * quantity) revert InsufficientFunds();
    }
}
