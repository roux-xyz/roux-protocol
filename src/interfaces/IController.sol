// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IController {
    /* -------------------------------------------- */
    /* errors                                       */
    /* -------------------------------------------- */

    /**
     * @notice transfer failed
     */
    error TransferFailed();

    /**
     * @notice invalid funds recipient
     */
    error InvalidFundsRecipient();

    /**
     * @notice invalid profit share value
     */
    error InvalidProfitShare();

    /* -------------------------------------------- */
    /* events                                       */
    /* -------------------------------------------- */

    /**
     * @notice disbursement
     * @param edition edition
     * @param tokenId token id
     * @param amount amount disbursed
     */
    event Disbursement(address indexed edition, uint256 indexed tokenId, uint256 amount);

    /**
     * @notice pending balance updated
     * @param edition edition that filled the pending balance
     * @param tokenId token id that filled the pending balance
     * @param parent parent edition
     * @param parentTokenId parent token id
     * @param amount amount
     */
    event PendingUpdated(
        address edition, uint256 indexed tokenId, address parent, uint256 indexed parentTokenId, uint256 amount
    );

    /**
     * @notice withdrawal
     * @param edition edition
     * @param tokenId token id
     * @param amount amount withdrawn
     */
    event Withdrawn(address indexed edition, uint256 indexed tokenId, address indexed to, uint256 amount);

    /**
     * @notice batch withdrawal
     * @param edition edition
     * @param tokenIds token ids
     * @param amount amount withdrawn
     */
    event WithdrawnBatch(address indexed edition, uint256[] indexed tokenIds, address indexed to, uint256 amount);

    /**
     * @notice admin fee enabled
     * @param enabled admin fee enabled
     */
    event PlatformFeeUpdated(bool enabled);

    /* -------------------------------------------- */
    /* structures                                   */
    /* -------------------------------------------- */

    /**
     * @notice attribution data
     */
    struct ControllerData {
        address fundsRecipient;
        uint16 profitShare;
    }

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    /**
     * @notice get balance by edition token
     * @param edition edition
     * @param tokenId token id
     * @return balance
     */
    function balance(address edition, uint256 tokenId) external view returns (uint256);

    /**
     * @notice get total balance for a batch of tokenIds
     * @param edition edition
     * @param tokenIds token ids
     * @return balance
     */
    function balanceBatch(address edition, uint256[] calldata tokenIds) external view returns (uint256);

    /**
     * @notice get pending balance by edition token
     * @param edition edition
     * @param tokenId token id
     */
    function pending(address edition, uint256 tokenId) external view returns (uint256);

    /**
     * @notice get admin fee balance
     */
    function platformFeeBalance() external view returns (uint256);

    /**
     * @notice get profit share for a given edition and tokenId
     * @param edition edition
     * @param tokenId tokenId
     */
    function profitShare(address edition, uint256 tokenId) external view returns (uint256);

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /**
     * @notice set attribution for an edition and tokenId
     * @param tokenId token id
     * @param fundsRecipient funding recipient
     * @param profitShare profit share
     *
     * @dev this should be called by the edition contract, as the attribution mapping
     *       is keyed by the edition contract address and token id
     */
    function setControllerData(uint256 tokenId, address fundsRecipient, uint16 profitShare) external;

    /**
     * @notice disburse mint funds to edition and pending balance
     * @param edition edition
     * @param tokenId token id
     */
    function disburse(address edition, uint256 tokenId) external payable;

    /**
     * @notice withdraw balance from edition for given token id
     * @param edition edition
     * @param tokenId token id
     * @return amount withdrawn
     *
     * @dev anyone can call this function to withdraw to the funding recipient
     *      for the given token id
     */
    function withdraw(address edition, uint256 tokenId) external returns (uint256);

    /**
     * @notice withdraw balance from edition for given token id
     * @param edition edition
     * @param tokenIds array of token ids
     * @return amount withdrawn
     *
     * @dev anyone can call this function to withdraw to the funding recipient
     *      for the given token id
     */
    function withdrawBatch(address edition, uint256[] calldata tokenIds) external returns (uint256);
}
