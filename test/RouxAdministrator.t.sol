// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import { IRouxAdministrator } from "src/interfaces/IRouxAdministrator.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { BaseTest } from "./Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";

import "./Constants.t.sol";

contract AdministratorTest is BaseTest {
    function setUp() public virtual override {
        BaseTest.setUp();
    }

    function test_RevertsWhen_Root_MaxDepthExceeded() external {
        RouxEdition[] memory editions = _createForks(MAX_FORK_DEPTH);

        /* get root */
        vm.expectRevert(IRouxAdministrator.MaxDepthExceeded.selector);

        /* attempt to add another fork */
        vm.prank(users.edition_0);
        edition.add(
            1,
            TEST_TOKEN_PRICE,
            uint40(block.timestamp),
            TEST_TOKEN_MINT_DURATION,
            TEST_TOKEN_URI,
            users.edition_0,
            address(editions[MAX_FORK_DEPTH]),
            1,
            TEST_PROFIT_SHARE
        );
    }

    function test__RevertsWhen_SetAdministration_FundsRecipientIsZero() external {
        vm.prank(users.edition_0);
        vm.expectRevert(IRouxAdministrator.InvalidFundsRecipient.selector);
        edition.add(
            TEST_TOKEN_MAX_SUPPLY,
            TEST_TOKEN_PRICE,
            uint40(block.timestamp),
            TEST_TOKEN_MINT_DURATION,
            TEST_TOKEN_URI,
            address(0), // funds recipient
            address(0),
            0,
            TEST_PROFIT_SHARE
        );
    }

    function test__RevertsWhen_UpgradeToAndCall_OnlyOwner() external {
        vm.expectRevert(Ownable.Unauthorized.selector);

        /* attempt to upgrade to and call */
        vm.prank(users.edition_0);
        administrator.upgradeToAndCall(address(edition), "");
    }

    function test__Root_Depth1() external {
        vm.startPrank(users.edition_1);

        /* create edition instance */
        RouxEdition edition1 = RouxEdition(factory.create());

        /* create forked token with attribution */
        edition1.add(
            TEST_TOKEN_MAX_SUPPLY,
            TEST_TOKEN_PRICE,
            uint40(block.timestamp),
            TEST_TOKEN_MINT_DURATION,
            TEST_TOKEN_URI,
            users.edition_1,
            address(edition),
            1,
            TEST_PROFIT_SHARE
        );
        vm.stopPrank();

        /* get root */
        (address root, uint256 tokenId, uint256 depth) = administrator.root(address(edition1), 1);

        assertEq(root, address(edition));
        assertEq(tokenId, 1);
        assertEq(depth, 1);
    }

    function test__Root_Depth2() external {
        RouxEdition[] memory editions = _createForks(2);

        /* get root */
        (address root, uint256 tokenId, uint256 depth) = administrator.root(address(editions[2]), 1);

        assertEq(root, address(edition));
        assertEq(tokenId, 1);
        assertEq(depth, 2);
    }

    function test__Root_Depth_MaxDepth() external {
        RouxEdition[] memory editions = _createForks(MAX_FORK_DEPTH);

        /* get root */
        (address root, uint256 tokenId, uint256 depth) = administrator.root(address(editions[MAX_FORK_DEPTH]), 1);

        assertEq(root, address(edition));
        assertEq(tokenId, 1);
        assertEq(depth, MAX_FORK_DEPTH);
    }

    function test__Root_DepthOfN(uint256 num) external {
        uint256 n = bound(num, 1, MAX_FORK_DEPTH);
        RouxEdition[] memory editions = _createForks(n);

        /* get root */
        (address root, uint256 tokenId, uint256 depth) = administrator.root(address(editions[n]), 1);

        assertEq(root, address(edition));
        assertEq(tokenId, 1);
        assertEq(depth, n);

        /* sanity checks */
        assertEq(editions.length, n + 1); // original + n forks
        for (uint256 i = 0; i < n + 1; i++) {
            assertEq(factory.isCreator(address(editions[i])), true);
        }
    }
}
