// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import { IRouxCreator } from "src/interfaces/IRouxCreator.sol";
import { RouxCreator } from "src/RouxCreator.sol";
import { BaseTest } from "./Base.t.sol";

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
        vm.expectRevert(IRouxCreator.OnlyOwner.selector);
        vm.prank(users.user_0);
        creator.add(TEST_TOKEN_MAX_SUPPLY, TEST_TOKEN_PRICE, TEST_TOKEN_URI);
    }

    function test__RevertWhen_OnlyOwner_UpdateUri() external {
        vm.expectRevert(IRouxCreator.OnlyOwner.selector);
        vm.prank(users.user_0);
        RouxCreator(address(creator)).updateUri(1, "https://new.com");
    }

    function test__RevertWhen_OnlyOwner_Withdraw() external {
        vm.startPrank(users.user_0);
        creator.mint{ value: TEST_TOKEN_PRICE }(users.user_0, 1, 1);

        vm.expectRevert(IRouxCreator.OnlyOwner.selector);
        RouxCreator(address(creator)).withdraw();
        vm.stopPrank();
    }

    function test__RevertWhen_InsufficientFunds() external {
        vm.expectRevert(IRouxCreator.InsufficientFunds.selector);
        creator.mint{ value: 0.04 ether }(users.user_0, 1, 1);
    }

    function test__RevertWhen_MaxSupplyExceeded() external {
        vm.prank(users.creator_0);
        uint256 tokenId = creator.add(1, TEST_TOKEN_PRICE, "https://test.com");

        vm.prank(users.user_0);
        creator.mint{ value: TEST_TOKEN_PRICE }(users.user_0, tokenId, 1);

        vm.prank(users.user_1);
        vm.expectRevert(IRouxCreator.MaxSupplyExceeded.selector);
        creator.mint{ value: TEST_TOKEN_PRICE }(users.user_1, tokenId, 1);
    }

    function test__TokenId() external {
        assertEq(creator.tokenCount(), 1);
    }

    function test__TokenId_AddToken() external {
        vm.prank(users.creator_0);
        creator.add(TEST_TOKEN_MAX_SUPPLY, TEST_TOKEN_PRICE, TEST_TOKEN_URI);
        assertEq(creator.tokenCount(), 2);
    }

    function test__Owner() external {
        assertEq(creator.owner(), users.creator_0);
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
        creator.add(TEST_TOKEN_MAX_SUPPLY, TEST_TOKEN_PRICE, "https://test.com");

        vm.prank(users.user_0);
        creator.mint{ value: TEST_TOKEN_PRICE }(users.user_0, 1, 1);
        assertEq(creator.balanceOf(users.user_0, 1), 1);
    }

    function test__AddToken_WithAttribution() external {
        vm.prank(users.creator_0);
        creator.add(TEST_TOKEN_MAX_SUPPLY, TEST_TOKEN_PRICE, "https://test.com");

        vm.startPrank(users.creator_1);

        /* encode params */
        bytes memory rouxCreatorParams = abi.encode(address(users.creator_1));

        /* create creator instance */
        RouxCreator creator1 = RouxCreator(factory.create(rouxCreatorParams));

        /* create forked token with attribution */
        creator1.add(TEST_TOKEN_MAX_SUPPLY, TEST_TOKEN_PRICE, "https://test.com", users.creator_0, 1);

        (address attribution, uint96 parentId) = creator1.attribution(1);

        assertEq(attribution, users.creator_0);
        assertEq(parentId, 1);
    }

    function test__AddMultipleTokens() external {
        vm.startPrank(users.creator_0);
        creator.add(TEST_TOKEN_MAX_SUPPLY, TEST_TOKEN_PRICE, "https://test1.com");
        creator.add(TEST_TOKEN_MAX_SUPPLY, TEST_TOKEN_PRICE, "https://test2.com");
        creator.add(10_000, 0.1 ether, "https://test3.com");
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
