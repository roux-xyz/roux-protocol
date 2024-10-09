// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Registry } from "src/Registry.sol";
import { BaseScript } from "script/Base.s.sol";

import "forge-std/Script.sol";

contract UpgradeRegistry is BaseScript {
    function run(address proxyAddress) public broadcast {
        console.log("Deploying new Registry implementation...\n");

        // deploy registry implementation contract
        Registry newRegistryImpl = new Registry();

        console.log("New Registry implementation: %s\n", address(newRegistryImpl));
        console.log("Upgrading Registry proxy...\n");

        // upgrade
        Registry(proxyAddress).upgradeToAndCall(address(newRegistryImpl), "");

        // validate
        assert(Registry(proxyAddress).getImplementation() == address(newRegistryImpl));

        console.log("Registry upgraded");
    }
}
