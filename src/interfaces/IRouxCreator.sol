// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IRouxCreator {
    /* -------------------------------------------- */
    /* errors                                       */
    /* -------------------------------------------- */

    error InvalidTokenId();

    error MaxSupplyExceeded();

    error InsufficientFunds();

    error TransferFailed();

    error MintNotStarted();

    error MintEnded();

    error CreatorAlreadyInitialized();

    /* -------------------------------------------- */
    /* events                                       */
    /* -------------------------------------------- */

    event TokenAdded(uint256 indexed id_, address indexed attributionContract_, uint256 indexed attributionId_);

    /* -------------------------------------------- */
    /* view functions                               */
    /* -------------------------------------------- */

    function price(uint256 id_) external view returns (uint256);

    function totalSupply(uint256 id_) external view returns (uint256);

    function creator() external view returns (address);

    function tokenCount() external view returns (uint256);

    function maxSupply(uint256 id_) external view returns (uint256);

    function uri(uint256 id_) external view returns (string memory);

    function attribution(uint256 id_) external view returns (address, uint256);

    /* -------------------------------------------- */
    /* write functions                              */
    /* -------------------------------------------- */

    function mint(address to_, uint256 id_, uint64 quantity_) external payable;

    function add(
        uint64 maxSupply_,
        uint128 price_,
        uint40 mintStart_,
        uint40 mintDuration_,
        string memory tokenUri_,
        address attributionContract_,
        uint256 attributionId_
    )
        external
        returns (uint256);

    function initializeCreator(address creator_) external;
}
