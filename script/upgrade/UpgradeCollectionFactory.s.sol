// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import "forge-std/Script.sol";
import { BaseScript } from "script/Base.s.sol";
import { CollectionFactory } from "src/CollectionFactory.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

interface IProxy {
    function upgradeTo(address newImplementation) external;
}

contract UpgradeCollectionFactory is BaseScript {
    function run(
        address proxyAddress,
        address singleEditionCollectionBeacon,
        address multiEditionCollectionBeacon
    )
        public
        broadcast
        returns (CollectionFactory newCollectionFactoryImpl)
    {
        console.log("Arguments: ");
        console.log("proxyAddress: %s", proxyAddress);
        console.log("singleEditionCollectionBeacon: %s", singleEditionCollectionBeacon);
        console.log("multiEditionCollectionBeacon: %s", multiEditionCollectionBeacon);
        console.log("\n");

        // read the current implementation address
        address currentImpl = CollectionFactory(proxyAddress).getImplementation();

        console.log("Current CollectionFactory Implementation: %s", currentImpl);

        // deploy new implementation with the constructor parameters
        console.log("Deploying new CollectionFactory implementation...");
        newCollectionFactoryImpl = new CollectionFactory(singleEditionCollectionBeacon, multiEditionCollectionBeacon);

        console.log("New CollectionFactory Implementation: %s", address(newCollectionFactoryImpl));

        // upgrade the proxy to use the new implementation
        console.log("Upgrading proxy to new implementation...");
        CollectionFactory(proxyAddress).upgradeToAndCall(address(newCollectionFactoryImpl), "");

        // verify that the proxy's implementation has been updated
        assert(CollectionFactory(proxyAddress).getImplementation() == address(newCollectionFactoryImpl));

        console.log("CollectionFactory Proxy upgraded to: %s", address(newCollectionFactoryImpl));
    }
}
