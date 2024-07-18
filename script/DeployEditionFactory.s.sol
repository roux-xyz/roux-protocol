// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { RouxEditionFactory } from "src/RouxEditionFactory.sol";
import { BaseScript } from "./Base.s.sol";

import "forge-std/Script.sol";

contract DeployEditionFactory is BaseScript {
    function run(address editionBeacon) public broadcast {
        console.log("Deploying RouxEditionFactory implementation...\n");

        // deploy edition factory implementation contract
        RouxEditionFactory rouxEditionFactoryImpl = new RouxEditionFactory(editionBeacon);

        console.log("RouxEditionFactory implementation: %s\n", address(rouxEditionFactoryImpl));
        console.log("Deploying RouxEditionFactory proxy...\n");

        // deploy edition factory proxy
        bytes memory initData = abi.encodeWithSelector(RouxEditionFactory.initialize.selector);
        ERC1967Proxy rouxEditionFactoryProxy = new ERC1967Proxy(address(rouxEditionFactoryImpl), initData);

        console.log("RouxEditionFactory proxy: %s\n", address(rouxEditionFactoryProxy));
    }
}
