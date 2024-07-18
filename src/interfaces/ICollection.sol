// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface ICollection is IERC165 {
    error InvalidExtension();
    error GatedMint();
    error InvalidItems();
    error InvalidCaller();

    event ExtensionSet(address indexed extension, bool enable);

    /**
     * @dev Mints a new token in the collection.
     * @param to The address that will receive the minted token.
     * @param extension The address of the extension to use for minting.
     * @param data Additional data to pass to the extension.
     * @return The ID of the newly minted token.
     */
    function mint(address to, address extension, bytes calldata data) external payable returns (uint256);

    /**
     * @dev Returns the address of the curator for this collection.
     * @return The curator's address.
     */
    function curator() external view returns (address);

    /**
     * @dev Returns the address of the currency used for this collection.
     * @return The currency contract address.
     */
    function currency() external view returns (address);

    /**
     * @dev Returns the current price for minting a token in this collection.
     * @return The current minting price.
     */
    function price() external view returns (uint256);

    /**
     * @dev Returns information about the items in this collection.
     * @return itemTargets An array of addresses representing the target contracts for each item.
     * @return itemIds An array of token IDs corresponding to each item in the collection.
     */
    function collection() external view returns (address[] memory itemTargets, uint256[] memory itemIds);

    /**
     * @dev Updates the minting parameters for this collection.
     * @param mintParams Encoded parameters for updating mint settings.
     */
    function updateMintParams(bytes calldata mintParams) external;

    /**
     * @dev Enables or disables gated minting for this collection.
     * @param gate True to enable gated minting, false to disable it.
     */
    function gateMint(bool gate) external;

    /**
     * @dev Sets or unsets an extension for the collection.
     * @param extension The address of the extension.
     * @param enable True to enable the extension, false to disable it.
     * @param options Additional options for the extension.
     */
    function setExtension(address extension, bool enable, bytes calldata options) external;

    /**
     * @dev Updates the mint parameters for a specific extension.
     * @param extension The address of the extension.
     * @param options The new mint parameters for the extension.
     */
    function updateExtensionMintParams(address extension, bytes calldata options) external;

    /**
     * @dev Checks if a given address is an authorized extension for this collection.
     * @param extension The address to check.
     * @return True if the address is an authorized extension, false otherwise.
     */
    function isExtension(address extension) external view returns (bool);
}
