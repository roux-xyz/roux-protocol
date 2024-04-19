// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { Controller } from "src/Controller.sol";
import { IController } from "src/interfaces/IController.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { IEditionMinter } from "src/interfaces/IEditionMinter.sol";

import { RouxEdition } from "src/RouxEdition.sol";
import { DefaultEditionMinter } from "src/minters/DefaultEditionMinter.sol";
import { BaseTest } from "test/Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";

contract DefaultEditionMinterTest is BaseTest {
    uint256 defaultMinterTokenId;

    function setUp() public virtual override {
        BaseTest.setUp();

        // user
        vm.startPrank(users.creator_0);

        /* add token to current edition */
        defaultMinterTokenId = edition.add(
            TEST_TOKEN_URI,
            address(users.creator_0),
            TEST_TOKEN_MAX_SUPPLY,
            address(users.creator_0),
            TEST_PROFIT_SHARE,
            address(0),
            0,
            address(defaultMinter),
            abi.encode(uint40(block.timestamp), uint40(block.timestamp + TEST_TOKEN_MINT_DURATION))
        );

        vm.stopPrank();
    }

    function test__RevertWhen_InsufficientFunds_Default() external {
        vm.expectRevert(IEditionMinter.InsufficientFunds.selector);
        defaultMinter.mint{ value: 0.0004 ether }(users.user_0, address(edition), defaultMinterTokenId, 1, "");
    }

    function test__RevertsWhen__MintNotStarted() external {
        // create optional sale data
        bytes memory saleData =
            abi.encode(uint40(block.timestamp) + 7 days, uint40(block.timestamp + TEST_TOKEN_MINT_DURATION));

        vm.prank(users.creator_0);
        uint256 tokenId = edition.add(
            TEST_TOKEN_URI,
            users.creator_0,
            TEST_TOKEN_MAX_SUPPLY,
            users.creator_0,
            TEST_PROFIT_SHARE,
            address(0),
            0,
            address(defaultMinter),
            saleData
        );

        vm.prank(users.user_0);
        vm.expectRevert(DefaultEditionMinter.MintNotStarted.selector);
        defaultMinter.mint{ value: 0.005 ether }(users.user_0, address(edition), tokenId, 1, "");
    }

    function test__RevertsWhen__MintEnded() external {
        vm.warp(block.timestamp + TEST_TOKEN_MINT_DURATION + 1 seconds);
        vm.prank(users.user_0);
        vm.expectRevert(DefaultEditionMinter.MintEnded.selector);
        defaultMinter.mint{ value: 0.005 ether }(users.user_0, address(edition), defaultMinterTokenId, 1, "");
    }

    function test__Price() external {
        assertEq(defaultMinter.price(address(edition), defaultMinterTokenId), 0.0005 ether);
    }

    function test__Mint() external {
        defaultMinter.mint{ value: 0.005 ether }(users.user_0, address(edition), defaultMinterTokenId, 1, "");
        assertEq(edition.balanceOf(users.user_0, defaultMinterTokenId), 1);

        // total supply by id
        assertEq(edition.totalSupply(defaultMinterTokenId), 2);
    }

    function test__Mint_Multiple() external {
        defaultMinter.mint{ value: 0.0025 ether }(users.user_0, address(edition), defaultMinterTokenId, 5, "");
        assertEq(edition.balanceOf(users.user_0, defaultMinterTokenId), 5, "balanceOf");

        // total supply by id
        assertEq(edition.totalSupply(defaultMinterTokenId), 6, "totalSupply of token");
    }

    function test__Mint_TokenWithAttribution() external {
        vm.startPrank(users.creator_1);

        /* create edition instance */
        bytes memory params = abi.encode(TEST_CONTRACT_URI, "");
        RouxEdition edition1 = RouxEdition(factory.create(params));

        /* create forked token with attribution */
        uint256 tokenId = edition1.add(
            TEST_TOKEN_URI,
            users.creator_1,
            TEST_TOKEN_MAX_SUPPLY,
            users.creator_1,
            TEST_PROFIT_SHARE,
            address(edition),
            1,
            address(defaultMinter),
            abi.encode(uint40(block.timestamp), uint40(block.timestamp + TEST_TOKEN_MINT_DURATION))
        );
        vm.stopPrank();

        vm.prank(users.user_0);
        defaultMinter.mint{ value: 0.005 ether }(users.user_0, address(edition1), tokenId, 1, "");
        assertEq(edition1.balanceOf(users.user_0, tokenId), 1);
    }
}
