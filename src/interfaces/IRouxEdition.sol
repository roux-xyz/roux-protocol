// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IController } from "src/interfaces/IController.sol";
import { EditionData } from "src/types/DataTypes.sol";

interface IRouxEdition {
    /* -------------------------------------------- */
    /* errors                                       */
    /* -------------------------------------------- */
    /**
     * @notice invalid parameters
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
     * @notice invalid caller
     */
    error InvalidCaller();

    /**
     * @notice invalid extension
     */
    error InvalidExtension();

    /**
     * @notice inactive mint
     */
    error InactiveMint();

    /**
     * @notice max supply exceeded
     */
    error MaxSupplyExceeded();

    /**
     * @notice gated mint
     */
    error GatedMint();

    /**
     * @notice invalid collection
     */
    error InvalidCollection();

    /**
     * @notice only allowlist
     */
    error OnlyAllowlist();

    /* -------------------------------------------- */
    /* events                                       */
    /* -------------------------------------------- */

    /**
     * @notice emitted when a token is added
     * @param id token id
     */
    event TokenAdded(uint256 indexed id);

    /**
     * @notice emitted when an extension is added
     * @param extension extension address
     * @param id token id
     */
    event ExtensionAdded(address indexed extension, uint256 indexed id);

    /**
     * @notice emitted when a contract uri is updated
     */
    event ContractURIUpdated();

    /* -------------------------------------------- */
    /* view functions                               */
    /* -------------------------------------------- */

    /**
     * @notice get creator
     * @param id token id
     * @return creator address
     */
    function creator(uint256 id) external view returns (address);

    /**
     * @notice get current token id
     * @return current token id
     */
    function currentToken() external view returns (uint256);

    /**
     * @notice get currency address
     * @return currency address
     */
    function currency() external view returns (address);

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
     * @notice contract uri
     * @return contract uri
     */
    function contractURI() external view returns (string memory);

    /**
     * @notice check if token exists
     * @param id token id
     * @return true if token exists
     */
    function exists(uint256 id) external view returns (bool);

    /**
     * @notice check if extension is valid for a token
     * @param id token id
     * @param extension extension address
     * @return true if extension is valid
     */
    function isExtension(uint256 id, address extension) external view returns (bool);

    /**
     * @notice check if collection is valid for a collection id
     * @param collectionId collection id
     * @param collection collection address
     * @return true if collection is valid
     */
    function isCollection(uint256 collectionId, address collection) external view returns (bool);

    /**
     * @notice get default price for a token
     * @param id token id
     * @return default price
     */
    function defaultPrice(uint256 id) external view returns (uint256);

    /**
     * @notice check if a token is gated
     * @param id token id
     * @return true if token is gated
     */
    function isGated(uint256 id) external view returns (bool);

    /**
     * @notice get default mint parameters for a token
     * @param id token id
     * @return default mint parameters
     */
    function defaultMintParams(uint256 id) external view returns (EditionData.MintParams memory);

    /* -------------------------------------------- */
    /* write functions                              */
    /* -------------------------------------------- */

    /**
     * @notice add a new token
     * @param p AddParams struct containing token parameters
     * @return new token id
     */
    function add(EditionData.AddParams calldata p) external returns (uint256);

    /**
     * @notice mint a token
     * @param to token receiver
     * @param id token id
     * @param quantity number of tokens to mint
     * @param referrer referrer address
     * @param extension extension address
     * @param data additional data
     */
    function mint(
        address to,
        uint256 id,
        uint256 quantity,
        address referrer,
        address extension,
        bytes calldata data
    )
        external
        payable;

    /**
     * @notice mint tokens for a single edition collection
     * @param to token receiver
     * @param ids array of token ids
     * @param totalAmount total amount to pay
     * @param data additional data
     */
    function collectionSingleMint(
        address to,
        uint256[] memory ids,
        uint256 totalAmount,
        bytes calldata data
    )
        external
        payable;

    /**
     * @notice mint a token for a multi edition collection
     * @param to token receiver
     * @param id token id
     * @param amount amount to pay
     * @param data additional data
     */
    function collectionMultiMint(address to, uint256 id, uint256 amount, bytes calldata data) external payable;
}
