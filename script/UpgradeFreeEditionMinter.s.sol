// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { FreeEditionMinter } from "src/minters/FreeEditionMinter.sol";
import { IEditionMinter } from "src/interfaces/IEditionMinter.sol";
import { BaseScript } from "./Base.s.sol";

import "forge-std/Script.sol";

contract UpgradeFreeEditionMinter is BaseScript {
    function run(address currentProxy, address controller) public broadcast {
        console.log("Upgrading FreeEditionMinter implementation...\n");

        // deploy editionMinter implementation contract
        FreeEditionMinter newFreeEditionMinter = new FreeEditionMinter(controller);

        console.log("New FreeEditionMinter implementation: %s\n", address(newFreeEditionMinter));
        console.log("Upgrading FreeEditionMinter proxy...\n");

        // upgrade
        IEditionMinter(currentProxy).upgradeToAndCall(address(newFreeEditionMinter), "");

        // verify
        assert(FreeEditionMinter(currentProxy).getImplementation() == address(newFreeEditionMinter));

        console.log("FreeEditionMinter upgraded");
    }
}
