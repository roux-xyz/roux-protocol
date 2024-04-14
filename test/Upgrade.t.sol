// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import { BaseTest } from "./Base.t.sol";

import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract UpgradeTest is BaseTest {
    function setUp() public virtual override {
        BaseTest.setUp();
    }

    function test__Upgrade() external {
        /* assert current implementation */
        assertEq(editionBeacon.implementation(), address(editionImpl));

        /* deploy new edition implementation */
        IRouxEdition newCreatorImpl = new RouxEdition(address(administrator));

        /* set new implementation in beacon */
        vm.prank(users.deployer);
        editionBeacon.upgradeTo(address(newCreatorImpl));

        /* assert new implementation */
        assertEq(editionBeacon.implementation(), address(newCreatorImpl));

        /* assert different implementation */
        assertNotEq(editionBeacon.implementation(), address(editionImpl));
    }
}
