// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IRouxEdition {
    /* -------------------------------------------- */
    /* errors                                       */
    /* -------------------------------------------- */

    /**
     * @notice invalid token id
     */
    error InvalidTokenId();

    /**
     * @notice max supply exceeded
     */
    error MaxSupplyExceeded();

    /**
     * @notice max mintable exceeded
     */
    error MaxMintableExceeded();

    /**
     * @notice insufficient funds
     */
    error InsufficientFunds();

    /**
     * @notice mint not started
     */
    error MintNotStarted();

    /**
     * @notice mint ended
     */
    error MintEnded();

    /**
     * @notice edition already set
     */
    error CreatorAlreadySet();

    /**
     * @notice invalid param
     */
    error InvalidPrice();

    /**
     * @notice invalid attribution
     */
    error InvalidAttribution();

    /* -------------------------------------------- */
    /* events                                       */
    /* -------------------------------------------- */

    /**
     * @notice emitted when a token is added
     * @param id token id
     * @param parentEdition parent edition
     * @param parentTokenId parent token id
     */
    event TokenAdded(uint256 indexed id, address indexed parentEdition, uint256 indexed parentTokenId);

    /* -------------------------------------------- */
    /* view functions                               */
    /* -------------------------------------------- */

    /**
     * @notice get creator
     *
     * @dev creator is set by factory at initialization
     */
    function creator() external view returns (address);

    /**
     * @notice get current token id
     * @return current token id
     */
    function currentToken() external view returns (uint256);

    /**
     * @notice get implementation version
     * @return implementation version
     */
    function implementationVersion() external view returns (string memory);

    /**
     * @notice get total supply for a given token id
     * @param id token id
     * @return total supply
     */
    function totalSupply(uint256 id) external view returns (uint256);

    /**
     * @notice get price for a given token id
     * @param id token id
     * @return price
     */
    function price(uint256 id) external view returns (uint256);

    /**
     * @notice get max supply for a given token id
     * @param id token id
     * @return max supply
     */
    function maxSupply(uint256 id) external view returns (uint256);

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

    /* -------------------------------------------- */
    /* write functions                              */
    /* -------------------------------------------- */

    /**
     * @notice mint a token
     * @param to token receiver
     * @param id token id
     * @param quantity number of tokens to mint
     */
    function mint(address to, uint256 id, uint64 quantity) external payable;

    /**
     * @notice set creator
     * @param edition edition
     *
     * @dev called by factory contract
     */
    function setCreator(address edition) external;
}
