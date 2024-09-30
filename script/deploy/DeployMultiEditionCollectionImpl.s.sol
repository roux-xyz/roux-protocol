// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Script.sol";

import { MultiEditionCollection } from "src/MultiEditionCollection.sol";
import { BaseScript } from "script/Base.s.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract DeployMultiEditionCollectionImpl is BaseScript {
    function run(
        address erc6551registry,
        address accountImplementation,
        address editionFactory,
        address controller
    )
        public
        broadcast
        returns (MultiEditionCollection multiEditionCollectionImpl, UpgradeableBeacon multiEditionCollectionBeacon)
    {
        console.log("Arguments: ");
        console.log("erc6551registry: %s", erc6551registry);
        console.log("accountImplementation: %s", accountImplementation);
        console.log("editionFactory: %s", editionFactory);
        console.log("controller: %s", controller);
        console.log("\n");

        console.log("Deploying MultiEditionCollection implementation...\n");

        // deploy implementation
        multiEditionCollectionImpl =
            new MultiEditionCollection(erc6551registry, accountImplementation, editionFactory, controller);

        console.log("MultiEditionCollection Implementation: %s\n", address(multiEditionCollectionImpl));
        console.log("Deploying MultiEditionCollection beacon...\n");

        // deploy beacon
        multiEditionCollectionBeacon = new UpgradeableBeacon(address(multiEditionCollectionImpl), msg.sender);
        console.log("MultiEditionCollection Beacon: %s\n", address(multiEditionCollectionBeacon));
    }
}
