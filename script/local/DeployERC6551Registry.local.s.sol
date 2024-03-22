// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import "forge-std/Script.sol";

import { ERC6551Registry } from "erc6551/ERC6551Registry.sol";
import { BaseScript } from "script/Base.s.sol";

contract DeployERC6551Registry is BaseScript {
    function run() public broadcast {
        ERC6551Registry registry = new ERC6551Registry();
        console.log("ERC6551 Registry: ", address(registry));
    }
}
