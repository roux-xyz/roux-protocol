// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface ICollection is IERC165 {
    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    /**
     * @notice get information about the items in this collection
     * @return itemTargets array of addresses representing the target contracts for each item
     * @return itemIds array of token IDs corresponding to each item in the collection
     */
    function collection() external view returns (address[] memory itemTargets, uint256[] memory itemIds);

    /**
     * @notice get contract uri
     * @return contract uri
     *
     * @dev tokenURI and contractURI are the same
     */
    function contractURI() external view returns (string memory);

    /**
     * @notice get curator address for this collection
     * @return curator address
     */
    function curator() external view returns (address);

    /**
     * @notice get currency address used for this collection
     * @return currency contract address
     */
    function currency() external view returns (address);

    /**
     * @notice get current price for minting a token in this collection
     * @return current minting price
     */
    function price() external view returns (uint256);

    /**
     * @notice get total supply
     * @return total supply
     */
    function totalSupply() external view returns (uint256);

    /**
     * @notice check if extension is enabled
     * @param extension extension address
     * @return true if extension is enabled
     */
    function isRegisteredExtension(address extension) external view returns (bool);

    /**
     * @notice check if collection is gated
     * @return true if collection is gated
     */
    function isGated() external view returns (bool);

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /**
     * @notice mint a new token in the collection
     * @param to address that will receive the minted token
     * @param extension address of the extension to use for minting
     * @param referrer referrer address
     * @param data additional data to pass to the extension
     * @return ID of the newly minted token
     *
     * @dev while multi edition collections can use extensions, note that the derived price from the constiuent
     *      tokens will be used and so price parameters should not be set on the extension (will just result in
     *      reverts if insufficient funds are provided)
     */
    function mint(address to, address extension, address referrer, bytes calldata data) external returns (uint256);

    /* -------------------------------------------- */
    /* admin                                        */
    /* -------------------------------------------- */

    /**
     * @notice one time setter for curator
     * @param curator_ curator address
     * @dev called by collection factory on initialization
     */
    function setCurator(address curator_) external;
}
