// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Script.sol";

import { RouxEdition } from "src/RouxEdition.sol";
import { BaseScript } from "script/Base.s.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract DeployEditionImpl is BaseScript {
    function run(
        address controller,
        address registry,
        address currency
    )
        public
        broadcast
        returns (RouxEdition editionImpl, UpgradeableBeacon editionBeacon)
    {
        console.log("Deploying Edition implementation...\n");

        // deploy implementation
        editionImpl = new RouxEdition(controller, registry, currency);
        console.log("Edition Implementation: %s\n", address(editionImpl));
        console.log("Deploying Edition beacon...\n");

        // deploy beacon
        editionBeacon = new UpgradeableBeacon(address(editionImpl), msg.sender);
        console.log("Edition Beacon: %s\n", address(editionBeacon));
    }
}
