// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import "forge-std/Script.sol";

import { SingleEditionCollection } from "src/core/SingleEditionCollection.sol";
import { BaseScript } from "script/Base.s.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract DeploySingleEditionCollectionImpl is BaseScript {
    function run(
        address erc6551registry,
        address accountImplementation,
        address editionFactory,
        address controller
    )
        public
        broadcast
        returns (SingleEditionCollection singleEditionCollectionImpl, UpgradeableBeacon singleEditionCollectionBeacon)
    {
        console.log("Arguments: ");
        console.log("erc6551registry: %s", erc6551registry);
        console.log("accountImplementation: %s", accountImplementation);
        console.log("editionFactory: %s", editionFactory);
        console.log("controller: %s", controller);
        console.log("\n");

        console.log("Deploying SingleEditionCollection implementation...\n");

        // deploy implementation
        singleEditionCollectionImpl =
            new SingleEditionCollection(erc6551registry, accountImplementation, editionFactory, controller);

        console.log("New SingleEditionCollection Implementation: %s\n", address(singleEditionCollectionImpl));
        console.log("Deploying SingleEditionCollection beacon...\n");

        // deploy beacon
        singleEditionCollectionBeacon = new UpgradeableBeacon(address(singleEditionCollectionImpl), msg.sender);
        console.log("SingleEditionCollection Beacon: %s\n", address(singleEditionCollectionBeacon));
    }
}
