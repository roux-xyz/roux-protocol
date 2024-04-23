// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { DefaultEditionMinter } from "src/minters/DefaultEditionMinter.sol";
import { BaseScript } from "./Base.s.sol";

import "forge-std/Script.sol";

contract DeployDefaultEditionMinter is BaseScript {
    function run(address controller) public broadcast {
        console.log("Deploying DefaultEditionMinter implementation...\n");

        // deploy defaultEditionMinter implementation contract
        DefaultEditionMinter defaultEditionMinter = new DefaultEditionMinter(controller);

        console.log("DefaultEditionMinter implementation: %s\n", address(defaultEditionMinter));
        console.log("Deploying DefaultEditionMinter proxy...\n");

        // deploy controller proxy
        bytes memory initData = abi.encodeWithSelector(DefaultEditionMinter.initialize.selector);
        ERC1967Proxy defaultEditionMinterProxy = new ERC1967Proxy(address(defaultEditionMinter), initData);

        console.log("DefaultEditionMinter proxy: %s\n", address(defaultEditionMinterProxy));
    }
}
