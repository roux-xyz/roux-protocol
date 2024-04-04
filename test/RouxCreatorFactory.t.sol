// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import { IRouxCreatorFactory } from "src/interfaces/IRouxCreatorFactory.sol";
import { RouxCreatorFactory } from "src/RouxCreatorFactory.sol";
import { BaseTest } from "./Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "./Constants.t.sol";

contract RouxCreatorFactoryTest is BaseTest {
    function setUp() public virtual override {
        BaseTest.setUp();
    }

    function test__RevertWhen_OnlyAllowlist() external {
        vm.expectRevert(IRouxCreatorFactory.OnlyAllowlist.selector);

        vm.prank(users.user_0);
        factory.create();
    }

    function test__RevertWhen_OnlyOwner_AddAllowlist() external {
        vm.expectRevert(Ownable.Unauthorized.selector);

        address[] memory allowlist = new address[](1);
        allowlist[0] = users.creator_1;

        vm.prank(users.creator_0);
        RouxCreatorFactory(factory).addAllowlist(allowlist);
    }

    function test__RevertWhen_AlreadyInitialized() external {
        /* verify current implementation */
        assertEq(factory.getImplementation(), address(factoryImpl));

        /* deploy new factory */
        vm.startPrank(users.deployer);
        RouxCreatorFactory newFactoryImpl = new RouxCreatorFactory(address(creatorBeacon));

        /* init data */
        bytes memory initData = abi.encodeWithSelector(factory.initialize.selector);

        /* upgrade */
        vm.expectRevert("Already initialized");
        factory.upgradeToAndCall(address(newFactoryImpl), initData);

        vm.stopPrank();
    }

    function test__Owner() external {
        assertEq(factory.owner(), address(users.deployer));
    }

    function test__TransferOwnership() external {
        vm.prank(users.deployer);
        factory.transferOwnership(users.creator_0);

        assertEq(factory.owner(), address(users.creator_0));
    }

    function test__AddAllowlist() external {
        address[] memory allowlist = new address[](1);
        allowlist[0] = users.creator_2;

        vm.prank(users.deployer);
        RouxCreatorFactory(factory).addAllowlist(allowlist);

        vm.prank(users.creator_2);
        address newCreator = factory.create();

        assert(factory.isCreator(newCreator));
    }

    function test__RemoveAllowlist() external {
        /* add to allowlist */
        address[] memory allowlist = new address[](1);
        allowlist[0] = users.creator_2;

        vm.prank(users.deployer);
        RouxCreatorFactory(factory).addAllowlist(allowlist);

        /* remove creator from allowlist */
        vm.prank(users.deployer);
        RouxCreatorFactory(factory).removeAllowlist(users.creator_2);

        /* attempt to create new creator */
        vm.prank(users.creator_2);
        vm.expectRevert(IRouxCreatorFactory.OnlyAllowlist.selector);
        factory.create();
    }

    function test__UpgradeFactory() external {
        /* verify current implementation */
        assertEq(factory.getImplementation(), address(factoryImpl));

        /* deploy new factory */
        vm.startPrank(users.deployer);
        RouxCreatorFactory newFactoryImpl = new RouxCreatorFactory(address(creatorBeacon));

        /* upgrade */
        factory.upgradeToAndCall(address(newFactoryImpl), "");

        vm.stopPrank();

        /* verify */
        assertEq(factory.getImplementation(), address(newFactoryImpl));
    }
}
