// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { BaseTest } from "./Base.t.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { Ownable as OpenZeppelinOwnable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { Initializable } from "solady/utils/Initializable.sol";
import { Controller } from "src/Controller.sol";
import { Registry } from "src/Registry.sol";
import { RouxEditionFactory } from "src/RouxEditionFactory.sol";

contract UpgradeTest is BaseTest {
    function setUp() public virtual override {
        BaseTest.setUp();
    }

    /// @dev revert when not owner
    function test__RevertWhen_UpgradeEdition_OnlyOwner() external {
        // assert current implementation
        assertEq(editionBeacon.implementation(), address(editionImpl));

        // deploy new edition implementation with updated minter array
        IRouxEdition newEditionImpl =
            new RouxEdition(address(factory), address(collectionFactory), address(controller), address(registry));

        // revert when not owner
        vm.expectRevert(abi.encodeWithSelector(OpenZeppelinOwnable.OwnableUnauthorizedAccount.selector, user));
        vm.prank(user);
        editionBeacon.upgradeTo(address(newEditionImpl));
    }

    /// @dev revert when not owner
    function test__RevertWhen_UpgradeController_OnlyOwner() external {
        // assert current implementation
        assertEq(controller.getImplementation(), address(controllerImpl));

        // deploy new controller implementation
        Controller newControllerImpl = new Controller(address(registry), address(mockUSDC));

        vm.prank(user);
        vm.expectRevert(Ownable.Unauthorized.selector);
        controller.upgradeToAndCall(address(newControllerImpl), "");
    }

    /// @dev revert when attempting to initialize previously initialized contract
    function test__RevertWhen_UpgradeController_AttemptInitialization() external {
        // assert current implementation
        assertEq(controller.getImplementation(), address(controllerImpl));

        // deploy new controller implementation
        Controller newControllerImpl = new Controller(address(registry), address(mockUSDC));

        bytes memory initData = abi.encodeWithSelector(Controller.initialize.selector, address(registry));
        vm.prank(users.deployer);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        controller.upgradeToAndCall(address(newControllerImpl), initData);
    }

    /// @dev revert when not owner
    function test__RevertWhen_UpgradeRegistry_OnlyOwner() external {
        // assert current implementation
        assertEq(registry.getImplementation(), address(registryImpl));

        // deploy new registry implementation
        Registry newRegistryImpl = new Registry();

        vm.prank(user);
        vm.expectRevert(Ownable.Unauthorized.selector);
        registry.upgradeToAndCall(address(newRegistryImpl), "");
    }

    /// @dev revert when attempting to initialize previously initialized contract
    function test__RevertWhen_UpgradeRegistry_AttemptInitialization() external {
        // assert current implementation
        assertEq(registry.getImplementation(), address(registryImpl));

        // deploy new registry implementation
        Registry newRegistryImpl = new Registry();

        bytes memory initData = abi.encodeWithSelector(Registry.initialize.selector);
        vm.prank(users.deployer);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        registry.upgradeToAndCall(address(newRegistryImpl), initData);
    }

    /// @dev revert when not owner
    function test__RevertWhen_UpgradeRouxEditionFactory_OnlyOwner() external {
        // assert current implementation
        assertEq(factory.getImplementation(), address(factoryImpl));

        // deploy new roux edition factory implementation
        RouxEditionFactory newFactoryImpl = new RouxEditionFactory(address(editionBeacon));

        vm.prank(user);
        vm.expectRevert(Ownable.Unauthorized.selector);
        factory.upgradeToAndCall(address(newFactoryImpl), "");
    }

    /// @dev revert when attempting to initialize previously initialized contract
    function test__RevertWhen_UpgradeRouxEditionFactory_AttemptInitialization() external {
        // assert current implementation
        assertEq(factory.getImplementation(), address(factoryImpl));

        // deploy new roux edition factory implementation
        RouxEditionFactory newFactoryImpl = new RouxEditionFactory(address(editionBeacon));

        bytes memory initData = abi.encodeWithSelector(RouxEditionFactory.initialize.selector, users.deployer);
        vm.prank(users.deployer);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        factory.upgradeToAndCall(address(newFactoryImpl), initData);
    }

    /// @dev upgrade edition
    function test__UpgradeEdition() external {
        // assert current implementation
        assertEq(editionBeacon.implementation(), address(editionImpl));

        // deploy new edition implementation with updated minter array
        IRouxEdition newEditionImpl =
            new RouxEdition(address(factory), address(collectionFactory), address(controller), address(registry));

        // set new implementation in beacon
        vm.prank(users.deployer);
        editionBeacon.upgradeTo(address(newEditionImpl));

        // assert new implementation
        assertEq(editionBeacon.implementation(), address(newEditionImpl));

        // assert new implementation is not the same as the old one
        assertNotEq(address(newEditionImpl), address(editionImpl));

        // add new token
        vm.startPrank(creator);

        // create instance
        bytes memory params = abi.encode(CONTRACT_URI, "");
        address newEdition = factory.create(params);

        // add token
        RouxEdition(newEdition).add(defaultAddParams);

        // validate new token
        assertEq(RouxEdition(newEdition).totalSupply(1), 1);
    }

    /// @dev upgrade controller
    function test__UpgradeController() external {
        // assert current implementation
        assertEq(controller.getImplementation(), address(controllerImpl));

        // deploy new controller implementation
        Controller newControllerImpl = new Controller(address(registry), address(mockUSDC));

        vm.prank(users.deployer);
        controller.upgradeToAndCall(address(newControllerImpl), "");

        // assert new implementation
        assertEq(controller.getImplementation(), address(newControllerImpl));
    }

    /// @dev upgrade registry
    function test__UpgradeRegistry() external {
        // assert current implementation
        assertEq(registry.getImplementation(), address(registryImpl));

        // deploy new controller implementation
        Registry newRegistryImpl = new Registry();

        vm.prank(users.deployer);
        registry.upgradeToAndCall(address(newRegistryImpl), "");

        // assert new implementation
        assertEq(registry.getImplementation(), address(newRegistryImpl));
    }

    /// @dev upgrade edition factory
    function test__UpgradeEditionFactory() external {
        // assert current implementation
        assertEq(factory.getImplementation(), address(factoryImpl));

        // deploy new controller implementation
        RouxEditionFactory newFactoryImpl = new RouxEditionFactory(address(editionBeacon));

        vm.prank(users.deployer);
        factory.upgradeToAndCall(address(newFactoryImpl), "");

        // assert new implementation
        assertEq(factory.getImplementation(), address(newFactoryImpl));
    }
}
