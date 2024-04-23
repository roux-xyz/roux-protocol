// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { EditionMinter } from "src/minters/EditionMinter.sol";
import { BaseScript } from "./Base.s.sol";

import "forge-std/Script.sol";

contract DeployEditionMinter is BaseScript {
    function run(address controller) public broadcast {
        console.log("Deploying EditionMinter implementation...\n");

        // deploy editionMinter implementation contract
        EditionMinter editionMinter = new EditionMinter(controller);

        console.log("EditionMinter implementation: %s\n", address(editionMinter));
        console.log("Deploying EditionMinter proxy...\n");

        // deploy controller proxy
        bytes memory initData = abi.encodeWithSelector(EditionMinter.initialize.selector);
        ERC1967Proxy editionMinterProxy = new ERC1967Proxy(address(editionMinter), initData);

        console.log("EditionMinter proxy: %s\n", address(editionMinterProxy));
    }
}
