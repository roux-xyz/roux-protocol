// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import "forge-std/Script.sol";

import { RouxEditionFactory } from "src/RouxEditionFactory.sol";
import { BaseScript } from "./Base.s.sol";

contract DeployEditionFactory is BaseScript {
    function run(address editionImpl) public broadcast {
        RouxEditionFactory editionFactory = new RouxEditionFactory(editionImpl);
        console.log("Creator Factory: ", address(editionFactory));
    }
}
