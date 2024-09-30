// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Script.sol";

import { MultiEditionCollection } from "src/MultiEditionCollection.sol";
import { BaseScript } from "script/Base.s.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract UpgradeMultiEditionCollection is BaseScript {
    function run(
        address multiEditionCollectionBeacon,
        address erc6551registry,
        address accountImplementation,
        address editionFactory,
        address controller
    )
        public
        broadcast
        returns (MultiEditionCollection newMultiEditionCollectionImpl)
    {
        console.log("Arguments: ");
        console.log("multiEditionCollectionBeacon: %s", multiEditionCollectionBeacon);
        console.log("erc6551registry: %s", erc6551registry);
        console.log("accountImplementation: %s", accountImplementation);
        console.log("editionFactory: %s", editionFactory);
        console.log("controller: %s", controller);
        console.log("\n");

        address currentImpl = UpgradeableBeacon(multiEditionCollectionBeacon).implementation();
        console.log("Current MultiEditionCollection Implementation: %s\n", currentImpl);

        console.log("Deploying new MultiEditionCollection implementation...\n");

        // deploy new implementation
        newMultiEditionCollectionImpl =
            new MultiEditionCollection(erc6551registry, accountImplementation, editionFactory, controller);
        console.log("New MultiEditionCollection Implementation: %s\n", address(newMultiEditionCollectionImpl));

        // upgrade beacon
        UpgradeableBeacon(multiEditionCollectionBeacon).upgradeTo(address(newMultiEditionCollectionImpl));

        // assert that the beacon has been upgraded
        assert(
            UpgradeableBeacon(multiEditionCollectionBeacon).implementation() == address(newMultiEditionCollectionImpl)
        );

        console.log("MultiEditionCollection Beacon upgraded to: %s\n", address(newMultiEditionCollectionImpl));
    }
}
