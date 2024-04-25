// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { EditionMinter } from "src/minters/EditionMinter.sol";
import { IEditionMinter } from "src/interfaces/IEditionMinter.sol";
import { BaseScript } from "./Base.s.sol";

import "forge-std/Script.sol";

contract UpgradeEditionMinter is BaseScript {
    function run(address currentProxy, address controller) public broadcast {
        console.log("Upgrading EditionMinter implementation...\n");

        // deploy editionMinter implementation contract
        EditionMinter newEditionMinter = new EditionMinter(controller);

        console.log("New EditionMinter implementation: %s\n", address(newEditionMinter));
        console.log("Upgrading EditionMinter proxy...\n");

        // upgrade
        IEditionMinter(currentProxy).upgradeToAndCall(address(newEditionMinter), "");

        // verify
        assert(EditionMinter(currentProxy).getImplementation() == address(newEditionMinter));

        console.log("EditionMinter upgraded");
    }
}
