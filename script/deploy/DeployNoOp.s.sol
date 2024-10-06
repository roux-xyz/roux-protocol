// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import "forge-std/Script.sol";
import { NoOp } from "src/NoOp.sol";
import { BaseScript } from "script/Base.s.sol";

contract DeployNoOp is BaseScript {
    function run() public broadcast returns (NoOp noOpImpl) {
        console.log("Deploying NoOp implementation...\n");

        // deploy NoOp implementation
        noOpImpl = new NoOp();
        console.log("NoOp Implementation: %s\n", address(noOpImpl));
    }
}
