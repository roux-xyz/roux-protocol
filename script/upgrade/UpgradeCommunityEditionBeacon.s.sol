// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import "forge-std/Script.sol";
import { BaseScript } from "script/Base.s.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract UpgradeCommunityEditionBeacon is BaseScript {
    function run(address communityEditionBeacon, address newImplementation) public broadcast {
        address currentImpl = UpgradeableBeacon(communityEditionBeacon).implementation();
        console.log("Current Community Edition Implementation: %s\n", currentImpl);

        console.log("Upgrading Community Edition Beacon...\n");

        // upgrade beacon
        UpgradeableBeacon(communityEditionBeacon).upgradeTo(newImplementation);

        // assert that the beacon has been upgraded
        assert(UpgradeableBeacon(communityEditionBeacon).implementation() == newImplementation);

        console.log("Community Edition Beacon upgraded to: %s\n", newImplementation);
    }
}
