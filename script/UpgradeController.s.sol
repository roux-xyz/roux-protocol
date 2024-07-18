// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Controller} from "src/Controller.sol";
import {BaseScript} from "./Base.s.sol";

import "forge-std/Script.sol";

contract UpgradeController is BaseScript {
    function run(address proxyAddress, address registry, address currency) public broadcast {
        console.log("Deploying new Controller implementation...\n");

        // deploy controller implementation contract
        Controller newControllerImpl = new Controller(registry, currency);

        console.log("New Controller implementation: %s\n", address(newControllerImpl));
        console.log("Upgrading Controller proxy...\n");

        // upgrade
        Controller(proxyAddress).upgradeToAndCall(address(newControllerImpl), "");

        // verify
        assert(Controller(proxyAddress).getImplementation() == address(newControllerImpl));

        console.log("Controller upgraded");
    }
}
