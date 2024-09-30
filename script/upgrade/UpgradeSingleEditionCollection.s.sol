// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Script.sol";

import { SingleEditionCollection } from "src/SingleEditionCollection.sol";
import { BaseScript } from "script/Base.s.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract UpgradeSingleEditionCollection is BaseScript {
    function run(
        address singleEditionCollectionBeacon,
        address erc6551registry,
        address accountImplementation,
        address editionFactory,
        address controller
    )
        public
        broadcast
        returns (SingleEditionCollection newSingleEditionCollectionImpl)
    {
        console.log("Arguments: ");
        console.log("singleEditionCollectionBeacon: %s", singleEditionCollectionBeacon);
        console.log("erc6551registry: %s", erc6551registry);
        console.log("accountImplementation: %s", accountImplementation);
        console.log("editionFactory: %s", editionFactory);
        console.log("controller: %s", controller);
        console.log("\n");

        address currentImpl = UpgradeableBeacon(singleEditionCollectionBeacon).implementation();
        console.log("Current SingleEditionCollection Implementation: %s\n", currentImpl);

        console.log("Deploying new SingleEditionCollection implementation...\n");

        // deploy new implementation
        newSingleEditionCollectionImpl =
            new SingleEditionCollection(erc6551registry, accountImplementation, editionFactory, controller);
        console.log("New SingleEditionCollection Implementation: %s\n", address(newSingleEditionCollectionImpl));

        // upgrade beacon
        UpgradeableBeacon(singleEditionCollectionBeacon).upgradeTo(address(newSingleEditionCollectionImpl));

        // assert that the beacon has been upgraded
        assert(
            UpgradeableBeacon(singleEditionCollectionBeacon).implementation() == address(newSingleEditionCollectionImpl)
        );

        console.log("SingleEditionCollection Beacon upgraded to: %s\n", address(newSingleEditionCollectionImpl));
    }
}
