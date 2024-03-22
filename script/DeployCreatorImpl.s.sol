// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import "forge-std/Script.sol";

import { RouxCreator } from "src/RouxCreator.sol";
import { BaseScript } from "./Base.s.sol";

contract DeployCreatorImpl is BaseScript {
    function run() public broadcast {
        RouxCreator creatorImpl = new RouxCreator();
        console.log("Creator Implementation: ", address(creatorImpl));
    }
}
