// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { BaseTest } from "test/Base.t.sol";
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

    /// @dev already initialized
    function test__RevertWhen_AlreadyInitialized() external {
        assertEq(factory.getImplementation(), address(factoryImpl));

        vm.startPrank(users.deployer);
        RouxEditionFactory newFactoryImpl = new RouxEditionFactory(address(editionBeacon));

        bytes memory initData = abi.encodeWithSelector(factory.initialize.selector, users.deployer);

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        factory.upgradeToAndCall(address(newFactoryImpl), initData);

        vm.stopPrank();
    }

    /// @dev owner
    function test__Owner() external view {
        assertEq(factory.owner(), address(users.deployer));
    }

    /// @dev transfer ownership
    function test__TransferOwnership() external {
        vm.prank(users.deployer);
        factory.transferOwnership(creator);

        assertEq(factory.owner(), address(creator));
    }

    /// @dev create
    function test__Create() external {
        vm.prank(creator);

        bytes memory params = abi.encode(CONTRACT_URI);
        address newEdition = factory.create(params);

        assertEq(factory.isEdition(newEdition), true);
    }

    /// @dev is edition true
    function test__IsEdition_True() external {
        vm.prank(creator);
        bytes memory params = abi.encode(CONTRACT_URI);
        address newEdition = factory.create(params);

        assertEq(factory.isEdition(newEdition), true);
    }

    /// @dev is edition false
    function test__IsEdition_False() external view {
        assertFalse(factory.isEdition(address(creator)));
    }

    /// @dev get editions
    function test__getEditions() external {
        address[] memory editions = new address[](3);
        bytes memory params = abi.encode(CONTRACT_URI);

        vm.prank(creator);
        editions[0] = factory.create(params);

        vm.prank(users.creator_1);
        editions[1] = factory.create(params);

        vm.prank(users.creator_2);
        editions[2] = factory.create(params);

        for (uint256 i = 0; i < 3; i++) {
            assertEq(factory.isEdition(editions[i]), true);
        }
    }

    /// @dev upgrade factory
    function test__UpgradeFactory() external {
        assertEq(factory.getImplementation(), address(factoryImpl));

        vm.startPrank(users.deployer);
        RouxEditionFactory newFactoryImpl = new RouxEditionFactory(address(editionBeacon));

        factory.upgradeToAndCall(address(newFactoryImpl), "");

        vm.stopPrank();

        assertEq(factory.getImplementation(), address(newFactoryImpl));
    }
}
