// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { ERC1155 } from "solady/tokens/ERC1155.sol";
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title restricted 1155
 * @notice abstract ERC1155 token with transfer restrictions
 * @author roux
 * @custom:version 1.0
 */
abstract contract Restricted1155 is ERC1155, ERC165 {
    /* -------------------------------------------- */
    /* errors                                       */
    /* -------------------------------------------- */

    /// @notice transfer is not allowed
    error Restricted1155_TransferNotAllowed();

    /* -------------------------------------------- */
    /* constants                                    */
    /* -------------------------------------------- */

    /**
     * @notice Restricted1155 storage slot
     * @dev keccak256(abi.encode(uint256(keccak256("restricted1155.restricted1155Storage")) - 1)) &
     * ~bytes32(uint256(0xff));
     */
    bytes32 internal constant RESTRICTED_1155_STORAGE_SLOT =
        0x4e73ff6706f99fb82c648dcc49152478b9d6d38f017862cfe517ed7a9b5a6000;

    /* -------------------------------------------- */
    /* structures                                   */
    /* -------------------------------------------- */

    /**
     * @notice restricted 1155 storage
     * @custom:storage-location erc7201:restricted1155.restricted1155Storage
     */
    struct Restricted1155Storage {
        uint256 totalSupply;
    }

    /* -------------------------------------------- */
    /* storage                                      */
    /* -------------------------------------------- */

    /**
     * @notice get restricted 1155 storage location
     * @return $ restricted 1155 storage location
     */
    function _restricted1155Storage() internal pure returns (Restricted1155Storage storage $) {
        assembly {
            $.slot := RESTRICTED_1155_STORAGE_SLOT
        }
    }

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    /**
     * @notice get the total supply of tokens
     * @return total supply of tokens
     */
    function totalSupply() external view returns (uint256) {
        return _restricted1155Storage().totalSupply;
    }

    /* -------------------------------------------- */
    /* overrides                                    */
    /* -------------------------------------------- */

    /// @dev transfers not allowed
    function safeTransferFrom(address, address, uint256, uint256, bytes calldata) public pure virtual override {
        revert Restricted1155_TransferNotAllowed();
    }

    /// @dev transfers not allowed
    function safeBatchTransferFrom(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    )
        public
        pure
        virtual
        override
    {
        revert Restricted1155_TransferNotAllowed();
    }

    /// @dev transfers not allowed
    function setApprovalForAll(address, bool) public pure virtual override {
        revert Restricted1155_TransferNotAllowed();
    }

    /* -------------------------------------------- */
    /* internal functions                           */
    /* -------------------------------------------- */

    /**
     * @notice internal function to mint tokens
     * @param to address to mint tokens to
     * @param id token ID
     * @param amount amount of tokens to mint
     * @param data additional data
     */
    function _mint(address to, uint256 id, uint256 amount, bytes memory data) internal virtual override {
        _restricted1155Storage().totalSupply += amount;

        super._mint(to, id, amount, data);
    }

    /**
     * @notice internal function to burn tokens
     * @param from address to burn tokens from
     * @param id token ID
     * @param amount amount of tokens to burn
     */
    function _burn(address from, uint256 id, uint256 amount) internal virtual override {
        _restricted1155Storage().totalSupply -= amount;

        super._burn(from, id, amount);
    }

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, ERC1155) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
