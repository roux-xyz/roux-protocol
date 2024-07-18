// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

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

    /**
     * @notice invalid array length
     */
    error InvalidArrayLength();

    /* -------------------------------------------- */
    /* events                                       */
    /* -------------------------------------------- */

    /**
     * @notice emitted when funds are deposited
     * @param recipient recipient of the funds
     * @param amount amount deposited
     */
    event Deposited(address indexed recipient, uint256 amount);

    /**
     * @notice emitted when pending balance is updated
     * @param edition edition address
     * @param tokenId token ID
     * @param parentEdition parent edition address
     * @param parentTokenId parent token ID
     * @param amount amount pending
     */
    event PendingUpdated(
        address edition, uint256 indexed tokenId, address parentEdition, uint256 indexed parentTokenId, uint256 amount
    );

    /**
     * @notice emitted when funds are withdrawn
     * @param recipient recipient of the withdrawal
     * @param amount amount withdrawn
     */
    event Withdrawn(address indexed recipient, uint256 amount);

    /**
     * @notice emitted when platform fee status is updated
     * @param enabled whether the platform fee is enabled
     */
    event PlatformFeeUpdated(bool enabled);

    /* -------------------------------------------- */
    /* constants                                    */
    /* -------------------------------------------- */

    /**
     * @notice platform fee percentage
     * @return platform fee in basis points
     */
    function PLATFORM_FEE() external pure returns (uint256);

    /**
     * @notice referral fee percentage
     * @return referral fee in basis points
     */
    function REFERRAL_FEE() external pure returns (uint256);

    /**
     * @notice collection fee percentage
     * @return collection fee in basis points
     */
    function COLLECTION_FEE() external pure returns (uint256);

    /* -------------------------------------------- */
    /* view functions                               */
    /* -------------------------------------------- */

    /**
     * @notice get the currency address
     * @return address of the currency token
     */
    function currency() external view returns (address);

    /**
     * @notice get the balance of a recipient
     * @param recipient address of the recipient
     * @return balance of the recipient
     */
    function balance(address recipient) external view returns (uint256);

    /**
     * @notice get the pending balance for an edition and token ID
     * @param edition address of the edition
     * @param tokenId token ID
     * @return pending balance
     */
    function pending(address edition, uint256 tokenId) external view returns (uint256);

    /**
     * @notice get the platform fee balance
     * @return platform fee balance
     */
    function platformFeeBalance() external view returns (uint256);

    /**
     * @notice get the profit share for an edition and token ID
     * @param edition address of the edition
     * @param tokenId token ID
     * @return profit share percentage
     */
    function profitShare(address edition, uint256 tokenId) external view returns (uint256);

    /**
     * @notice get the funds recipient for an edition and token ID
     * @param edition address of the edition
     * @param tokenId token ID
     * @return address of the funds recipient
     */
    function fundsRecipient(address edition, uint256 tokenId) external view returns (address);

    /* -------------------------------------------- */
    /* write functions                              */
    /* -------------------------------------------- */

    /**
     * @notice set controller data for a token
     * @param tokenId token ID
     * @param fundsRecipient_ address of the funds recipient
     * @param profitShare_ profit share percentage
     */
    function setControllerData(uint256 tokenId, address fundsRecipient_, uint16 profitShare_) external;

    /**
     * @notice disburse funds for a token
     * @param tokenId token ID
     * @param amount amount to disburse
     * @param referrer address of the referrer
     */
    function disburse(uint256 tokenId, uint256 amount, address referrer) external payable;

    /**
     * @notice record funds for a recipient
     * @param recipient address of the recipient
     * @param amount amount to record
     */
    function recordFunds(address recipient, uint256 amount) external payable;

    /**
     * @notice disburse pending balance for an edition and token ID
     * @param edition address of the edition
     * @param tokenId token ID
     */
    function disbursePending(address edition, uint256 tokenId) external;

    /**
     * @notice disburse pending balance for multiple editions and token IDs
     * @param editions array of edition addresses
     * @param tokenIds array of token IDs
     */
    function disbursePendingBatch(address[] calldata editions, uint256[] calldata tokenIds) external;

    /**
     * @notice disburse pending balance and withdraw for an edition and token ID
     * @param edition address of the edition
     * @param tokenId token ID
     * @return amount withdrawn
     */
    function disbursePendingAndWithdraw(address edition, uint256 tokenId) external returns (uint256);

    /**
     * @notice withdraw funds for a recipient
     * @param recipient address of the recipient
     * @return amount withdrawn
     */
    function withdraw(address recipient) external returns (uint256);

    /**
     * @notice enable or disable the platform fee
     * @param enable whether to enable the platform fee
     */
    function enablePlatformFee(bool enable) external;

    /**
     * @notice withdraw the platform fee
     * @param to address to send the platform fee to
     * @return amount withdrawn
     */
    function withdrawPlatformFee(address to) external returns (uint256);

    /**
     * @notice get the implementation address of the proxy
     * @return address of the implementation
     */
    function getImplementation() external view returns (address);

    /**
     * @notice upgrade the proxy to a new implementation
     * @param newImplementation address of the new implementation
     * @param data optional calldata for the upgrade
     */
    function upgradeToAndCall(address newImplementation, bytes calldata data) external;
}
