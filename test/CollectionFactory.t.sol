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
        collectionItemTargets[0] = address(creator);

        /* create token id array for collection */
        collectionItemIds = new uint256[](1);
        collectionItemIds[0] = 1;

        /* encode collection params */
        collectionParams = abi.encode(TEST_TOKEN_URI, collectionItemTargets, collectionItemIds);
    }

    function test__RevertWhen_OnlyAllowlist() external {
        vm.expectRevert(ICollectionFactory.OnlyAllowlist.selector);

        vm.prank(users.user_0);
        collectionFactory.create(collectionParams);
    }

    function test__RevertWhen_OnlyOwner_AddAllowlist() external {
        vm.expectRevert(Ownable.Unauthorized.selector);

        address[] memory allowlist = new address[](1);
        allowlist[0] = users.creator_1;

        vm.prank(users.creator_0);
        CollectionFactory(collectionFactory).addAllowlist(allowlist);
    }

    function test__AddAllowlist() external {
        address[] memory allowlist = new address[](1);
        allowlist[0] = users.creator_2;

        vm.prank(users.deployer);
        CollectionFactory(collectionFactory).addAllowlist(allowlist);

        vm.prank(users.creator_2);
        address newCollection = collectionFactory.create(collectionParams);

        assert(collectionFactory.isCollection(newCollection));
    }

    function test__RemoveAllowlist() external {
        /* add to allowlist */
        address[] memory allowlist = new address[](1);
        allowlist[0] = users.creator_2;

        vm.prank(users.deployer);
        CollectionFactory(collectionFactory).addAllowlist(allowlist);

        /* remove creator from allowlist */
        vm.prank(users.deployer);
        CollectionFactory(collectionFactory).removeAllowlist(users.creator_2);

        /* attempt to create new creator */
        vm.prank(users.creator_2);
        vm.expectRevert(ICollectionFactory.OnlyAllowlist.selector);
        collectionFactory.create(collectionParams);
    }
}
