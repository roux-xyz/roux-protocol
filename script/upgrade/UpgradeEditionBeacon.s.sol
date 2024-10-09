// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import "forge-std/Script.sol";
import { BaseScript } from "script/Base.s.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract UpgradeEditionBeacon is BaseScript {
    function run(address editionBeacon, address newImplementation) public broadcast {
        address currentImpl = UpgradeableBeacon(editionBeacon).implementation();
        console.log("Current Edition Implementation: %s\n", currentImpl);

        console.log("Upgrading Edition Beacon...\n");

        // upgrade beacon
        UpgradeableBeacon(editionBeacon).upgradeTo(newImplementation);

        // assert that the beacon has been upgraded
        assert(UpgradeableBeacon(editionBeacon).implementation() == newImplementation);

        console.log("Edition Beacon upgraded to: %s\n", newImplementation);
    }
}
