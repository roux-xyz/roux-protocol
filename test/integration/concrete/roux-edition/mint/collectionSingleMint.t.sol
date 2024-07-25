// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { CollectionBase } from "test/shared/CollectionBase.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { SingleEditionCollection } from "src/SingleEditionCollection.sol";

contract CollectionSingleMint_RouxEdition_Integration_Concrete_Test is CollectionBase {
    /* -------------------------------------------- */
    /* state                                        */
    /* -------------------------------------------- */
    EditionData.AddParams addParams;

    /* -------------------------------------------- */
    /* setup                                        */
    /* -------------------------------------------- */

    function setUp() public override {
        CollectionBase.setUp();

        addParams = defaultAddParams;
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev reverts when unregistered collection is caller
    function test__RevertWhen_InvalidCaller() external {
        // unset collection
        vm.prank(collectionAdmin);
        edition.setCollection(collectionId, address(singleEditionCollection), false);

        // attempt to mint
        vm.prank(user);
        vm.expectRevert(ErrorsLib.RouxEdition_InvalidCaller.selector);
        singleEditionCollection.mint({ to: user, extension: address(0), data: "" });
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev successfully mint collection tokens to token bound account
    function test__SingleEditionCollection_Mint() external {
        // get erc6551 account
        address erc6551account = _getERC6551AccountSingleEdition(address(singleEditionCollection), 1);

        // emit batch transfer event
        vm.expectEmit({ emitter: address(edition) });
        emit TransferBatch({
            operator: address(singleEditionCollection),
            from: address(0),
            to: erc6551account,
            ids: tokenIds,
            amounts: quantities
        });

        // mint
        vm.prank(user);
        singleEditionCollection.mint({ to: user, extension: address(0), data: "" });

        // assert owner
        assertEq(singleEditionCollection.ownerOf(1), user);

        // assert total supply
        assertEq(singleEditionCollection.totalSupply(), 1);

        // assert balance
        assertEq(singleEditionCollection.balanceOf(user), 1);

        // assert balance
        for (uint256 i = 1; i <= NUM_TOKENS_IN_COLLECTION; i++) {
            assertEq(edition.balanceOf(erc6551account, i), 1);
        }

        // assert total supply
        for (uint256 i = 2; i <= NUM_TOKENS_IN_COLLECTION; i++) {
            // tokens were minted to edition owner on `add`
            assertEq(edition.totalSupply(i), 2);
        }
    }

    /// @dev successfully mint collection with gated token
    function test__SingleEditionCollection_Mint_WithGatedTokens() external {
        // gate token
        addParams.gate = true;
        RouxEdition edition_ = _createEdition(collectionAdmin);

        vm.startPrank(collectionAdmin);
        uint256 gatedTokenId = edition_.add(addParams);
        uint256 gatedTokenId2 = edition_.add(addParams);
        vm.stopPrank();

        // create token array
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = gatedTokenId;
        tokenIds[1] = gatedTokenId2;

        // create collection
        SingleEditionCollection gatedSingleEditionCollection =
            _createSingleEditionCollectionWithParams(address(edition_), tokenIds);

        // set collection
        uint256 collectionId = _encodeCollectionId(tokenIds);

        vm.prank(collectionAdmin);
        edition_.setCollection(collectionId, address(gatedSingleEditionCollection), true);

        // approve and mint collection
        _approveToken(address(gatedSingleEditionCollection), user);

        vm.prank(user);
        gatedSingleEditionCollection.mint({ to: user, extension: address(0), data: "" });

        // assert owner
        assertEq(gatedSingleEditionCollection.ownerOf(1), user);

        // get erc6551 account
        address erc6551account = _getERC6551AccountSingleEdition(address(gatedSingleEditionCollection), 1);

        // assert balance
        assertEq(edition_.balanceOf(erc6551account, gatedTokenId), 1);
        assertEq(edition_.balanceOf(erc6551account, gatedTokenId2), 1);
    }
}
