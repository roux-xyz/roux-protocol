// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import "forge-std/Script.sol";

import { RouxCreatorFactory } from "src/RouxCreatorFactory.sol";
import { BaseScript } from "./Base.s.sol";

contract DeployCreatorFactory is BaseScript {
    function run(address creatorImpl) public broadcast {
        RouxCreatorFactory creatorFactory = new RouxCreatorFactory(creatorImpl);
        console.log("Creator Factory: ", address(creatorFactory));
    }
}
