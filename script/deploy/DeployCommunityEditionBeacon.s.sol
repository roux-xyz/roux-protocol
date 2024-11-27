// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import "forge-std/Script.sol";
import { BaseScript } from "script/Base.s.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract DeployCommunityEditionBeacon is BaseScript {
    function run(address implementation) public broadcast returns (UpgradeableBeacon editionBeacon) {
        console.log("Deploying Community Edition beacon...\n");

        // deploy beacon
        editionBeacon = new UpgradeableBeacon(implementation, msg.sender);
        console.log("Community Edition Beacon: %s\n", address(editionBeacon));
    }
}
