// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Script.sol";

import { ERC6551Account } from "src/ERC6551Account.sol";
import { BaseScript } from "./Base.s.sol";

contract DeployERC6551Account is BaseScript {
    function run() public broadcast {
        ERC6551Account accountImpl = new ERC6551Account();
        console.log("ERC6551 Account Implementation: ", address(accountImpl));
    }
}
