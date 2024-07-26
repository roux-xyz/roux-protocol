// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { BaseTest } from "./Base.t.sol";
import { IRouxEditionFactory } from "src/interfaces/IRouxEditionFactory.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { RouxEditionFactory } from "src/RouxEditionFactory.sol";
import { Initializable } from "solady/utils/Initializable.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";

contract RouxEditionFactoryTest is BaseTest {
    function setUp() public virtual override {
        BaseTest.setUp();
    }

    function test__RevertWhen_OnlyAllowlist() external {
        bytes memory params = abi.encode(CONTRACT_URI);

        vm.prank(users.deployer);
        factory.setAllowlist(true);

        vm.startPrank(user);
        vm.expectRevert(ErrorsLib.RouxEdition_OnlyAllowlist.selector);
        RouxEdition edition_ = RouxEdition(factory.create(params));

        vm.stopPrank();
    }

    function test__RevertWhen_OnlyOwner_AddAllowlist() external {
        vm.expectRevert(Ownable.Unauthorized.selector);

        address[] memory allowlist = new address[](1);
        allowlist[0] = users.creator_1;

        vm.prank(creator);
        factory.addAllowlist(allowlist);
    }

    function test__RevertWhen_AlreadyInitialized() external {
        assertEq(factory.getImplementation(), address(factoryImpl));

        vm.startPrank(users.deployer);
        RouxEditionFactory newFactoryImpl = new RouxEditionFactory(address(editionBeacon));

        bytes memory initData = abi.encodeWithSelector(factory.initialize.selector, users.deployer);

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        factory.upgradeToAndCall(address(newFactoryImpl), initData);

        vm.stopPrank();
    }

    function test__Owner() external {
        assertEq(factory.owner(), address(users.deployer));
    }

    function test__DisableAllowlist() external {
        vm.prank(users.deployer);
        factory.setAllowlist(false);

        vm.prank(user);
        bytes memory params = abi.encode(CONTRACT_URI);
        address newEdition = factory.create(params);

        assertEq(factory.isEdition(newEdition), true);
    }

    function test__TransferOwnership() external {
        vm.prank(users.deployer);
        factory.transferOwnership(creator);

        assertEq(factory.owner(), address(creator));
    }

    function test__AddAllowlist() external {
        address[] memory allowlist = new address[](1);
        allowlist[0] = users.creator_2;

        vm.prank(users.deployer);
        RouxEditionFactory(factory).addAllowlist(allowlist);

        vm.prank(users.creator_2);
        bytes memory params = abi.encode(CONTRACT_URI);
        address newEdition = factory.create(params);

        assertEq(factory.isEdition(newEdition), true);
    }

    function test__RemoveAllowlist() external {
        address[] memory allowlist = new address[](1);
        allowlist[0] = users.creator_2;

        vm.prank(users.deployer);
        RouxEditionFactory(factory).addAllowlist(allowlist);

        vm.prank(users.deployer);
        RouxEditionFactory(factory).removeAllowlist(users.creator_2);

        bytes memory params = abi.encode(CONTRACT_URI);
        vm.startPrank(users.creator_2);
        address newEdition = factory.create(params);

        assertEq(factory.isEdition(newEdition), true);

        vm.stopPrank();
    }

    function test__Create() external {
        vm.prank(creator);

        bytes memory params = abi.encode(CONTRACT_URI);
        address newEdition = factory.create(params);

        assertEq(factory.isEdition(newEdition), true);
    }

    function test__IsEdition_True() external {
        vm.prank(creator);
        bytes memory params = abi.encode(CONTRACT_URI);
        address newEdition = factory.create(params);

        assertEq(factory.isEdition(newEdition), true);
    }

    function test__IsEdition_False() external {
        assertFalse(factory.isEdition(address(creator)));
    }

    function test__getEditions() external {
        address[] memory allowlist = new address[](2);
        allowlist[0] = users.creator_1;
        allowlist[1] = users.creator_2;

        vm.prank(users.deployer);
        RouxEditionFactory(factory).addAllowlist(allowlist);

        address[] memory editions = new address[](3);
        bytes memory params = abi.encode(CONTRACT_URI);

        vm.prank(creator);
        editions[0] = factory.create(params);

        vm.prank(users.creator_1);
        editions[1] = factory.create(params);

        vm.prank(users.creator_2);
        editions[2] = factory.create(params);
    }

    function test__UpgradeFactory() external {
        assertEq(factory.getImplementation(), address(factoryImpl));

        vm.startPrank(users.deployer);
        RouxEditionFactory newFactoryImpl = new RouxEditionFactory(address(editionBeacon));

        factory.upgradeToAndCall(address(newFactoryImpl), "");

        vm.stopPrank();

        assertEq(factory.getImplementation(), address(newFactoryImpl));
    }
}
