// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IController {
    /* -------------------------------------------- */
    /* view functions                               */
    /* -------------------------------------------- */

    /**
     * @notice get the currency address
     * @return address of the currency token
     */
    function currency() external view returns (address);

    /**
     * @notice get the number of decimals for the controller's currency
     * @return number of decimals for the controller's currency
     */
    function decimals() external view returns (uint8);

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
     * @notice disburse funds for a token
     * @param id token id
     * @param amount amount to disburse
     * @param referrer address of the referrer
     *
     * @dev funds pool to the funds recipient
     */
    function disburse(uint256 id, uint256 amount, address referrer) external payable;

    /**
     * @notice record funds for a recipient
     * @param recipient address of the recipient
     * @param amount amount to record
     *
     * @dev general catchall function used to record funds for a recipient
     *      - used by SingleEditionCollection to record referral fee earnings
     *      - used by MultiEditionCollection to record collection fee + referral fee earnings
     */
    function recordFunds(address recipient, uint256 amount) external payable;

    /**
     * @notice distribute pending balance for an edition and token ID
     * @param edition address of the edition
     * @param tokenId token ID
     *
     * @dev pending balances are funds earned by a token from a child token that have not been distributed
     *      - they represent the parent share earned by a mint of a fork
     *      - on the `distributePending` call, the internal `_disburse` function checks if there is
     *        another parent token and updates balances accordingly
     */
    function distributePending(address edition, uint256 tokenId) external;

    /**
     * @notice distribute pending balance for multiple editions and token IDs
     * @param editions array of edition addresses
     * @param tokenIds array of token IDs
     */
    function distributePendingBatch(address[] calldata editions, uint256[] calldata tokenIds) external;

    /**
     * @notice distribute pending balance and withdraw for an edition and token ID
     * @param edition address of the edition
     * @param tokenId token ID
     * @return amount withdrawn
     */
    function distributePendingAndWithdraw(address edition, uint256 tokenId) external returns (uint256);

    /**
     * @notice withdraw funds for a recipient
     * @param recipient address of the recipient
     * @return amount withdrawn
     */
    function withdraw(address recipient) external returns (uint256);

    /**
     * @notice set funds recipient for a token
     * @param tokenId token id
     * @param fundsRecipient_  funds recipient address
     *
     * @dev must be called by the edition contract to take effect
     */
    function setFundsRecipient(uint256 tokenId, address fundsRecipient_) external;

    /**
     * @notice set profit share for a token
     * @param tokenId token id
     * @param profitShare_ profit share percentage
     *
     * @dev must be called by the edition contract to take effect
     *      - profit share is the percentage of the proceeds that goes to the child edition
     *      - cannot be decreased once set, only increased
     */
    function setProfitShare(uint256 tokenId, uint16 profitShare_) external;

    /**
     * @notice set both funds recipient and profit share for a token
     * @param tokenId token id
     * @param fundsRecipient_ funds recipient address
     * @param profitShare_ profit share percentage
     *
     * @dev must be called by the edition contract to take effect, sets both funds recipient and profit share
     *      in a single call to save gas on call from the edition contract
     */
    function setControllerData(uint256 tokenId, address fundsRecipient_, uint16 profitShare_) external;

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
}
