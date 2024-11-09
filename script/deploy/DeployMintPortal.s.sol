// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { RouxMintPortal } from "src/periphery/RouxMintPortal.sol";
import { BaseScript } from "script/Base.s.sol";

import "forge-std/Script.sol";

contract DeployMintPortal is BaseScript {
    function run(
        address underlying,
        address editionFactory,
        address collectionFactory
    )
        public
        broadcast
        returns (RouxMintPortal mintPortalImpl, RouxMintPortal mintPortalProxy)
    {
        console.log("Deploying RouxMintPortal implementation...\n");

        // deploy mint portal implementation contract
        mintPortalImpl = new RouxMintPortal(underlying, editionFactory, collectionFactory);

        console.log("RouxMintPortal implementation: %s\n", address(mintPortalImpl));
        console.log("Deploying RouxMintPortal proxy...\n");

        // deploy edition factory proxy
        bytes memory initData = abi.encodeWithSelector(RouxMintPortal.initialize.selector);
        mintPortalProxy = RouxMintPortal(address(new ERC1967Proxy(address(mintPortalImpl), initData)));

        console.log("RouxMintPortal proxy: %s\n", address(mintPortalProxy));
    }
}
