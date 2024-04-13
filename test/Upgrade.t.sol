// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import { BaseTest } from "./Base.t.sol";

import { IRouxCreator } from "src/interfaces/IRouxCreator.sol";
import { RouxCreator } from "src/RouxCreator.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract UpgradeTest is BaseTest {
    function setUp() public virtual override {
        BaseTest.setUp();
    }

    function test__Upgrade() external {
        /* assert current implementation */
        assertEq(creatorBeacon.implementation(), address(creatorImpl));

        /* deploy new creator implementation */
        IRouxCreator newCreatorImpl = new RouxCreator(address(administrator));

        /* set new implementation in beacon */
        vm.prank(users.deployer);
        creatorBeacon.upgradeTo(address(newCreatorImpl));

        /* assert new implementation */
        assertEq(creatorBeacon.implementation(), address(newCreatorImpl));

        /* assert different implementation */
        assertNotEq(creatorBeacon.implementation(), address(creatorImpl));
    }
}
