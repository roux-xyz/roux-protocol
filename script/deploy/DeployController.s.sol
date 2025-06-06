// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Controller } from "src/core/Controller.sol";
import { BaseScript } from "script/Base.s.sol";

import "forge-std/Script.sol";

contract DeployController is BaseScript {
    function run(
        address registry,
        address currency
    )
        public
        broadcast
        returns (Controller controller, Controller controllerProxy)
    {
        console.log("Deploying Controller implementation...\n");

        // deploy controller implementation contract
        controller = new Controller(registry, currency);

        console.log("Controller implementation: %s\n", address(controller));
        console.log("Deploying Controller proxy...\n");

        // deploy controller proxy
        bytes memory initData = abi.encodeWithSelector(Controller.initialize.selector);
        controllerProxy = Controller(address(new ERC1967Proxy(address(controller), initData)));

        console.log("Controller proxy deployed at: %s\n", address(controllerProxy));
    }
}
