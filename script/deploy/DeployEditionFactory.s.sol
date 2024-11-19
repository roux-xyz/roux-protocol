// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { RouxEditionFactory } from "src/core/RouxEditionFactory.sol";
import { BaseScript } from "script/Base.s.sol";

import "forge-std/Script.sol";

contract DeployEditionFactory is BaseScript {
    function run(
        address editionBeacon,
        address coCreateBeacon
    )
        public
        broadcast
        returns (RouxEditionFactory editionFactoryImpl, RouxEditionFactory editionFactoryProxy)
    {
        console.log("Deploying RouxEditionFactory implementation...\n");

        // deploy edition factory implementation contract
        editionFactoryImpl = new RouxEditionFactory(editionBeacon, coCreateBeacon);

        console.log("RouxEditionFactory implementation: %s\n", address(editionFactoryImpl));
        console.log("Deploying RouxEditionFactory proxy...\n");

        // deploy edition factory proxy
        bytes memory initData = abi.encodeWithSelector(RouxEditionFactory.initialize.selector);
        editionFactoryProxy = RouxEditionFactory(address(new ERC1967Proxy(address(editionFactoryImpl), initData)));

        console.log("RouxEditionFactory proxy: %s\n", address(editionFactoryProxy));
    }
}
