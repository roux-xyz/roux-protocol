// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { BaseScript } from "script/Base.s.sol";

contract DeployEditionImpl is BaseScript {
    function run(
        address editionFactory,
        address collectionFactory,
        address controller,
        address registry,
        address currency
    )
        public
        broadcast
        returns (RouxEdition editionImpl)
    {
        console.log("Deploying Edition implementation...\n");

        // deploy implementation
        editionImpl = new RouxEdition(editionFactory, collectionFactory, controller, registry, currency);
        console.log("Edition Implementation: %s\n", address(editionImpl));
    }
}
