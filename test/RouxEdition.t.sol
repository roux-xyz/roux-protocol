// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { RouxAdministrator } from "src/RouxAdministrator.sol";
import { IRouxAdministrator } from "src/interfaces/IRouxAdministrator.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { BaseTest } from "./Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";

import "./Constants.t.sol";

import "forge-std/console.sol";

contract EditionTest is BaseTest {
    function setUp() public virtual override {
        BaseTest.setUp();
    }

    function test__RevertWhen_InvalidTokenId_0() external {
        vm.expectRevert(IRouxEdition.InvalidTokenId.selector);
        edition.mint{ value: TEST_TOKEN_PRICE }(users.user_0, 0, 1);
    }

    function test__RevertWhen_InvalidTokenId_2() external {
        vm.expectRevert(IRouxEdition.InvalidTokenId.selector);
        edition.mint{ value: TEST_TOKEN_PRICE }(users.user_0, 2, 1);
    }

    function test__RevertWhen_OnlyOwner_AddToken() external {
        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(users.user_0);
        edition.add(defaultTokenSaleData, defaultAdministrationData, TEST_TOKEN_URI, users.creator_0);
    }

    function test__RevertWhen_OnlyOwner_UpdateUri() external {
        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(users.user_0);
        RouxEdition(address(edition)).updateUri(1, "https://new.com");
    }

    function test__RevertWhen_InsufficientFunds() external {
        vm.expectRevert(IRouxEdition.InsufficientFunds.selector);
        edition.mint{ value: 0.04 ether }(users.user_0, 1, 1);
    }

    function test__RevertWhen_MaxSupplyExceeded() external {
        // modifiy default token sale data
        IRouxEdition.TokenSaleData memory t = defaultTokenSaleData;
        t.maxSupply = 1;

        vm.prank(users.creator_0);
        uint256 tokenId = edition.add(t, defaultAdministrationData, TEST_TOKEN_URI, users.creator_0);

        vm.prank(users.user_0);
        edition.mint{ value: TEST_TOKEN_PRICE }(users.user_0, tokenId, 1);

        vm.prank(users.user_1);
        vm.expectRevert(IRouxEdition.MaxSupplyExceeded.selector);
        edition.mint{ value: TEST_TOKEN_PRICE }(users.user_1, tokenId, 1);
    }

    function test__RevertsWhen__MintNotStarted() external {
        // modify default token sale data
        IRouxEdition.TokenSaleData memory t = defaultTokenSaleData;
        t.mintStart = uint40(block.timestamp + 7 days);

        vm.prank(users.creator_0);
        uint256 tokenId = edition.add(t, defaultAdministrationData, TEST_TOKEN_URI, users.creator_0);

        vm.prank(users.user_0);
        vm.expectRevert(IRouxEdition.MintNotStarted.selector);
        edition.mint{ value: TEST_TOKEN_PRICE }(users.user_0, tokenId, 1);
    }

    function test__RevertsWhen__MintEnded() external {
        vm.prank(users.creator_0);
        uint256 tokenId = edition.add(defaultTokenSaleData, defaultAdministrationData, TEST_TOKEN_URI, users.creator_0);

        vm.warp(block.timestamp + TEST_TOKEN_MINT_DURATION + 1 seconds);

        vm.prank(users.user_0);
        vm.expectRevert(IRouxEdition.MintEnded.selector);
        edition.mint{ value: TEST_TOKEN_PRICE }(users.user_0, tokenId, 1);
    }

    function test__RevertsWhen_ForkPriceLowerThanParent() external {
        // modify default token sale data
        IRouxEdition.TokenSaleData memory t = defaultTokenSaleData;
        t.price = TEST_TOKEN_PRICE - 1;

        // modify default administration data
        IRouxAdministrator.AdministrationData memory a = defaultAdministrationData;
        a.parentEdition = address(edition);
        a.parentTokenId = 1;

        vm.startPrank(users.creator_1);
        RouxEdition edition1 = RouxEdition(factory.create(""));

        vm.expectRevert(IRouxEdition.InvalidPrice.selector);
        edition1.add(t, a, TEST_TOKEN_URI, users.creator_1);
    }

    function test__TokenId() external {
        assertEq(edition.currentToken(), 1);
    }

    function test__TokenId_AfterAddToken() external {
        vm.prank(users.creator_0);
        edition.add(defaultTokenSaleData, defaultAdministrationData, TEST_TOKEN_URI, users.creator_0);
        assertEq(edition.currentToken(), 2);
    }

    function test__Owner() external {
        assertEq(edition.owner(), users.creator_0);
    }

    function test__Creator() external {
        assertEq(edition.creator(1), users.creator_0);
    }

    function test__TotalSupply() external {
        edition.mint{ value: TEST_TOKEN_PRICE }(users.user_0, 1, 1);

        assertEq(edition.totalSupply(1), 1);
    }

    function test__URI() external {
        assertEq(edition.uri(1), TEST_TOKEN_URI);
    }

    function test__Price() external {
        assertEq(edition.price(1), TEST_TOKEN_PRICE);
    }

    function test__MintToEOA() external {
        edition.mint{ value: TEST_TOKEN_PRICE }(users.user_0, 1, 1);
        assertEq(edition.balanceOf(users.user_0, 1), 1);

        // total supply by id
        assertEq(edition.totalSupply(1), 1);

        // balanceOf
        assertEq(edition.balanceOf(users.creator_0, 1), 0);
    }

    function test__MintToEOA_Batch() external {
        edition.mint{ value: 0.25 ether }(users.user_0, 1, 5);
        assertEq(edition.balanceOf(users.user_0, 1), 5, "balanceOf");

        // total supply by id
        assertEq(edition.totalSupply(1), 5, "totalSupply of token");
    }

    function test__AddToken() external {
        vm.prank(users.creator_0);
        edition.add(defaultTokenSaleData, defaultAdministrationData, TEST_TOKEN_URI, users.creator_0);

        vm.prank(users.user_0);
        edition.mint{ value: TEST_TOKEN_PRICE }(users.user_0, 1, 1);
        assertEq(edition.balanceOf(users.user_0, 1), 1);
    }

    function test__AddToken_WithAttribution() external {
        // modify default administration data
        IRouxAdministrator.AdministrationData memory a = defaultAdministrationData;
        a.parentEdition = address(edition);
        a.parentTokenId = 1;

        vm.startPrank(users.creator_1);

        /* create edition instance */
        RouxEdition edition1 = RouxEdition(factory.create(""));

        /* create forked token with attribution */
        edition1.add(defaultTokenSaleData, a, TEST_TOKEN_URI, users.creator_1);
        vm.stopPrank();

        (address attribution, uint256 parentId) = edition1.attribution(1);

        assertEq(attribution, address(edition));
        assertEq(parentId, 1);

        vm.prank(users.user_0);
        edition.mint{ value: TEST_TOKEN_PRICE }(users.user_0, 1, 1);
        assertEq(edition.balanceOf(users.user_0, 1), 1);
    }

    function test__Mint_TokenWithAttribution() external {
        // modify default administration data
        IRouxAdministrator.AdministrationData memory a = defaultAdministrationData;
        a.parentEdition = address(edition);
        a.parentTokenId = 1;

        vm.startPrank(users.creator_1);

        /* create edition instance */
        RouxEdition edition1 = RouxEdition(factory.create(""));

        /* create forked token with attribution */
        edition1.add(defaultTokenSaleData, a, TEST_TOKEN_URI, users.creator_1);
        vm.stopPrank();

        vm.prank(users.user_0);
        edition1.mint{ value: TEST_TOKEN_PRICE }(users.user_0, 1, 1);
        assertEq(edition1.balanceOf(users.user_0, 1), 1);
    }

    function test__Mint_TokenWithAttribution_DepthOf8() external {
        RouxEdition[] memory editions = _createForks(8);

        vm.prank(users.user_0);
        editions[8].mint{ value: TEST_TOKEN_PRICE }(users.user_0, 1, 1);
        assertEq(editions[8].balanceOf(users.user_0, 1), 1);

        (address attribution, uint256 parentId) = editions[8].attribution(1);
        assertEq(attribution, address(editions[7]));
        assertEq(parentId, 1);

        (address parent, uint256 tokenId, uint256 depth) = administrator.root(address(editions[8]), 1);
        assertEq(parent, address(edition));
        assertEq(tokenId, 1);
        assertEq(depth, 8);
    }

    function test__Mint_TokenWithAttribution_MaxDepth() external {
        RouxEdition[] memory editions = _createForks(MAX_FORK_DEPTH);

        vm.prank(users.user_0);
        editions[MAX_FORK_DEPTH].mint{ value: TEST_TOKEN_PRICE }(users.user_0, 1, 1);
        assertEq(editions[MAX_FORK_DEPTH].balanceOf(users.user_0, 1), 1);

        (address attribution, uint256 parentId) = editions[8].attribution(1);
        assertEq(attribution, address(editions[7]));
        assertEq(parentId, 1);

        (address parent, uint256 tokenId, uint256 depth) = administrator.root(address(editions[MAX_FORK_DEPTH]), 1);
        assertEq(parent, address(edition));
        assertEq(tokenId, 1);
        assertEq(depth, MAX_FORK_DEPTH);
    }

    function test__Withdraw_TokenWithAttribution() external {
        // modify default administration data
        IRouxAdministrator.AdministrationData memory a = defaultAdministrationData;
        a.parentEdition = address(edition);
        a.parentTokenId = 1;
        a.fundsRecipient = users.creator_1;

        vm.startPrank(users.creator_1);

        /* create edition instance */
        RouxEdition edition1 = RouxEdition(factory.create(""));

        /* create forked token with attribution */
        edition1.add(defaultTokenSaleData, a, TEST_TOKEN_URI, users.creator_1);
        vm.stopPrank();

        vm.prank(users.user_0);
        edition1.mint{ value: TEST_TOKEN_PRICE }(users.user_0, 1, 1);
        assertEq(edition1.balanceOf(users.user_0, 1), 1);

        /* cache balances */
        uint256 balance0 = address(users.creator_0).balance;
        uint256 balance1 = address(users.creator_1).balance;

        uint256 edition0ExpectedSplit = (TEST_TOKEN_PRICE * (10_000 - TEST_PROFIT_SHARE)) / 10_000;
        uint256 edition1ExpectedSplit = (TEST_TOKEN_PRICE * TEST_PROFIT_SHARE) / 10_000;

        vm.prank(users.creator_1);
        administrator.withdraw(address(edition1), 1);
        assertEq(address(users.creator_1).balance, balance1 + edition1ExpectedSplit);

        vm.prank(users.creator_0);
        administrator.withdraw(address(edition), 1);
        assertEq(address(users.creator_0).balance, balance0 + edition0ExpectedSplit);
    }

    function test__AddToken_WithAttribution_DepthOf3() external {
        // modify default administration data
        IRouxAdministrator.AdministrationData memory a = defaultAdministrationData;
        a.parentEdition = address(edition);
        a.parentTokenId = 1;
        a.fundsRecipient = users.creator_1;

        vm.startPrank(users.creator_1);

        /* create new edition instance */
        RouxEdition edition1 = RouxEdition(factory.create(""));

        /* create forked token with attribution */
        uint256 tokenId = edition1.add(defaultTokenSaleData, a, TEST_TOKEN_URI, users.creator_1);
        vm.stopPrank();

        (address attribution, uint256 parentId) = edition1.attribution(tokenId);

        assertEq(attribution, address(edition));
        assertEq(parentId, 1);

        // modify default administration data again
        IRouxAdministrator.AdministrationData memory a2 = defaultAdministrationData;
        a2.parentEdition = address(edition1);
        a2.parentTokenId = 1;

        /* create forked token from the fork with attribution */
        vm.prank(users.creator_0);

        uint256 tokenId2 = edition.add(defaultTokenSaleData, a2, TEST_TOKEN_URI, users.creator_0);

        /* verify attribution */
        (address attribution2, uint256 parentId2) = edition.attribution(tokenId2);
        assertEq(attribution2, address(edition1));
        assertEq(parentId2, 1);

        /* cache starting balances */
        uint256 balance0 = address(users.creator_0).balance;
        uint256 balance1 = address(users.creator_1).balance;

        /* mint 2nd fork */
        vm.prank(users.user_0);
        edition.mint{ value: TEST_TOKEN_PRICE }(users.user_0, tokenId2, 1);
        assertEq(edition.balanceOf(users.user_0, tokenId2), 1);

        /* calculate expected splits */
        uint256 fork2CreatorSplit = (TEST_TOKEN_PRICE * TEST_PROFIT_SHARE) / 10_000;
        uint256 fork2ParentSplit = (TEST_TOKEN_PRICE * (10_000 - TEST_PROFIT_SHARE)) / 10_000;
        uint256 fork1CreatorSplit = (fork2ParentSplit * TEST_PROFIT_SHARE) / 10_000;
        uint256 fork1ParentSplit = (fork2ParentSplit * (10_000 - TEST_PROFIT_SHARE)) / 10_000;

        /* withdraw from fork2, tokenId2 */
        vm.prank(users.creator_0);
        uint256 withdrawalAmount = administrator.withdraw(address(edition), tokenId2);
        assertEq(withdrawalAmount, fork2CreatorSplit);

        /* withdraw from fork1 */
        vm.prank(users.creator_1);
        uint256 withdrawalAmount2 = administrator.withdraw(address(edition1), tokenId);
        assertEq(withdrawalAmount2, fork1CreatorSplit);

        /* withdraw from root */
        vm.prank(users.creator_0);
        uint256 withdrawalAmount3 = administrator.withdraw(address(edition), 1);
        assertEq(withdrawalAmount3, fork1ParentSplit);

        /* verify balances */
        assertEq(address(users.creator_0).balance, balance0 + fork1ParentSplit + fork2CreatorSplit);
        assertEq(address(users.creator_1).balance, balance1 + fork1CreatorSplit);
    }

    function test__UpdateUri() external {
        vm.prank(users.creator_0);
        RouxEdition(address(edition)).updateUri(1, "https://new.com");
        assertEq(edition.uri(1), "https://new.com");
    }
}
