// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.26;

import { IExtension } from "src/interfaces/IExtension.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/**
 * @title FreeMintExtension
 * @author Roux
 */
contract MockExtension is IExtension, OwnableRoles, ERC165 {
    /* -------------------------------------------- */
    /* errors                                       */
    /* -------------------------------------------- */

    error InvalidAccount();

    /* -------------------------------------------- */
    /* structures                                   */
    /* -------------------------------------------- */

    /// @dev mint params
    struct MintParams {
        uint128 price;
    }

    /* -------------------------------------------- */
    /* state                                   */
    /* -------------------------------------------- */

    /// @dev mint params
    mapping(address edition => mapping(uint256 tokenId => MintParams)) internal _mintParams;

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    /// @dev get price
    function price(address edition, uint256 id) external view returns (uint128) {
        return _mintParams[edition][id].price;
    }

    /// @dev approve mint
    function approveMint(
        uint256 id,
        uint256 quantity,
        address, /* operator */
        address account,
        bytes calldata /* data */
    )
        external
        view
        returns (uint256)
    {
        if (account == address(0x12345678)) revert InvalidAccount();

        return _mintParams[msg.sender][id].price * quantity;
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev set mint params
    function setMintParams(uint256 id, bytes calldata params) external {
        (uint128 price_) = abi.decode(params, (uint128));

        MintParams memory p = MintParams({ price: price_ });

        _mintParams[msg.sender][id] = p;

        emit MintParamsUpdated(msg.sender, id, params);
    }

    /* -------------------------------------------- */
    /* supports interface                           */
    /* -------------------------------------------- */

    /// @dev supports interface
    function supportsInterface(bytes4 interfaceId) public view virtual override(IExtension, ERC165) returns (bool) {
        return interfaceId == type(IExtension).interfaceId || super.supportsInterface(interfaceId);
    }
}
