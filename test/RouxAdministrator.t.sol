// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import { IRouxAdministrator } from "src/interfaces/IRouxAdministrator.sol";
import { IRouxCreator } from "src/interfaces/IRouxCreator.sol";
import { RouxCreator } from "src/RouxCreator.sol";
import { BaseTest } from "./Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";

import "./Constants.t.sol";

contract AdministratorTest is BaseTest {
    function setUp() public virtual override {
        BaseTest.setUp();
    }

    function test_RevertsWhen_Root_MaxDepthExceeded() external {
        RouxCreator[] memory creators = _createForks(MAX_FORK_DEPTH);

        /* get root */
        vm.expectRevert(IRouxAdministrator.MaxDepthExceeded.selector);

        /* attempt to add another fork */
        vm.prank(users.creator_0);
        creator.add(
            1,
            TEST_TOKEN_PRICE,
            uint40(block.timestamp),
            TEST_TOKEN_MINT_DURATION,
            TEST_TOKEN_URI,
            users.creator_0,
            address(creators[MAX_FORK_DEPTH]),
            1,
            TEST_PROFIT_SHARE
        );
    }

    function test__RevertsWhen_UpgradeToAndCall_OnlyOwner() external {
        vm.expectRevert(Ownable.Unauthorized.selector);

        /* attempt to upgrade to and call */
        vm.prank(users.creator_0);
        administrator.upgradeToAndCall(address(creator), "");
    }

    function test__Root_Depth1() external {
        vm.startPrank(users.creator_1);

        /* create creator instance */
        RouxCreator creator1 = RouxCreator(factory.create());

        /* create forked token with attribution */
        creator1.add(
            TEST_TOKEN_MAX_SUPPLY,
            TEST_TOKEN_PRICE,
            uint40(block.timestamp),
            TEST_TOKEN_MINT_DURATION,
            TEST_TOKEN_URI,
            users.creator_1,
            address(creator),
            1,
            TEST_PROFIT_SHARE
        );
        vm.stopPrank();

        /* get root */
        (address root, uint256 tokenId, uint256 depth) = administrator.root(address(creator1), 1);

        assertEq(root, address(creator));
        assertEq(tokenId, 1);
        assertEq(depth, 1);
    }

    function test__Root_Depth2() external {
        RouxCreator[] memory creators = _createForks(2);

        /* get root */
        (address root, uint256 tokenId, uint256 depth) = administrator.root(address(creators[2]), 1);

        assertEq(root, address(creator));
        assertEq(tokenId, 1);
        assertEq(depth, 2);
    }

    function test__Root_Depth_MaxDepth() external {
        RouxCreator[] memory creators = _createForks(MAX_FORK_DEPTH);

        /* get root */
        (address root, uint256 tokenId, uint256 depth) = administrator.root(address(creators[MAX_FORK_DEPTH]), 1);

        assertEq(root, address(creator));
        assertEq(tokenId, 1);
        assertEq(depth, MAX_FORK_DEPTH);
    }

    function test__Root_DepthOfN(uint256 num) external {
        uint256 n = bound(num, 1, MAX_FORK_DEPTH);
        RouxCreator[] memory creators = _createForks(n);

        /* get root */
        (address root, uint256 tokenId, uint256 depth) = administrator.root(address(creators[n]), 1);

        assertEq(root, address(creator));
        assertEq(tokenId, 1);
        assertEq(depth, n);

        /* sanity checks */
        assertEq(creators.length, n + 1); // original + n forks
        for (uint256 i = 0; i < n + 1; i++) {
            assertEq(factory.isCreator(address(creators[i])), true);
        }
    }
}
