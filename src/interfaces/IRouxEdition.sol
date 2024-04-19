// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IController } from "src/interfaces/IController.sol";

interface IRouxEdition {
    /* -------------------------------------------- */
    /* errors                                       */
    /* -------------------------------------------- */
    /**
     * @notice invalid token id
     */
    error InvalidParams();

    /**
     * @notice invalid token id
     */
    error InvalidTokenId();

    /**
     * @notice edition already set
     */
    error CreatorAlreadySet();

    /**
     * @notice invalid attribution
     */
    error InvalidAttribution();

    /**
     * @notice invalid attribution
     */
    error InvalidCaller();

    /**
     * @notice max supply exceeded
     */
    error MaxSupplyExceeded();

    /* -------------------------------------------- */
    /* events                                       */
    /* -------------------------------------------- */

    /**
     * @notice emitted when a token is added
     * @param tokenId token id
     * @param minter minter
     */
    event TokenAdded(uint256 indexed tokenId, address indexed minter);

    /**
     * @notice emitted when a minter is added
     * @param minter minter
     */
    event MinterAdded(address indexed minter);

    /**
     * @notice emitted when a minter is removed
     * @param minter minter
     */
    event MinterRemoved(address indexed minter);

    /* -------------------------------------------- */
    /* structures                                   */
    /* -------------------------------------------- */

    /**
     * @notice token data
     */
    struct TokenData {
        address creator;
        uint128 totalSupply;
        uint128 maxSupply;
        mapping(address minter => bool valid) minters;
        string uri;
    }

    /* -------------------------------------------- */
    /* view functions                               */
    /* -------------------------------------------- */

    /**
     * @notice get creator
     *
     * @dev creator is set by factory at initialization
     */
    function creator(uint256 id) external view returns (address);

    /**
     * @notice get current token id
     * @return current token id
     */
    function currentToken() external view returns (uint256);

    /**
     * @notice get implementation version
     * @return implementation version
     */
    function IMPLEMENTATION_VERSION() external view returns (string memory);

    /**
     * @notice get total supply for a given token id
     * @param id token id
     * @return total supply
     */
    function totalSupply(uint256 id) external view returns (uint256);

    /**
     * @notice get uri for a given token id
     * @param id token id
     * @return uri
     */
    function uri(uint256 id) external view returns (string memory);

    /**
     * @notice get attribution for a given token id
     * @param id token id
     * @return parent edition
     * @return parent token id
     */
    function attribution(uint256 id) external view returns (address, uint256);

    /**
     * @notice check if token exists
     * @param id token id
     * @return true if token exists
     */
    function exists(uint256 id) external view returns (bool);

    /**
     * @notice check if minter is valid
     * @param id token id
     * @param minter minter
     */
    function isMinter(uint256 id, address minter) external view returns (bool);

    /* -------------------------------------------- */
    /* write functions                              */
    /* -------------------------------------------- */

    /**
     * @notice add a token
     * @param tokenUri token uri
     * @param creator_ creator
     * @param maxSupply max supply
     * @param fundsRecipient funds recipient
     * @param profitShare profit share
     * @param parentEdition parent edition - address(0) if root
     * @param parentTokenId parent token id - 0 if root
     * @param minter minter - must be previously set to add token
     * @param options additional options
     * @return token id
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
        bytes calldata options
    )
        external
        returns (uint256);

    /**
     * @notice mint a token
     * @param to token receiver
     * @param tokenId token id
     * @param quantity number of tokens to mint
     * @param data additional data
     */
    function mint(address to, uint256 tokenId, uint256 quantity, bytes calldata data) external;
}
