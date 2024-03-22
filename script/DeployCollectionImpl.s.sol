// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import "forge-std/Script.sol";

import { Collection } from "src/Collection.sol";
import { BaseScript } from "./Base.s.sol";

contract DeployCollectionImpl is BaseScript {
    function run(address erc6551Registry, address erc6551Account) public broadcast {
        Collection collectionImpl = new Collection(erc6551Registry, erc6551Account);
        console.log("Collection Implementation: ", address(collectionImpl));
    }
}
