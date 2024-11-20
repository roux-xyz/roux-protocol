// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { CollectionBase } from "test/shared/CollectionBase.t.sol";
import { ICollectionFactory } from "src/core/interfaces/ICollectionFactory.sol";
import { ICollection } from "src/core/interfaces/ICollection.sol";
import { CollectionFactory } from "src/core/CollectionFactory.sol";
import { SingleEditionCollection } from "src/core/SingleEditionCollection.sol";
import { MultiEditionCollection } from "src/core/MultiEditionCollection.sol";
import { Initializable } from "solady/utils/Initializable.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { CollectionData } from "src/types/DataTypes.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

contract CollectionFactoryTest is CollectionBase {
    function setUp() public virtual override {
        CollectionBase.setUp();
    }

    /// @dev already initialized
    function test__RevertWhen_AlreadyInitialized() external {
        assertEq(collectionFactory.getImplementation(), address(collectionFactoryImpl));

        vm.startPrank(users.deployer);
        CollectionFactory newCollectionFactoryImpl =
            new CollectionFactory(address(singleEditionCollectionBeacon), address(multiEditionCollectionBeacon));

        bytes memory initData = abi.encodeWithSelector(collectionFactory.initialize.selector);

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        collectionFactory.upgradeToAndCall(address(newCollectionFactoryImpl), initData);

        vm.stopPrank();
    }

    /// @dev owner
    function test__Owner() external view {
        assertEq(collectionFactory.owner(), address(users.deployer));
    }

    /// @dev test create single deterministic
    function test__CreateSingleDeterministic() external {
        // calculate expected address for first deployment
        uint256 nonce = 0;
        bytes32 salt = keccak256(abi.encodePacked(users.creator_1, nonce));
        bytes memory initData =
            abi.encodeWithSelector(SingleEditionCollection.initialize.selector, singleEditionCollectionParams);
        bytes memory proxyBytecode = abi.encodePacked(
            type(BeaconProxy).creationCode, abi.encode(address(singleEditionCollectionBeacon), initData)
        );

        address expectedAddress = Create2.computeAddress(salt, keccak256(proxyBytecode), address(collectionFactory));

        // deploy first collection
        vm.prank(users.creator_1);
        address actualAddress = collectionFactory.createSingle(singleEditionCollectionParams);

        // verify address matches prediction
        assertEq(actualAddress, expectedAddress);

        // verify second deployment with same parameters but different nonce produces different address
        vm.prank(users.creator_1);
        address secondAddress = collectionFactory.createSingle(singleEditionCollectionParams);
        assertTrue(secondAddress != actualAddress);
    }

    /// @dev test create multi deterministic
    function test__CreateMultiDeterministic() external {
        // calculate expected address for first deployment
        uint256 nonce = 0;
        bytes32 salt = keccak256(abi.encodePacked(users.creator_1, nonce));
        bytes memory initData =
            abi.encodeWithSelector(MultiEditionCollection.initialize.selector, multiEditionCollectionParams);
        bytes memory proxyBytecode = abi.encodePacked(
            type(BeaconProxy).creationCode, abi.encode(address(multiEditionCollectionBeacon), initData)
        );

        address expectedAddress = Create2.computeAddress(salt, keccak256(proxyBytecode), address(collectionFactory));

        // deploy first collection
        vm.prank(users.creator_1);
        address actualAddress = collectionFactory.createMulti(multiEditionCollectionParams);

        // verify address matches prediction
        assertEq(actualAddress, expectedAddress);

        // verify second deployment with same parameters but different nonce produces different address
        vm.prank(users.creator_1);
        address secondAddress = collectionFactory.createMulti(multiEditionCollectionParams);
        assertTrue(secondAddress != actualAddress);
    }

    /// @dev transfer ownership
    function test__TransferOwnership() external {
        vm.prank(users.deployer);
        collectionFactory.transferOwnership(creator);

        assertEq(collectionFactory.owner(), address(creator));
    }

    /// @dev create single edition collection
    function test__CreateSingleEditionCollection() external {
        vm.prank(collectionAdmin);
        address newCollection = collectionFactory.createSingle(singleEditionCollectionParams);

        assertEq(collectionFactory.isCollection(newCollection), true);
        assertTrue(SingleEditionCollection(newCollection).supportsInterface(type(ICollection).interfaceId));
    }

    /// @dev create multi edition collection
    function test__CreateMultiEditionCollection() external {
        vm.prank(curator);
        address newCollection = collectionFactory.createMulti(multiEditionCollectionParams);

        assertEq(collectionFactory.isCollection(newCollection), true);
        assertTrue(MultiEditionCollection(newCollection).supportsInterface(type(ICollection).interfaceId));
    }

    /// @dev is collection true
    function test__IsCollection_True() external {
        vm.prank(collectionAdmin);
        address newCollection = collectionFactory.createSingle(singleEditionCollectionParams);

        assertEq(collectionFactory.isCollection(newCollection), true);
    }

    /// @dev is collection false
    function test__IsCollection_False() external view {
        assertFalse(collectionFactory.isCollection(address(creator)));
    }

    /// @dev upgrade factory
    function test__UpgradeFactory() external {
        assertEq(collectionFactory.getImplementation(), address(collectionFactoryImpl));

        vm.startPrank(users.deployer);
        CollectionFactory newCollectionFactoryImpl =
            new CollectionFactory(address(singleEditionCollectionBeacon), address(multiEditionCollectionBeacon));

        collectionFactory.upgradeToAndCall(address(newCollectionFactoryImpl), "");

        vm.stopPrank();

        assertEq(collectionFactory.getImplementation(), address(newCollectionFactoryImpl));
    }

    /// @dev total collections
    function test__TotalCollections() external {
        uint256 initialTotal = 3;
        assertEq(collectionFactory.totalCollections(), initialTotal);

        address[] memory collections = new address[](3);

        vm.prank(collectionAdmin);
        collections[0] = collectionFactory.createSingle(singleEditionCollectionParams);

        vm.prank(curator);
        collections[1] = collectionFactory.createMulti(multiEditionCollectionParams);

        vm.prank(curator);
        collections[2] = collectionFactory.createMulti(multiEditionCollectionParams);

        assertEq(collectionFactory.totalCollections(), initialTotal + 3);
    }
}
