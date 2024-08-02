// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { BaseTest } from "test/Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";

contract Admin_Registry_Unit_Concrete_Test is BaseTest {
    function setUp() public virtual override {
        BaseTest.setUp();
    }

    function test__RevertWhen_UpgradeToAndCall_OnlyOwner() external {
        vm.prank(creator);
        vm.expectRevert(Ownable.Unauthorized.selector);
        registry.upgradeToAndCall(address(edition), "");
    }

    function test__Owner() external view {
        assertEq(registry.owner(), address(users.deployer));
    }
}
