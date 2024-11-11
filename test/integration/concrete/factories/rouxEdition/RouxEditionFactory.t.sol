// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { BaseTest } from "test/Base.t.sol";
import { IRouxEditionFactory } from "src/core/interfaces/IRouxEditionFactory.sol";
import { IRouxEdition } from "src/core/interfaces/IRouxEdition.sol";
import { RouxEdition } from "src/core/RouxEdition.sol";
import { RouxEditionFactory } from "src/core/RouxEditionFactory.sol";
import { Initializable } from "solady/utils/Initializable.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

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

    /// @dev test create deterministic
    function test__CreateDeterministic() external {
        bytes memory params = abi.encode(CONTRACT_URI);

        // calculate expected address for first deployment
        uint256 nonce = 0;
        bytes32 salt = keccak256(abi.encodePacked(users.creator_1, nonce));
        bytes memory initData = abi.encodeWithSignature("initialize(bytes)", params);
        bytes memory proxyBytecode =
            abi.encodePacked(type(BeaconProxy).creationCode, abi.encode(address(editionBeacon), initData));

        address expectedAddress = Create2.computeAddress(salt, keccak256(proxyBytecode), address(factory));

        // deploy first edition
        vm.prank(users.creator_1);
        address actualAddress = factory.create(params);

        // verify address matches prediction
        assertEq(actualAddress, expectedAddress);

        // verify second deployment with same parameters but different nonce produces different address
        vm.prank(users.creator_1);
        address secondAddress = factory.create(params);
        assertTrue(secondAddress != actualAddress);
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

    /// @dev total editions
    function test__TotalEditions() external {
        assertEq(factory.totalEditions(), 1);

        address[] memory editions = new address[](3);
        bytes memory params = abi.encode(CONTRACT_URI);

        vm.prank(creator);
        editions[0] = factory.create(params);

        vm.prank(users.creator_1);
        editions[1] = factory.create(params);

        vm.prank(users.creator_2);
        editions[2] = factory.create(params);

        assertEq(factory.totalEditions(), 4);
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
