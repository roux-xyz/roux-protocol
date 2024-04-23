// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { FreeEditionMinter } from "src/minters/FreeEditionMinter.sol";
import { BaseScript } from "./Base.s.sol";

import "forge-std/Script.sol";

contract DeployFreeEditionMinter is BaseScript {
    function run(address controller) public broadcast {
        console.log("Deploying FreeEditionMinter implementation...\n");

        // deploy freeEditionMinter implementation contract
        FreeEditionMinter freeEditionMinter = new FreeEditionMinter(controller);

        console.log("FreeEditionMinter implementation: %s\n", address(freeEditionMinter));
        console.log("Deploying FreeEditionMinter proxy...\n");

        // deploy controller proxy
        bytes memory initData = abi.encodeWithSelector(FreeEditionMinter.initialize.selector);
        ERC1967Proxy freeEditionMinterProxy = new ERC1967Proxy(address(freeEditionMinter), initData);

        console.log("FreeEditionMinter proxy: %s\n", address(freeEditionMinterProxy));
    }
}
