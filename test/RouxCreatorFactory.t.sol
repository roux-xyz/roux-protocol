// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import { IRouxCreatorFactory } from "src/interfaces/IRouxCreatorFactory.sol";
import { IFactory } from "src/interfaces/IFactory.sol";
import { RouxCreatorFactory } from "src/RouxCreatorFactory.sol";
import { BaseTest } from "./Base.t.sol";

import "./Constants.t.sol";

contract RouxCreatorFactoryTest is BaseTest {
    function setUp() public virtual override {
        BaseTest.setUp();
    }

    function test__RevertWhen_OnlyAllowlist() external {
        vm.expectRevert(IRouxCreatorFactory.OnlyAllowlist.selector);

        bytes memory params = abi.encode(address(users.creator_0));

        vm.prank(users.user_0);
        factory.create(params);
    }

    function test__RevertWhen_OnlyOwner_AddAllowlist() external {
        vm.expectRevert(IFactory.OnlyOwner.selector);

        address[] memory allowlist = new address[](1);
        allowlist[0] = users.creator_1;

        vm.prank(users.creator_0);
        RouxCreatorFactory(factory).addAllowlist(allowlist);
    }

    function test__AddAllowlist() external {
        address[] memory allowlist = new address[](1);
        allowlist[0] = users.creator_1;

        vm.prank(users.deployer);
        RouxCreatorFactory(factory).addAllowlist(allowlist);

        vm.prank(users.creator_1);
        bytes memory params = abi.encode(address(users.creator_1));
        address newCreator = factory.create(params);

        assert(factory.isCreator(newCreator));
    }

    function test__RemoveAllowlist() external {
        /* add to allowlist */
        address[] memory allowlist = new address[](1);
        allowlist[0] = users.creator_1;

        vm.prank(users.deployer);
        RouxCreatorFactory(factory).addAllowlist(allowlist);

        /* remove creator from allowlist */
        vm.prank(users.deployer);
        RouxCreatorFactory(factory).removeAllowlist(users.creator_1);

        /* attempt to create new creator */
        vm.prank(users.creator_1);
        vm.expectRevert(IRouxCreatorFactory.OnlyAllowlist.selector);
        bytes memory newParams = abi.encode(address(users.creator_1));
        factory.create(newParams);
    }
}
