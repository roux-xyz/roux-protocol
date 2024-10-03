// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { ERC1155 } from "solady/tokens/ERC1155.sol";
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { LibBitmap } from "solady/utils/LibBitmap.sol";

/**
 * @title restricted 1155
 * @notice abstract ERC1155 token with transfer restrictions
 * @author roux
 * @custom:version 1.0
 */
abstract contract Restricted1155 is ERC1155, ERC165 {
    using LibBitmap for LibBitmap.Bitmap;
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
        string baseUri;
        string contractUri;
        mapping(uint256 id => uint256 totalSupply) totalSupply;
        mapping(address => LibBitmap.Bitmap) approvals;
        mapping(uint256 id => bool isRestricted) restrictedTokens;
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
     * @notice view function to get the total supply of a token
     * @param id token ID
     * @return total supply of token
     */
    function totalSupply(uint256 id) public view returns (uint256) {
        return _restricted1155Storage().totalSupply[id];
    }

    /**
     * @notice view function to get if a token is restricted
     * @param id token ID
     * @return true if token is restricted, false otherwise
     */
    function isRestricted(uint256 id) public view returns (bool) {
        return _restricted1155Storage().restrictedTokens[id];
    }

    /* -------------------------------------------- */
    /* overrides                                    */
    /* -------------------------------------------- */

    /// @dev transfers not allowed
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    )
        public
        virtual
        override
    {
        if (_restricted1155Storage().restrictedTokens[id]) {
            revert Restricted1155_TransferNotAllowed();
        }

        super.safeTransferFrom(from, to, id, amount, data);
    }

    /// @dev transfers not allowed
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    )
        public
        virtual
        override
    {
        for (uint256 i = 0; i < ids.length; i++) {
            if (_restricted1155Storage().restrictedTokens[ids[i]]) {
                revert Restricted1155_TransferNotAllowed();
            }
        }
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /// @dev transfers not allowed
    function setApprovalForAll(address operator, bool approved) public virtual override {
        super.setApprovalForAll(operator, approved);
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
        _restricted1155Storage().totalSupply[id] += amount;
        super._mint(to, id, amount, data);
    }

    /**
     * @notice internal function to burn tokens
     * @param from address to burn tokens from
     * @param id token ID
     * @param amount amount of tokens to burn
     */
    function _burn(address from, uint256 id, uint256 amount) internal virtual override {
        super._burn(from, id, amount);
        _restricted1155Storage().totalSupply[id] -= amount;
    }

    function _setTokenRestriction(uint256 id, bool restricted) internal {
        _restricted1155Storage().restrictedTokens[id] = restricted;
    }

    /* -------------------------------------------- */
    /* supports interface                           */
    /* -------------------------------------------- */

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, ERC1155) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
