// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import "forge-std/Script.sol";

import { RouxCreator } from "src/RouxCreator.sol";
import { BaseScript } from "./Base.s.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract DeployCreatorImpl is BaseScript {
    function run() public broadcast {
        /* deploy implementation */
        RouxCreator creatorImpl = new RouxCreator();
        console.log("Creator Implementation: ", address(creatorImpl));

        /* deploy beacon */
        UpgradeableBeacon creatorBeacon = new UpgradeableBeacon(address(creatorImpl), msg.sender);
        console.log("Creator Beacon: ", address(creatorBeacon));
        console.log("Owner: ", msg.sender);
    }
}
