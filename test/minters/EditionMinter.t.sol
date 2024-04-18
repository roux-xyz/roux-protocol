// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { RouxAdministrator } from "src/RouxAdministrator.sol";
import { IRouxAdministrator } from "src/interfaces/IRouxAdministrator.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { IEditionMinter } from "src/interfaces/IEditionMinter.sol";

import { RouxEdition } from "src/RouxEdition.sol";
import { EditionMinter } from "src/minters/EditionMinter.sol";
import { BaseTest } from "test/Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";

contract EditionMinterTest is BaseTest {
    function setUp() public virtual override {
        BaseTest.setUp();
    }

    function test__RevertWhen_InsufficientFunds() external {
        vm.expectRevert(IEditionMinter.InsufficientFunds.selector);
        editionMinter.mint{ value: 0.04 ether }(users.user_0, address(edition), 1, 1, "");
    }

    function test__RevertsWhen__MintNotStarted() external {
        // create optional sale data
        bytes memory saleData = _encodeMintParams(
            TEST_TOKEN_PRICE,
            uint40(block.timestamp) + 7 days,
            uint40(block.timestamp) + TEST_TOKEN_MINT_DURATION,
            type(uint16).max
        );

        vm.prank(users.creator_0);
        uint256 tokenId = edition.add(
            TEST_TOKEN_URI,
            users.creator_0,
            TEST_TOKEN_MAX_SUPPLY,
            users.creator_0,
            TEST_PROFIT_SHARE,
            address(0),
            0,
            address(editionMinter),
            saleData
        );

        vm.prank(users.user_0);
        vm.expectRevert(EditionMinter.MintNotStarted.selector);
        editionMinter.mint{ value: TEST_TOKEN_PRICE }(users.user_0, address(edition), tokenId, 1, "");
    }

    function test__RevertsWhen__MintEnded() external {
        vm.warp(block.timestamp + TEST_TOKEN_MINT_DURATION + 1 seconds);

        vm.prank(users.user_0);
        vm.expectRevert(EditionMinter.MintEnded.selector);
        editionMinter.mint{ value: TEST_TOKEN_PRICE }(users.user_0, address(edition), 1, 1, "");
    }

    function test__Price() external {
        assertEq(editionMinter.price(address(edition), 1), TEST_TOKEN_PRICE);
    }

    function test__Mint() external {
        editionMinter.mint{ value: TEST_TOKEN_PRICE }(users.user_0, address(edition), 1, 1, "");
        assertEq(edition.balanceOf(users.user_0, 1), 1);

        // total supply by id
        assertEq(edition.totalSupply(1), 1);
    }

    function test__Mint_Batch() external {
        editionMinter.mint{ value: 0.25 ether }(users.user_0, address(edition), 1, 5, "");
        assertEq(edition.balanceOf(users.user_0, 1), 5, "balanceOf");

        // total supply by id
        assertEq(edition.totalSupply(1), 5, "totalSupply of token");
    }

    function test__Mint_TokenWithAttribution() external {
        vm.startPrank(users.creator_1);

        /* create edition instance */
        RouxEdition edition1 = RouxEdition(factory.create(""));

        /* create forked token with attribution */
        edition1.add(
            TEST_TOKEN_URI,
            users.creator_1,
            TEST_TOKEN_MAX_SUPPLY,
            users.creator_1,
            TEST_PROFIT_SHARE,
            address(edition),
            1,
            address(editionMinter),
            optionalSaleData
        );
        vm.stopPrank();

        vm.prank(users.user_0);
        editionMinter.mint{ value: TEST_TOKEN_PRICE }(users.user_0, address(edition1), 1, 1, "");
        assertEq(edition1.balanceOf(users.user_0, 1), 1);
    }

    function test__Mint_TokenWithAttribution_DepthOf8() external {
        RouxEdition[] memory editions = _createForks(8);

        vm.prank(users.user_0);
        editionMinter.mint{ value: TEST_TOKEN_PRICE }(users.user_0, address(editions[8]), 1, 1, "");
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
        editionMinter.mint{ value: TEST_TOKEN_PRICE }(users.user_0, address(editions[MAX_FORK_DEPTH]), 1, 1, "");
        assertEq(editions[MAX_FORK_DEPTH].balanceOf(users.user_0, 1), 1);

        (address attribution, uint256 parentId) = editions[8].attribution(1);
        assertEq(attribution, address(editions[7]));
        assertEq(parentId, 1);

        (address parent, uint256 tokenId, uint256 depth) = administrator.root(address(editions[MAX_FORK_DEPTH]), 1);
        assertEq(parent, address(edition));
        assertEq(tokenId, 1);
        assertEq(depth, MAX_FORK_DEPTH);
    }
}
