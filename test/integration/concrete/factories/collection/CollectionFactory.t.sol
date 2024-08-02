// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { CollectionBase } from "test/shared/CollectionBase.t.sol";
import { ICollectionFactory } from "src/interfaces/ICollectionFactory.sol";
import { ICollection } from "src/interfaces/ICollection.sol";
import { CollectionFactory } from "src/CollectionFactory.sol";
import { SingleEditionCollection } from "src/SingleEditionCollection.sol";
import { MultiEditionCollection } from "src/MultiEditionCollection.sol";
import { Initializable } from "solady/utils/Initializable.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { CollectionData } from "src/types/DataTypes.sol";

contract CollectionFactoryTest is CollectionBase {
    function setUp() public virtual override {
        CollectionBase.setUp();
    }

    /// @dev only allowlist
    function test__RevertWhen_OnlyAllowlist() external {
        vm.startPrank(users.deployer);
        collectionFactory.setAllowlist(true);
        vm.stopPrank();

        vm.prank(user);
        vm.expectRevert(ErrorsLib.CollectionFactory_OnlyAllowlist.selector);
        collectionFactory.create(CollectionData.CollectionType.SingleEdition, abi.encode(singleEditionCollectionParams));
    }

    /// @dev only owner can add allowlist
    function test__RevertWhen_OnlyOwner_AddAllowlist() external {
        address[] memory allowlist = new address[](1);
        allowlist[0] = users.creator_1;

        vm.prank(creator);
        vm.expectRevert(Ownable.Unauthorized.selector);
        collectionFactory.addAllowlist(allowlist);
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

    /// @dev disable allowlist
    function test__DisableAllowlist() external {
        vm.startPrank(users.deployer);
        collectionFactory.setAllowlist(true);
        collectionFactory.setAllowlist(false);
        vm.stopPrank();

        vm.prank(user);
        address newCollection = collectionFactory.create(
            CollectionData.CollectionType.SingleEdition, abi.encode(singleEditionCollectionParams)
        );

        assertEq(collectionFactory.isCollection(newCollection), true);
    }

    /// @dev transfer ownership
    function test__TransferOwnership() external {
        vm.prank(users.deployer);
        collectionFactory.transferOwnership(creator);

        assertEq(collectionFactory.owner(), address(creator));
    }

    /// @dev add allowlist
    function test__AddAllowlist() external {
        address[] memory allowlist = new address[](1);
        allowlist[0] = users.creator_2;

        vm.startPrank(users.deployer);
        collectionFactory.setAllowlist(true);
        collectionFactory.addAllowlist(allowlist);
        vm.stopPrank();

        vm.prank(users.creator_2);
        address newCollection = collectionFactory.create(
            CollectionData.CollectionType.SingleEdition, abi.encode(singleEditionCollectionParams)
        );

        assertEq(collectionFactory.isCollection(newCollection), true);
    }

    /// @dev remove allowlist
    function test__RemoveAllowlist() external {
        address[] memory allowlist = new address[](1);
        allowlist[0] = users.creator_2;

        vm.startPrank(users.deployer);
        collectionFactory.setAllowlist(true);
        collectionFactory.addAllowlist(allowlist);
        collectionFactory.removeAllowlist(users.creator_2);
        vm.stopPrank();

        vm.prank(users.creator_2);
        vm.expectRevert(ErrorsLib.CollectionFactory_OnlyAllowlist.selector);
        collectionFactory.create(CollectionData.CollectionType.SingleEdition, abi.encode(singleEditionCollectionParams));
    }

    /// @dev create single edition collection
    function test__CreateSingleEditionCollection() external {
        vm.prank(collectionAdmin);
        address newCollection = collectionFactory.create(
            CollectionData.CollectionType.SingleEdition, abi.encode(singleEditionCollectionParams)
        );

        assertEq(collectionFactory.isCollection(newCollection), true);
        assertTrue(SingleEditionCollection(newCollection).supportsInterface(type(ICollection).interfaceId));
    }

    /// @dev create multi edition collection
    function test__CreateMultiEditionCollection() external {
        vm.prank(curator);
        address newCollection = collectionFactory.create(
            CollectionData.CollectionType.MultiEdition, abi.encode(multiEditionCollectionParams)
        );

        assertEq(collectionFactory.isCollection(newCollection), true);
        assertTrue(MultiEditionCollection(newCollection).supportsInterface(type(ICollection).interfaceId));
    }

    /// @dev is collection true
    function test__IsCollection_True() external {
        vm.prank(collectionAdmin);
        address newCollection = collectionFactory.create(
            CollectionData.CollectionType.SingleEdition, abi.encode(singleEditionCollectionParams)
        );

        assertEq(collectionFactory.isCollection(newCollection), true);
    }

    /// @dev is collection false
    function test__IsCollection_False() external {
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
}
