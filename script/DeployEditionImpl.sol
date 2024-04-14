// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import { RouxEdition } from "src/RouxEdition.sol";
import { BaseScript } from "./Base.s.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract DeployEditionImpl is BaseScript {
    function run(address administrator) public broadcast {
        /* deploy implementation */
        RouxEdition editionImpl = new RouxEdition(administrator);
        console.log("Creator Implementation: ", address(editionImpl));

        /* deploy beacon */
        UpgradeableBeacon editionBeacon = new UpgradeableBeacon(address(editionImpl), msg.sender);
        console.log("Creator Beacon: ", address(editionBeacon));
    }
}
