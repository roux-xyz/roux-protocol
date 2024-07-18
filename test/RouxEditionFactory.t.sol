// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IRouxEditionFactory } from "src/interfaces/IRouxEditionFactory.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { RouxEditionFactory } from "src/RouxEditionFactory.sol";
import { BaseTest } from "./Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract RouxEditionFactoryTest is BaseTest {
    function setUp() public virtual override {
        BaseTest.setUp();
    }

    function test__RevertWhen_OnlyAllowlist() external {
        vm.startPrank(users.user_0);

        // create edition instance
        bytes memory params = abi.encode(CONTRACT_URI);
        RouxEdition edition_ = RouxEdition(factory.create(params));

        vm.expectRevert(IRouxEdition.OnlyAllowlist.selector);
        edition_.add(defaultAddParams);

        vm.stopPrank();
    }

    function test__RevertWhen_OnlyOwner_AddAllowlist() external {
        vm.expectRevert(Ownable.Unauthorized.selector);

        address[] memory allowlist = new address[](1);
        allowlist[0] = users.creator_1;

        vm.prank(users.creator_0);
        factory.addAllowlist(allowlist);
    }

    function test__RevertWhen_AlreadyInitialized() external {
        // verify current implementation
        assertEq(factory.getImplementation(), address(factoryImpl));

        // deploy new factory
        vm.startPrank(users.deployer);
        RouxEditionFactory newFactoryImpl = new RouxEditionFactory(address(editionBeacon));

        // init data
        bytes memory initData = abi.encodeWithSelector(factory.initialize.selector, users.deployer);

        // upgrade
        vm.expectRevert("Already initialized");
        factory.upgradeToAndCall(address(newFactoryImpl), initData);

        vm.stopPrank();
    }

    function test__Owner() external {
        assertEq(factory.owner(), address(users.deployer));
    }

    function test__DisableAllowlist() external {
        // disable allowlist
        vm.prank(users.deployer);
        factory.setAllowlist(false);

        // allow anyone to create
        vm.prank(users.user_0);
        bytes memory params = abi.encode(CONTRACT_URI);
        address newEdition = factory.create(params);

        assertEq(factory.isEdition(newEdition), true);
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
        RouxEditionFactory(factory).addAllowlist(allowlist);

        vm.prank(users.creator_2);
        bytes memory params = abi.encode(CONTRACT_URI);
        address newEdition = factory.create(params);

        assertEq(factory.isEdition(newEdition), true);
    }

    function test__RemoveAllowlist() external {
        // add to allowlist
        address[] memory allowlist = new address[](1);
        allowlist[0] = users.creator_2;

        vm.prank(users.deployer);
        RouxEditionFactory(factory).addAllowlist(allowlist);

        // remove user from allowlist
        vm.prank(users.deployer);
        RouxEditionFactory(factory).removeAllowlist(users.creator_2);

        // add new edition
        vm.startPrank(users.creator_2);
        bytes memory params = abi.encode(CONTRACT_URI);
        RouxEdition edition1 = RouxEdition(factory.create(params));

        // attempt to add token
        vm.expectRevert(IRouxEdition.OnlyAllowlist.selector);
        edition1.add(defaultAddParams);

        vm.stopPrank();
    }

    function test__Create() external {
        vm.prank(users.creator_0);

        // create instance
        bytes memory params = abi.encode(CONTRACT_URI);
        address newEdition = factory.create(params);

        assertEq(factory.isEdition(newEdition), true);
    }

    function test__IsEdition_True() external {
        vm.prank(users.creator_0);
        bytes memory params = abi.encode(CONTRACT_URI);
        address newEdition = factory.create(params);

        assertEq(factory.isEdition(newEdition), true);
    }

    function test__IsEdition_False() external {
        assertFalse(factory.isEdition(address(users.creator_0)));
    }

    function test__getEditions() external {
        // add to allowlist
        address[] memory allowlist = new address[](2);
        allowlist[0] = users.creator_1;
        allowlist[1] = users.creator_2;

        vm.prank(users.deployer);
        RouxEditionFactory(factory).addAllowlist(allowlist);

        // create editions
        address[] memory editions = new address[](3);

        // set params
        bytes memory params = abi.encode(CONTRACT_URI);

        vm.prank(users.creator_0);
        editions[0] = factory.create(params);

        vm.prank(users.creator_1);
        editions[1] = factory.create(params);

        vm.prank(users.creator_2);
        editions[2] = factory.create(params);

        // get editions
        address[] memory result = factory.getEditions();

        assertEq(result.length, 4);
        assertEq(result[0], address(edition));
        assertEq(result[1], editions[0]);
        assertEq(result[2], editions[1]);
        assertEq(result[3], editions[2]);
    }

    function test__UpgradeFactory() external {
        // verify current implementation
        assertEq(factory.getImplementation(), address(factoryImpl));

        // deploy new factory
        vm.startPrank(users.deployer);
        RouxEditionFactory newFactoryImpl = new RouxEditionFactory(address(editionBeacon));

        // upgrade
        factory.upgradeToAndCall(address(newFactoryImpl), "");

        vm.stopPrank();

        // verify
        assertEq(factory.getImplementation(), address(newFactoryImpl));
    }
}
