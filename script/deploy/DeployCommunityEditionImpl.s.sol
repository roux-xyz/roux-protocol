// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import "forge-std/Script.sol";
import { RouxCommunityEdition } from "src/core/RouxCommunityEdition.sol";
import { BaseScript } from "script/Base.s.sol";

contract DeployCommunityEditionImpl is BaseScript {
    function run(
        address editionFactory,
        address collectionFactory,
        address controller,
        address registry
    )
        public
        broadcast
        returns (RouxCommunityEdition editionImpl)
    {
        console.log("Deploying Community Edition implementation...\n");

        // deploy implementation
        editionImpl = new RouxCommunityEdition(editionFactory, collectionFactory, controller, registry);
        console.log("Community Edition Implementation: %s\n", address(editionImpl));
    }
}
