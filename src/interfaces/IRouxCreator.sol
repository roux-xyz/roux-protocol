// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IRouxCreator {
    /* -------------------------------------------- */
    /* errors                                       */
    /* -------------------------------------------- */

    error InvalidTokenId();

    error MaxSupplyExceeded();

    error MaxMintableExceeded();

    error InsufficientFunds();

    error MintNotStarted();

    error MintEnded();

    error CreatorAlreadySet();

    error InvalidParam();

    error InvalidAttribution();

    /* -------------------------------------------- */
    /* events                                       */
    /* -------------------------------------------- */

    event TokenAdded(uint256 indexed id, address indexed attributionContract, uint256 indexed attributionid);

    /* -------------------------------------------- */
    /* view functions                               */
    /* -------------------------------------------- */

    function price(uint256 id) external view returns (uint256);

    function totalSupply(uint256 id) external view returns (uint256);

    function creator() external view returns (address);

    function currentToken() external view returns (uint256);

    function maxSupply(uint256 id) external view returns (uint256);

    function uri(uint256 id) external view returns (string memory);

    function attribution(uint256 id) external view returns (address, uint256);

    function exists(uint256 id) external view returns (bool);

    /* -------------------------------------------- */
    /* write functions                              */
    /* -------------------------------------------- */

    function mint(address to_, uint256 id, uint64 quantity_) external payable;

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
        returns (uint256);

    function setCreator(address creator) external;

    function updateAdministrationData(
        uint256 id,
        address parentEdition,
        uint256 parentTokenId,
        address fundsRecipient,
        uint16 profitShare
    )
        external;
}
