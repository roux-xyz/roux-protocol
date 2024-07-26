// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { CollectionBase } from "test/shared/CollectionBase.t.sol";
import { SingleEditionCollection } from "src/SingleEditionCollection.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { CollectionData, EditionData } from "src/types/DataTypes.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";

contract Mint_SingleEditionCollection_Integration_Concrete_Test is CollectionBase {
    /* -------------------------------------------- */
    /* setup                                        */
    /* -------------------------------------------- */

    function setUp() public virtual override {
        CollectionBase.setUp();
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev successfully mints collection
    function test__Mint_SingleEditionCollection() external {
        // cache starting user balance
        uint256 startingUserBalance = mockUSDC.balanceOf(user);
        uint256 startingControllerBalance = _getUserControllerBalance(collectionAdmin);

        // get erc6551 account
        address erc6551account = _getERC6551AccountSingleEdition(address(singleEditionCollection), 1);

        // emit erc721 transfer event
        vm.expectEmit({ emitter: address(singleEditionCollection) });
        emit Transfer({ from: address(0), to: user, tokenId: 1 });

        // emit batch transfer event
        vm.expectEmit({ emitter: address(edition) });
        emit TransferBatch({
            operator: address(singleEditionCollection),
            from: address(0),
            to: erc6551account,
            ids: singleEditionCollectionIds,
            amounts: singleEditionCollectionQuantities
        });

        // mint
        vm.prank(user);
        singleEditionCollection.mint({ to: user, extension: address(0), referrer: address(0), data: "" });

        // assert owner
        assertEq(singleEditionCollection.ownerOf(1), user);

        // assert total supply
        assertEq(singleEditionCollection.totalSupply(), 1);

        // assert balance
        assertEq(singleEditionCollection.balanceOf(user), 1);

        // assert balance - tba
        for (uint256 i = 1; i <= NUM_TOKENS_IN_COLLECTION; i++) {
            assertEq(edition.balanceOf(erc6551account, i), 1);
        }

        // assert total supply - edition
        for (uint256 i = 2; i <= NUM_TOKENS_IN_COLLECTION; i++) {
            // tokens were minted to edition owner on `add`
            assertEq(edition.totalSupply(i), 2);
        }

        // verify user balance
        assertEq(mockUSDC.balanceOf(user), startingUserBalance - SINGLE_EDITION_COLLECTION_PRICE);
        assertEq(
            _getUserControllerBalance(collectionAdmin), startingControllerBalance + SINGLE_EDITION_COLLECTION_PRICE
        );
    }
}
