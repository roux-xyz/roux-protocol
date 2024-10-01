// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

interface IExtension {
    /* -------------------------------------------- */
    /* errors                                       */
    /* -------------------------------------------- */

    /**
     * @notice insufficient funds
     */
    error InsufficientFunds();

    /**
     * @notice invalid mint params
     */
    error InvalidMintParams();

    /**
     * @notice invalid params length
     */
    error InvalidParamsLength();

    /**
     * @notice already minted
     */
    error AlreadyMinted();

    /**
     * @notice mint params not set
     */
    error MintParamsNotSet();

    /* -------------------------------------------- */
    /* events                                       */
    /* -------------------------------------------- */

    /**
     * @notice emitted when mint params are updated
     * @param target target contract (edition or collection)
     * @param id token id (0 for collections)
     * @param mintParams mint params
     */
    event MintParamsUpdated(address indexed target, uint256 indexed id, bytes mintParams);

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    /**
     * @notice get token or collection price
     * @param target target contract (edition or collection)
     * @param id token id (0 for collections)
     * @return price
     */
    function price(address target, uint256 id) external view returns (uint128);

    /**
     * @notice approve mint
     * @param id token id (0 for collections)
     * @param quantity quantity (1 for collections)
     * @param operator operator
     * @param account account
     * @param data additional data
     * @return price or amount to pay
     */
    function approveMint(
        uint256 id,
        uint256 quantity,
        address operator,
        address account,
        bytes calldata data
    )
        external
        returns (uint256);

    /**
     * @notice supports interface
     * @param interfaceId interface id
     * @return true if interface is supported
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /**
     * @notice set mint params
     * @param id token id (0 for collections)
     * @param params mint params
     *
     * @dev must be called via edition or collection
     */
    function setMintParams(uint256 id, bytes calldata params) external;
}
