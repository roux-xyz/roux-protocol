// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { TestFreeMinter } from "src/test/TestFreeMinter.sol";
import { BaseScript } from ".././Base.s.sol";

import "forge-std/Script.sol";

contract DeployTestFreeMinter is BaseScript {
    function run(address controller) public broadcast {
        console.log("Deploying TestFreeMinter implementation...\n");

        // deploy testFreeMinter implementation contract
        TestFreeMinter testFreeMinter = new TestFreeMinter(controller);

        console.log("TestFreeMinter implementation: %s\n", address(testFreeMinter));
        console.log("Deploying TestFreeMinter proxy...\n");

        // deploy controller proxy
        bytes memory initData = abi.encodeWithSelector(TestFreeMinter.initialize.selector);
        ERC1967Proxy testFreeMinterProxy = new ERC1967Proxy(address(testFreeMinter), initData);

        console.log("TestFreeMinter proxy: %s\n", address(testFreeMinterProxy));
    }
}
