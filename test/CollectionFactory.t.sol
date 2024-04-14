// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import { ICollectionFactory } from "src/interfaces/ICollectionFactory.sol";
import { CollectionFactory } from "src/CollectionFactory.sol";
import { BaseTest } from "./Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";

import "./Constants.t.sol";

contract CollectionFactoryTest is BaseTest {
    address[] collectionItemTargets;
    uint256[] collectionItemIds;
    bytes collectionParams;

    function setUp() public virtual override {
        BaseTest.setUp();

        /* create target array for collection */
        collectionItemTargets = new address[](1);
        collectionItemTargets[0] = address(edition);

        /* create token id array for collection */
        collectionItemIds = new uint256[](1);
        collectionItemIds[0] = 1;

        /* encode collection params */
        collectionParams = abi.encode(
            TEST_COLLECTION_NAME, TEST_COLLECTION_SYMBOL, TEST_TOKEN_URI, collectionItemTargets, collectionItemIds
        );
    }

    function test__RevertWhen_OnlyAllowlist() external {
        vm.expectRevert(ICollectionFactory.OnlyAllowlist.selector);

        vm.prank(users.user_0);
        collectionFactory.create(collectionParams);
    }

    function test__RevertWhen_OnlyOwner_AddAllowlist() external {
        vm.expectRevert(Ownable.Unauthorized.selector);

        address[] memory allowlist = new address[](1);
        allowlist[0] = users.edition_1;

        vm.prank(users.edition_0);
        CollectionFactory(collectionFactory).addAllowlist(allowlist);
    }

    function test__RevertWhen_AlreadyInitialized() external {
        /* verify current implementation */
        assertEq(collectionFactory.getImplementation(), address(collectionFactoryImpl));

        /* deploy new factory */
        vm.startPrank(users.deployer);
        CollectionFactory newFactoryImpl = new CollectionFactory(address(collectionBeacon));

        /* init data */
        bytes memory initData = abi.encodeWithSelector(collectionFactory.initialize.selector);

        /* upgrade */
        vm.expectRevert("Already initialized");
        collectionFactory.upgradeToAndCall(address(newFactoryImpl), initData);

        vm.stopPrank();
    }

    function test__Owner() external {
        assertEq(collectionFactory.owner(), address(users.deployer));
    }

    function test__TransferOwnership() external {
        vm.prank(users.deployer);
        collectionFactory.transferOwnership(users.edition_0);

        assertEq(collectionFactory.owner(), address(users.edition_0));
    }

    function test__AddAllowlist() external {
        address[] memory allowlist = new address[](1);
        allowlist[0] = users.edition_2;

        vm.prank(users.deployer);
        CollectionFactory(collectionFactory).addAllowlist(allowlist);

        vm.prank(users.edition_2);
        address newCollection = collectionFactory.create(collectionParams);

        assert(collectionFactory.isCollection(newCollection));
    }

    function test__RemoveAllowlist() external {
        /* add to allowlist */
        address[] memory allowlist = new address[](1);
        allowlist[0] = users.edition_2;

        vm.prank(users.deployer);
        CollectionFactory(collectionFactory).addAllowlist(allowlist);

        /* remove edition from allowlist */
        vm.prank(users.deployer);
        CollectionFactory(collectionFactory).removeAllowlist(users.edition_2);

        /* attempt to create new edition */
        vm.prank(users.edition_2);
        vm.expectRevert(ICollectionFactory.OnlyAllowlist.selector);
        collectionFactory.create(collectionParams);
    }

    function test__UpgradeFactory() external {
        /* verify current implementation */
        assertEq(collectionFactory.getImplementation(), address(collectionFactoryImpl));

        /* deploy new factory */
        vm.startPrank(users.deployer);
        CollectionFactory newFactoryImpl = new CollectionFactory(address(collectionBeacon));

        /* upgrade */
        collectionFactory.upgradeToAndCall(address(newFactoryImpl), "");

        vm.stopPrank();

        /* verify */
        assertEq(collectionFactory.getImplementation(), address(newFactoryImpl));
    }
}
