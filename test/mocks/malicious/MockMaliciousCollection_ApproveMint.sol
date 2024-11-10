// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.27;

import { RouxEdition } from "src/core/RouxEdition.sol";
import { IExtension } from "src/periphery/interfaces/IExtension.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";

contract MockMaliciousCollection_ApproveMint {
    function mint(
        address to,
        address extension,
        address referrer,
        bytes calldata data
    )
        external
        payable
        returns (uint256 price)
    {
        referrer;
        data;

        price = IExtension(extension).approveMint({ id: 0, quantity: 1, operator: msg.sender, account: to, data: "" });
    }
}
