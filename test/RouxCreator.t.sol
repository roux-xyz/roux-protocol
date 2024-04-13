// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import { RouxAdministrator } from "src/RouxAdministrator.sol";
import { IRouxCreator } from "src/interfaces/IRouxCreator.sol";
import { RouxCreator } from "src/RouxCreator.sol";
import { BaseTest } from "./Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";

import "./Constants.t.sol";

import "forge-std/console.sol";

contract CreatorTest is BaseTest {
    function setUp() public virtual override {
        BaseTest.setUp();
    }

    function test__RevertWhen_InvalidTokenId_0() external {
        vm.expectRevert(IRouxCreator.InvalidTokenId.selector);
        creator.mint{ value: TEST_TOKEN_PRICE }(users.user_0, 0, 1);
    }

    function test__RevertWhen_InvalidTokenId_2() external {
        vm.expectRevert(IRouxCreator.InvalidTokenId.selector);
        creator.mint{ value: TEST_TOKEN_PRICE }(users.user_0, 2, 1);
    }

    function test__RevertWhen_OnlyOwner_AddToken() external {
        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(users.user_0);
        creator.add(
            TEST_TOKEN_MAX_SUPPLY,
            TEST_TOKEN_PRICE,
            uint40(block.timestamp),
            TEST_TOKEN_MINT_DURATION,
            TEST_TOKEN_URI,
            users.user_0,
            address(0),
            0,
            TEST_PROFIT_SHARE
        );
    }

    function test__RevertWhen_OnlyOwner_UpdateUri() external {
        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(users.user_0);
        RouxCreator(address(creator)).updateUri(1, "https://new.com");
    }

    function test__RevertWhen_InsufficientFunds() external {
        vm.expectRevert(IRouxCreator.InsufficientFunds.selector);
        creator.mint{ value: 0.04 ether }(users.user_0, 1, 1);
    }

    function test__RevertWhen_MaxSupplyExceeded() external {
        vm.prank(users.creator_0);
        uint256 tokenId = creator.add(
            1,
            TEST_TOKEN_PRICE,
            uint40(block.timestamp),
            TEST_TOKEN_MINT_DURATION,
            TEST_TOKEN_URI,
            users.creator_0,
            address(0),
            0,
            TEST_PROFIT_SHARE
        );

        vm.prank(users.user_0);
        creator.mint{ value: TEST_TOKEN_PRICE }(users.user_0, tokenId, 1);

        vm.prank(users.user_1);
        vm.expectRevert(IRouxCreator.MaxSupplyExceeded.selector);
        creator.mint{ value: TEST_TOKEN_PRICE }(users.user_1, tokenId, 1);
    }

    function test__RevertsWhen__MintNotStarted() external {
        uint40 mintStart = uint40(block.timestamp + 7 days);

        vm.prank(users.creator_0);
        uint256 tokenId = creator.add(
            TEST_TOKEN_MAX_SUPPLY,
            TEST_TOKEN_PRICE,
            mintStart,
            TEST_TOKEN_MINT_DURATION,
            TEST_TOKEN_URI,
            users.creator_0,
            address(0),
            0,
            TEST_PROFIT_SHARE
        );

        vm.prank(users.user_0);
        vm.expectRevert(IRouxCreator.MintNotStarted.selector);
        creator.mint{ value: TEST_TOKEN_PRICE }(users.user_0, tokenId, 1);
    }

    function test__RevertsWhen__MintEnded() external {
        vm.prank(users.creator_0);
        uint256 tokenId = creator.add(
            TEST_TOKEN_MAX_SUPPLY,
            TEST_TOKEN_PRICE,
            uint40(block.timestamp),
            1 days,
            TEST_TOKEN_URI,
            users.creator_0,
            address(0),
            0,
            TEST_PROFIT_SHARE
        );

        vm.warp(block.timestamp + 1 days + 1 seconds);

        vm.prank(users.user_0);
        vm.expectRevert(IRouxCreator.MintEnded.selector);
        creator.mint{ value: TEST_TOKEN_PRICE }(users.user_0, tokenId, 1);
    }

    function test__TokenId() external {
        assertEq(creator.currentToken(), 1);
    }

    function test__TokenId_AddToken() external {
        vm.prank(users.creator_0);
        creator.add(
            TEST_TOKEN_MAX_SUPPLY,
            TEST_TOKEN_PRICE,
            uint40(block.timestamp),
            TEST_TOKEN_MINT_DURATION,
            TEST_TOKEN_URI,
            users.creator_0,
            address(0),
            0,
            TEST_PROFIT_SHARE
        );
        assertEq(creator.currentToken(), 2);
    }

    function test__Owner() external {
        assertEq(creator.owner(), users.creator_0);
    }

    function test__Creator() external {
        assertEq(creator.creator(), users.creator_0);
    }

    function test__TotalSupply() external {
        creator.mint{ value: TEST_TOKEN_PRICE }(users.user_0, 1, 1);

        assertEq(creator.totalSupply(1), 1);
    }

    function test__URI() external {
        assertEq(creator.uri(1), TEST_TOKEN_URI);
    }

    function test__Price() external {
        assertEq(creator.price(1), TEST_TOKEN_PRICE);
    }

    function test__MintToEOA() external {
        creator.mint{ value: TEST_TOKEN_PRICE }(users.user_0, 1, 1);
        assertEq(creator.balanceOf(users.user_0, 1), 1);

        // total supply by id
        assertEq(creator.totalSupply(1), 1);

        // balanceOf
        assertEq(creator.balanceOf(users.creator_0, 1), 0);
    }

    function test__MintToEOA_Batch() external {
        creator.mint{ value: 0.25 ether }(users.user_0, 1, 5);
        assertEq(creator.balanceOf(users.user_0, 1), 5, "balanceOf");

        // total supply by id
        assertEq(creator.totalSupply(1), 5, "totalSupply of token");
    }

    function test__AddToken() external {
        vm.prank(users.creator_0);
        creator.add(
            TEST_TOKEN_MAX_SUPPLY,
            TEST_TOKEN_PRICE,
            uint40(block.timestamp),
            TEST_TOKEN_MINT_DURATION,
            TEST_TOKEN_URI,
            users.creator_0,
            address(0),
            0,
            TEST_PROFIT_SHARE
        );

        vm.prank(users.user_0);
        creator.mint{ value: TEST_TOKEN_PRICE }(users.user_0, 1, 1);
        assertEq(creator.balanceOf(users.user_0, 1), 1);
    }

    function test__AddToken_WithAttribution() external {
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

        (address attribution, uint256 parentId) = creator1.attribution(1);

        assertEq(attribution, address(creator));
        assertEq(parentId, 1);

        vm.prank(users.user_0);
        creator.mint{ value: TEST_TOKEN_PRICE }(users.user_0, 1, 1);
        assertEq(creator.balanceOf(users.user_0, 1), 1);
    }

    function test__Mint_TokenWithAttribution() external {
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

        vm.prank(users.user_0);
        creator1.mint{ value: TEST_TOKEN_PRICE }(users.user_0, 1, 1);
        assertEq(creator1.balanceOf(users.user_0, 1), 1);
    }

    function test__Mint_TokenWithAttribution_DepthOf8() external {
        RouxCreator[] memory creators = _createForks(8);

        vm.prank(users.user_0);
        creators[8].mint{ value: TEST_TOKEN_PRICE }(users.user_0, 1, 1);
        assertEq(creators[8].balanceOf(users.user_0, 1), 1);

        (address attribution, uint256 parentId) = creators[8].attribution(1);
        assertEq(attribution, address(creators[7]));
        assertEq(parentId, 1);

        (address parent, uint256 tokenId, uint256 depth) = administrator.root(address(creators[8]), 1);
        assertEq(parent, address(creator));
        assertEq(tokenId, 1);
        assertEq(depth, 8);
    }

    function test__Mint_TokenWithAttribution_MaxDepth() external {
        RouxCreator[] memory creators = _createForks(MAX_FORK_DEPTH);

        vm.prank(users.user_0);
        creators[MAX_FORK_DEPTH].mint{ value: TEST_TOKEN_PRICE }(users.user_0, 1, 1);
        assertEq(creators[MAX_FORK_DEPTH].balanceOf(users.user_0, 1), 1);

        (address attribution, uint256 parentId) = creators[8].attribution(1);
        assertEq(attribution, address(creators[7]));
        assertEq(parentId, 1);

        (address parent, uint256 tokenId, uint256 depth) = administrator.root(address(creators[MAX_FORK_DEPTH]), 1);
        assertEq(parent, address(creator));
        assertEq(tokenId, 1);
        assertEq(depth, MAX_FORK_DEPTH);
    }

    function test__Withdraw_TokenWithAttribution() external {
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

        vm.prank(users.user_0);
        creator1.mint{ value: TEST_TOKEN_PRICE }(users.user_0, 1, 1);
        assertEq(creator1.balanceOf(users.user_0, 1), 1);

        /* cache balances */
        uint256 balance0 = address(users.creator_0).balance;
        uint256 balance1 = address(users.creator_1).balance;

        uint256 creator0ExpectedSplit = (TEST_TOKEN_PRICE * (10_000 - TEST_PROFIT_SHARE)) / 10_000;
        uint256 creator1ExpectedSplit = (TEST_TOKEN_PRICE * TEST_PROFIT_SHARE) / 10_000;

        vm.prank(users.creator_1);
        administrator.withdraw(address(creator1), 1);
        assertEq(address(users.creator_1).balance, balance1 + creator1ExpectedSplit);

        vm.prank(users.creator_0);
        administrator.withdraw(address(creator), 1);
        assertEq(address(users.creator_0).balance, balance0 + creator0ExpectedSplit);
    }

    function test__AddToken_WithAttribution_DepthOf3() external {
        vm.startPrank(users.creator_1);

        /* create creator instance */
        RouxCreator creator1 = RouxCreator(factory.create());

        /* create forked token with attribution */
        uint256 tokenId = creator1.add(
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

        (address attribution, uint256 parentId) = creator1.attribution(tokenId);

        assertEq(attribution, address(creator));
        assertEq(parentId, 1);

        /* create forked token from the fork with attribution */
        vm.prank(users.creator_0);

        uint256 tokenId2 = creator.add(
            TEST_TOKEN_MAX_SUPPLY,
            TEST_TOKEN_PRICE,
            uint40(block.timestamp),
            TEST_TOKEN_MINT_DURATION,
            TEST_TOKEN_URI,
            users.creator_0,
            address(creator1),
            1,
            TEST_PROFIT_SHARE
        );

        /* verify attribution */
        (address attribution2, uint256 parentId2) = creator.attribution(tokenId2);
        assertEq(attribution2, address(creator1));
        assertEq(parentId2, 1);

        /* cache starting balances */
        uint256 balance0 = address(users.creator_0).balance;
        uint256 balance1 = address(users.creator_1).balance;

        /* mint 2nd fork */
        vm.prank(users.user_0);
        creator.mint{ value: TEST_TOKEN_PRICE }(users.user_0, tokenId2, 1);
        assertEq(creator.balanceOf(users.user_0, tokenId2), 1);

        /* calculate expected splits */
        uint256 fork2CreatorSplit = (TEST_TOKEN_PRICE * TEST_PROFIT_SHARE) / 10_000;
        uint256 fork2ParentSplit = (TEST_TOKEN_PRICE * (10_000 - TEST_PROFIT_SHARE)) / 10_000;
        uint256 fork1CreatorSplit = (fork2ParentSplit * TEST_PROFIT_SHARE) / 10_000;
        uint256 fork1ParentSplit = (fork2ParentSplit * (10_000 - TEST_PROFIT_SHARE)) / 10_000;

        /* withdraw from fork2, tokenId2 */
        vm.prank(users.creator_0);
        uint256 withdrawalAmount = administrator.withdraw(address(creator), tokenId2);
        assertEq(withdrawalAmount, fork2CreatorSplit);

        /* withdraw from fork1 */
        vm.prank(users.creator_1);
        uint256 withdrawalAmount2 = administrator.withdraw(address(creator1), tokenId);
        assertEq(withdrawalAmount2, fork1CreatorSplit);

        /* withdraw from root */
        vm.prank(users.creator_0);
        uint256 withdrawalAmount3 = administrator.withdraw(address(creator), 1);
        assertEq(withdrawalAmount3, fork1ParentSplit);

        /* verify balances */
        assertEq(address(users.creator_0).balance, balance0 + fork1ParentSplit + fork2CreatorSplit);
        assertEq(address(users.creator_1).balance, balance1 + fork1CreatorSplit);
    }

    function test__UpdateUri() external {
        vm.prank(users.creator_0);
        RouxCreator(address(creator)).updateUri(1, "https://new.com");
        assertEq(creator.uri(1), "https://new.com");
    }
}
