// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import "forge-std/Script.sol";
import { BaseScript } from "script/Base.s.sol";
import { RouxEditionFactory } from "src/core/RouxEditionFactory.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

interface IProxy {
    function upgradeTo(address newImplementation) external;
}

contract UpgradeRouxEditionFactory is BaseScript {
    function run(
        address proxyAddress,
        address editionBeacon,
        address communityBeacon
    )
        public
        broadcast
        returns (RouxEditionFactory newRouxEditionFactoryImpl)
    {
        console.log("Arguments: ");
        console.log("proxyAddress: %s", proxyAddress);
        console.log("editionBeacon: %s", editionBeacon);
        console.log("communityBeacon: %s", communityBeacon);
        console.log("\n");

        // read the current implementation address
        address currentImpl = RouxEditionFactory(proxyAddress).getImplementation();

        console.log("Current RouxEditionFactory Implementation: %s", currentImpl);

        // deploy new implementation with the constructor parameters
        console.log("Deploying new RouxEditionFactory implementation...");
        newRouxEditionFactoryImpl = new RouxEditionFactory(editionBeacon, communityBeacon);

        console.log("New RouxEditionFactory Implementation: %s", address(newRouxEditionFactoryImpl));

        // upgrade the proxy to use the new implementation
        console.log("Upgrading proxy to new implementation...");
        RouxEditionFactory(proxyAddress).upgradeToAndCall(address(newRouxEditionFactoryImpl), "");

        // verify that the proxy's implementation has been updated
        assert(RouxEditionFactory(proxyAddress).getImplementation() == address(newRouxEditionFactoryImpl));

        console.log("RouxEditionFactory Proxy upgraded to: %s", address(newRouxEditionFactoryImpl));
    }
}
