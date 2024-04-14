// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import { IRouxEditionFactory } from "src/interfaces/IRouxEditionFactory.sol";
import { RouxEditionFactory } from "src/RouxEditionFactory.sol";
import { BaseTest } from "./Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "./Constants.t.sol";

contract RouxEditionFactoryTest is BaseTest {
    function setUp() public virtual override {
        BaseTest.setUp();
    }

    function test__RevertWhen_OnlyAllowlist() external {
        vm.expectRevert(IRouxEditionFactory.OnlyAllowlist.selector);

        vm.prank(users.user_0);
        factory.create();
    }

    function test__RevertWhen_OnlyOwner_AddAllowlist() external {
        vm.expectRevert(Ownable.Unauthorized.selector);

        address[] memory allowlist = new address[](1);
        allowlist[0] = users.edition_1;

        vm.prank(users.edition_0);
        RouxEditionFactory(factory).addAllowlist(allowlist);
    }

    function test__RevertWhen_AlreadyInitialized() external {
        /* verify current implementation */
        assertEq(factory.getImplementation(), address(factoryImpl));

        /* deploy new factory */
        vm.startPrank(users.deployer);
        RouxEditionFactory newFactoryImpl = new RouxEditionFactory(address(editionBeacon));

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

    function test__DisableAllowlist() external {
        /* disable allowlist */
        vm.prank(users.deployer);
        factory.setAllowlist(false);

        /* allow anyone to create */
        vm.prank(users.user_0);
        address newCreator = factory.create();

        assert(factory.isCreator(newCreator));
    }

    function test__TransferOwnership() external {
        vm.prank(users.deployer);
        factory.transferOwnership(users.edition_0);

        assertEq(factory.owner(), address(users.edition_0));
    }

    function test__AddAllowlist() external {
        address[] memory allowlist = new address[](1);
        allowlist[0] = users.edition_2;

        vm.prank(users.deployer);
        RouxEditionFactory(factory).addAllowlist(allowlist);

        vm.prank(users.edition_2);
        address newCreator = factory.create();

        assert(factory.isCreator(newCreator));
    }

    function test__RemoveAllowlist() external {
        /* add to allowlist */
        address[] memory allowlist = new address[](1);
        allowlist[0] = users.edition_2;

        vm.prank(users.deployer);
        RouxEditionFactory(factory).addAllowlist(allowlist);

        /* remove edition from allowlist */
        vm.prank(users.deployer);
        RouxEditionFactory(factory).removeAllowlist(users.edition_2);

        /* attempt to create new edition */
        vm.prank(users.edition_2);
        vm.expectRevert(IRouxEditionFactory.OnlyAllowlist.selector);
        factory.create();
    }

    function test__UpgradeFactory() external {
        /* verify current implementation */
        assertEq(factory.getImplementation(), address(factoryImpl));

        /* deploy new factory */
        vm.startPrank(users.deployer);
        RouxEditionFactory newFactoryImpl = new RouxEditionFactory(address(editionBeacon));

        /* upgrade */
        factory.upgradeToAndCall(address(newFactoryImpl), "");

        vm.stopPrank();

        /* verify */
        assertEq(factory.getImplementation(), address(newFactoryImpl));
    }
}
