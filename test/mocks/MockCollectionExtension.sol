// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.27;

import { IExtension } from "src/periphery/interfaces/IExtension.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/**
 * @title MockCollectionExtension
 * @author Assistant
 */
contract MockCollectionExtension is IExtension, OwnableRoles, ERC165 {
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
        uint40 mintStart;
        uint40 mintEnd;
    }

    /* -------------------------------------------- */
    /* state                                        */
    /* -------------------------------------------- */

    /// @dev mint params
    MintParams internal _mintParams;

    /// @dev minted addresses
    mapping(address => bool) internal _minted;

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    /// @dev get price
    function price(address, /* target */ uint256 /* id */ ) external view returns (uint128) {
        return _mintParams.price;
    }

    /// @dev approve mint
    function approveMint(
        uint256, /* id */
        uint256, /* quantity */
        address, /* operator */
        address account,
        bytes calldata /* data */
    )
        external
        returns (uint256)
    {
        if (account == address(0x12345678)) revert InvalidAccount();
        if (_minted[account]) revert AlreadyMinted();
        if (block.timestamp < _mintParams.mintStart || block.timestamp > _mintParams.mintEnd) {
            revert InvalidMintParams();
        }

        _minted[account] = true;
        return _mintParams.price;
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev set collection mint params
    function setMintParams(uint256, /* id */ bytes calldata params) external {
        (uint128 price_, uint40 mintStart_, uint40 mintEnd_) = abi.decode(params, (uint128, uint40, uint40));

        _mintParams = MintParams({ price: price_, mintStart: mintStart_, mintEnd: mintEnd_ });
    }

    /* -------------------------------------------- */
    /* supports interface                           */
    /* -------------------------------------------- */

    /// @dev supports interface
    function supportsInterface(bytes4 interfaceId) public view virtual override(IExtension, ERC165) returns (bool) {
        return interfaceId == type(IExtension).interfaceId || super.supportsInterface(interfaceId);
    }
}
