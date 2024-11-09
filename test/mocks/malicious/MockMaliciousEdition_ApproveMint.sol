// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.27;

import { RouxEdition } from "src/core/RouxEdition.sol";
import { IExtension } from "src/periphery/interfaces/IExtension.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";

contract MockMaliciousEdition_ApproveMint {
    function mint(
        address to,
        uint256 id,
        uint256 quantity,
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

        price = IExtension(extension).approveMint({
            id: id,
            quantity: quantity,
            operator: msg.sender,
            account: to,
            data: ""
        });
    }
}
