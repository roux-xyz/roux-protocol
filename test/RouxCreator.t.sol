// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import { IRouxCreator } from "src/interfaces/IRouxCreator.sol";
import { RouxCreator } from "src/RouxCreator.sol";
import { BaseTest } from "./Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";

import "./Constants.t.sol";

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
            address(0),
            0
        );
    }

    function test__RevertWhen_OnlyOwner_UpdateUri() external {
        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(users.user_0);
        RouxCreator(address(creator)).updateUri(1, "https://new.com");
    }

    function test__RevertWhen_OnlyOwner_Withdraw() external {
        vm.startPrank(users.user_0);
        creator.mint{ value: TEST_TOKEN_PRICE }(users.user_0, 1, 1);

        vm.expectRevert(Ownable.Unauthorized.selector);
        RouxCreator(address(creator)).withdraw();
        vm.stopPrank();
    }

    function test__RevertWhen_InsufficientFunds() external {
        vm.expectRevert(IRouxCreator.InsufficientFunds.selector);
        creator.mint{ value: 0.04 ether }(users.user_0, 1, 1);
    }

    function test__RevertWhen_MaxSupplyExceeded() external {
        vm.prank(users.creator_0);
        uint256 tokenId = creator.add(
            1, TEST_TOKEN_PRICE, uint40(block.timestamp), TEST_TOKEN_MINT_DURATION, "https://test.com", address(0), 0
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
            TEST_TOKEN_MAX_SUPPLY, TEST_TOKEN_PRICE, mintStart, TEST_TOKEN_MINT_DURATION, TEST_TOKEN_URI, address(0), 0
        );

        vm.prank(users.user_0);
        vm.expectRevert(IRouxCreator.MintNotStarted.selector);
        creator.mint{ value: TEST_TOKEN_PRICE }(users.user_0, tokenId, 1);
    }

    function test__RevertsWhen__MintEnded() external {
        vm.prank(users.creator_0);
        uint256 tokenId = creator.add(
            TEST_TOKEN_MAX_SUPPLY, TEST_TOKEN_PRICE, uint40(block.timestamp), 1 days, TEST_TOKEN_URI, address(0), 0
        );

        vm.warp(block.timestamp + 1 days + 1 seconds);

        vm.prank(users.user_0);
        vm.expectRevert(IRouxCreator.MintEnded.selector);
        creator.mint{ value: TEST_TOKEN_PRICE }(users.user_0, tokenId, 1);
    }

    function test__TokenId() external {
        assertEq(creator.tokenCount(), 1);
    }

    function test__TokenId_AddToken() external {
        vm.prank(users.creator_0);
        creator.add(
            TEST_TOKEN_MAX_SUPPLY,
            TEST_TOKEN_PRICE,
            uint40(block.timestamp),
            TEST_TOKEN_MINT_DURATION,
            TEST_TOKEN_URI,
            address(0),
            0
        );
        assertEq(creator.tokenCount(), 2);
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
            "https://test.com",
            address(0),
            0
        );

        vm.prank(users.user_0);
        creator.mint{ value: TEST_TOKEN_PRICE }(users.user_0, 1, 1);
        assertEq(creator.balanceOf(users.user_0, 1), 1);
    }

    function test__AddToken_WithAttribution() external {
        vm.prank(users.creator_0);
        creator.add(
            TEST_TOKEN_MAX_SUPPLY,
            TEST_TOKEN_PRICE,
            uint40(block.timestamp),
            TEST_TOKEN_MINT_DURATION,
            "https://test.com",
            address(0),
            0
        );

        vm.startPrank(users.creator_1);

        /* create creator instance */
        RouxCreator creator1 = RouxCreator(factory.create());

        /* create forked token with attribution */
        creator1.add(
            TEST_TOKEN_MAX_SUPPLY,
            TEST_TOKEN_PRICE,
            uint40(block.timestamp),
            TEST_TOKEN_MINT_DURATION,
            "https://test.com",
            users.creator_0,
            1
        );

        (address attribution, uint256 parentId) = creator1.attribution(1);

        assertEq(attribution, users.creator_0);
        assertEq(parentId, 1);
    }

    function test__AddToken_WithAttribution_SecondaryBranch() external {
        vm.prank(users.creator_0);
        creator.add(
            TEST_TOKEN_MAX_SUPPLY,
            TEST_TOKEN_PRICE,
            uint40(block.timestamp),
            TEST_TOKEN_MINT_DURATION,
            "https://test.com",
            address(0),
            0
        );

        vm.startPrank(users.creator_1);

        /* create creator instance */
        RouxCreator creator1 = RouxCreator(factory.create());

        /* create forked token with attribution */
        uint256 tokenId = creator1.add(
            TEST_TOKEN_MAX_SUPPLY,
            TEST_TOKEN_PRICE,
            uint40(block.timestamp),
            TEST_TOKEN_MINT_DURATION,
            "https://test-forked.com",
            users.creator_0,
            1
        );

        (address attribution, uint256 parentId) = creator1.attribution(tokenId);

        assertEq(attribution, users.creator_0);
        assertEq(parentId, 1);
        assertEq(creator1.uri(1), "https://test-forked.com");

        /* create forked token from the fork with attribution */
        vm.startPrank(users.creator_0);

        uint256 tokenId2 = creator.add(
            TEST_TOKEN_MAX_SUPPLY,
            TEST_TOKEN_PRICE,
            uint40(block.timestamp),
            TEST_TOKEN_MINT_DURATION,
            "https://test-secondary-forked.com",
            address(creator1),
            1
        );

        (address attribution2, uint256 parentId2) = creator.attribution(tokenId2);

        assertEq(attribution2, address(creator1));
        assertEq(parentId2, 1);
        assertEq(creator.uri(tokenId2), "https://test-secondary-forked.com");
    }

    function test__AddMultipleTokens() external {
        vm.startPrank(users.creator_0);
        creator.add(
            TEST_TOKEN_MAX_SUPPLY,
            TEST_TOKEN_PRICE,
            uint40(block.timestamp),
            TEST_TOKEN_MINT_DURATION,
            "https://test1.com",
            address(0),
            0
        );
        creator.add(
            TEST_TOKEN_MAX_SUPPLY,
            TEST_TOKEN_PRICE,
            uint40(block.timestamp),
            TEST_TOKEN_MINT_DURATION,
            "https://test2.com",
            address(0),
            0
        );
        creator.add(
            10_000, 0.1 ether, uint40(block.timestamp), TEST_TOKEN_MINT_DURATION, "https://test3.com", address(0), 0
        );
        vm.stopPrank();

        vm.startPrank(users.user_0);
        creator.mint{ value: TEST_TOKEN_PRICE }(users.user_0, 2, 1);
        creator.mint{ value: TEST_TOKEN_PRICE }(users.user_0, 3, 1);
        creator.mint{ value: 0.1 ether }(users.user_0, 4, 1);
        vm.stopPrank();

        assertEq(creator.balanceOf(users.user_0, 4), 1);
        assertEq(creator.balanceOf(users.user_0, 3), 1);
        assertEq(creator.balanceOf(users.user_0, 4), 1);

        assertEq(creator.totalSupply(2), 1);
        assertEq(creator.totalSupply(3), 1);
        assertEq(creator.totalSupply(4), 1);

        assertEq(creator.price(2), TEST_TOKEN_PRICE);
        assertEq(creator.price(3), TEST_TOKEN_PRICE);
        assertEq(creator.price(4), 0.1 ether);

        assertEq(creator.owner(), users.creator_0);

        assertEq(creator.uri(2), "https://test1.com");
        assertEq(creator.uri(3), "https://test2.com");
        assertEq(creator.uri(4), "https://test3.com");
    }

    function test__UpdateUri() external {
        vm.prank(users.creator_0);
        RouxCreator(address(creator)).updateUri(1, "https://new.com");
        assertEq(creator.uri(1), "https://new.com");
    }

    function test__Withdraw() external {
        vm.prank(users.user_0);
        creator.mint{ value: TEST_TOKEN_PRICE }(users.user_0, 1, 1);

        uint256 creatorStartingBal = address(users.creator_0).balance;
        vm.prank(users.creator_0);
        RouxCreator(address(creator)).withdraw();
        assertEq(address(users.creator_0).balance, creatorStartingBal + TEST_TOKEN_PRICE);
    }
}
