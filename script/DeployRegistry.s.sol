// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Registry } from "src/Registry.sol";
import { BaseScript } from "./Base.s.sol";

import "forge-std/Script.sol";

contract DeployRegistry is BaseScript {
    function run() public broadcast {
        console.log("Deploying Registry implementation...\n");

        // deploy registry implementation contract
        Registry registry = new Registry();

        console.log("Registry implementation: %s\n", address(registry));
        console.log("Deploying Registry proxy...\n");

        // deploy controller proxy
        bytes memory initData = abi.encodeWithSelector(Registry.initialize.selector);
        ERC1967Proxy registryProxy = new ERC1967Proxy(address(registry), initData);

        console.log("Registry proxy deployed at: %s\n", address(registryProxy));
    }
}
