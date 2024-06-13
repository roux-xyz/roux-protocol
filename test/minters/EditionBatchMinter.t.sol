// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { Controller } from "src/Controller.sol";
import { IController } from "src/interfaces/IController.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { IEditionMinter } from "src/interfaces/IEditionMinter.sol";

import { RouxEdition } from "src/RouxEdition.sol";
import { EditionMinter } from "src/minters/EditionMinter.sol";
import { BaseTest } from "test/Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";

contract EditionBatchMinterTest is BaseTest {
    uint256[] tokenIds;
    uint256[] quantities;
    uint256 batchId;

    function setUp() public virtual override {
        BaseTest.setUp();

        // five total
        _addMultipleTokens(4);

        // create token id array
        tokenIds = new uint256[](5);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;
        tokenIds[3] = 4;
        tokenIds[4] = 5;

        quantities = new uint256[](5);
        quantities[0] = 1;
        quantities[1] = 1;
        quantities[2] = 1;
        quantities[3] = 1;
        quantities[4] = 1;

        // encode batch id
        batchId = uint256(keccak256(abi.encode(tokenIds)));

        // encode mint params
        bytes memory options =
            abi.encode(0.2 ether, uint40(block.timestamp), uint40(block.timestamp + TEST_TOKEN_MINT_DURATION));

        // add batch minter
        vm.prank(users.creator_0);
        edition.setBatchMinter(batchId, address(editionBatchMinter), true, options);
    }

    function test__RevertWhen_InsufficientFunds() external {
        vm.expectRevert(IEditionMinter.InsufficientFunds.selector);
        editionBatchMinter.batchMint{ value: 0.19 ether }(users.user_0, address(edition), tokenIds, quantities, "");
    }

    function test__RevertWhen_MintEnded() external {
        vm.warp(block.timestamp + TEST_TOKEN_MINT_DURATION + 1 seconds);

        vm.prank(users.user_0);
        vm.expectRevert(EditionMinter.MintEnded.selector);
        editionBatchMinter.batchMint{ value: 0.2 ether }(users.user_0, address(edition), tokenIds, quantities, "");
    }

    function test__RevertsWhen_Mint() external {
        vm.expectRevert(bytes("Batch mint only"));
        editionBatchMinter.mint{ value: 0.2 ether }(users.user_0, address(edition), 1, 1, "");
    }

    function test__RevertsWhen_InvalidBatch() external {
        // create token id array
        uint256[] memory tokenIdsInvalid = new uint256[](3);
        tokenIds[0] = 3;
        tokenIds[1] = 4;

        // create quantity array
        uint256[] memory quantitiesInvalid = new uint256[](3);
        quantities[0] = 1;
        quantities[1] = 1;

        vm.prank(users.user_0);
        vm.expectRevert(IEditionMinter.MintParamsNotSet.selector);
        editionBatchMinter.batchMint{ value: 0.2 ether }(
            users.user_0, address(edition), tokenIdsInvalid, quantitiesInvalid, ""
        );
    }

    function test__Price() external {
        assertEq(editionBatchMinter.price(address(edition), batchId), 0.2 ether);
    }

    function test__BatchMint() external {
        // expect transfer to be emitted
        vm.expectEmit({ emitter: address(edition) });
        emit TransferBatch({
            operator: address(editionBatchMinter),
            from: address(0),
            to: users.user_0,
            ids: tokenIds,
            amounts: quantities
        });

        editionBatchMinter.batchMint{ value: 0.2 ether }(users.user_0, address(edition), tokenIds, quantities, "");
        assertEq(edition.balanceOf(users.user_0, 1), 1);
        assertEq(edition.balanceOf(users.user_0, 2), 1);
        assertEq(edition.balanceOf(users.user_0, 3), 1);
        assertEq(edition.balanceOf(users.user_0, 4), 1);
        assertEq(edition.balanceOf(users.user_0, 5), 1);

        // total supply by id
        assertEq(edition.totalSupply(1), 2, "Total Supply of Token 1");
        assertEq(edition.totalSupply(2), 2, "Total Supply of Token 2");
        assertEq(edition.totalSupply(3), 2, "Total Supply of Token 3");
        assertEq(edition.totalSupply(4), 2, "Total Supply of Token 4");
        assertEq(edition.totalSupply(5), 2, "Total Supply of Token 5");

        // verify controller balances
        assertEq(controller.balance(address(edition), 1), 0.04 ether);
        assertEq(controller.balance(address(edition), 2), 0.04 ether);
        assertEq(controller.balance(address(edition), 3), 0.04 ether);
        assertEq(controller.balance(address(edition), 4), 0.04 ether);
        assertEq(controller.balance(address(edition), 5), 0.04 ether);

        // verify controller batch balances
        assertEq(controller.balanceBatch(address(edition), tokenIds), 0.2 ether);
    }

    function test__CreateDifferentBatch() internal {
        // create token id array
        uint256[] memory tokenIds2 = new uint256[](3);
        tokenIds[0] = 3;
        tokenIds[1] = 4;
        tokenIds[2] = 5;

        // create quantity array
        uint256[] memory quantities2 = new uint256[](3);
        quantities[0] = 1;
        quantities[1] = 1;
        quantities[2] = 1;

        // encode batch id
        uint256 batchId2 = uint256(keccak256(abi.encode(tokenIds2)));

        // encode mint params
        bytes memory options =
            abi.encode(0.1 ether, uint40(block.timestamp), uint40(block.timestamp + TEST_TOKEN_MINT_DURATION));

        // add batch minter
        vm.prank(users.creator_0);
        edition.setBatchMinter(batchId2, address(editionBatchMinter), true, "");

        // set mint params
        vm.prank(users.creator_0);
        editionBatchMinter.setMintParams(batchId2, options);

        // expect transfer to be emitted
        vm.expectEmit({ emitter: address(edition) });
        emit TransferBatch({
            operator: address(editionBatchMinter),
            from: address(0),
            to: users.user_0,
            ids: tokenIds2,
            amounts: quantities2
        });

        editionBatchMinter.batchMint{ value: 0.25 ether }(users.user_0, address(edition), tokenIds2, quantities2, "");
        assertEq(edition.balanceOf(users.user_0, 3), 1);
        assertEq(edition.balanceOf(users.user_0, 4), 1);
        assertEq(edition.balanceOf(users.user_0, 5), 1);
        assertEq(edition.balanceOf(users.user_0, 1), 0);
        assertEq(edition.balanceOf(users.user_0, 2), 0);

        // total supply by id
        assertEq(edition.totalSupply(3), 2, "Total Supply of Token 6");
        assertEq(edition.totalSupply(4), 2, "Total Supply of Token 7");
        assertEq(edition.totalSupply(5), 2, "Total Supply of Token 8");
    }
}
