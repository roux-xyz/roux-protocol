// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import "forge-std/Script.sol";

import { CollectionFactory } from "src/CollectionFactory.sol";
import { BaseScript } from "./Base.s.sol";

contract DeployCollectionFactory is BaseScript {
    function run(address collectionImpl) public broadcast {
        CollectionFactory collectionFactory = new CollectionFactory(collectionImpl);
        console.log("Collection Factory: ", address(collectionFactory));
    }
}
