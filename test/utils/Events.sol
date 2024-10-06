// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.27;

import "src/libraries/EventsLib.sol";

contract Events {
    /// @dev see {IExtension}
    event MintParamsUpdated(address indexed edition, uint256 indexed id, bytes mintParams);

    /// @dev see {IERC1155}
    event TransferSingle(
        address indexed operator, address indexed from, address indexed to, uint256 id, uint256 amount
    );

    /// @dev see {IERC1155}
    event TransferBatch(
        address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] amounts
    );

    /// @dev see {IERC1155}
    event URI(string value, uint256 indexed id);

    /// @dev see {IERC721}
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
}
