// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import { RouxEdition } from "src/RouxEdition.sol";
import { BaseScript } from "./Base.s.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract UpgradeEditionImpl is BaseScript {
    function run(
        address editionBeacon,
        address controller,
        address registry,
        address[] memory minters
    )
        public
        broadcast
    {
        address currentImpl = UpgradeableBeacon(editionBeacon).implementation();
        console.log("Current Edition Implementation: %s\n", currentImpl);

        console.log("Deploying new Edition implementation...\n");

        // deploy new implementation
        RouxEdition newEditionImpl = new RouxEdition(controller, registry, minters);
        console.log("New Edition Implementation: %s\n", address(newEditionImpl));

        // upgrade beacon
        UpgradeableBeacon(editionBeacon).upgradeTo(address(newEditionImpl));

        // assert that the beacon has been upgraded
        assert(UpgradeableBeacon(editionBeacon).implementation() == address(newEditionImpl));

        console.log("Edition Beacon upgraded to: %s\n", address(newEditionImpl));
    }
}
