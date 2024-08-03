// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { CollectionFactory } from "src/CollectionFactory.sol";
import { BaseScript } from "script/Base.s.sol";

import "forge-std/Script.sol";

contract DeployCollectionFactory is BaseScript {
    function run(
        address singleEditionCollectionBeacon,
        address multiEditionCollectionBeacon
    )
        public
        broadcast
        returns (CollectionFactory collectionFactoryImpl, CollectionFactory collectionFactoryProxy)
    {
        console.log("Deploying CollectionFactory implementation...\n");

        // deploy edition factory implementation contract
        collectionFactoryImpl = new CollectionFactory(singleEditionCollectionBeacon, multiEditionCollectionBeacon);

        console.log("CollectionFactory implementation: %s\n", address(collectionFactoryImpl));
        console.log("Deploying CollectionFactory proxy...\n");

        // deploy edition factory proxy
        bytes memory initData = abi.encodeWithSelector(CollectionFactory.initialize.selector);
        collectionFactoryProxy = CollectionFactory(address(new ERC1967Proxy(address(collectionFactoryImpl), initData)));

        console.log("CollectionFactory proxy deployed at: %s\n", address(collectionFactoryProxy));
    }
}
