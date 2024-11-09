// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { CollectionBase } from "test/shared/CollectionBase.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { IRouxEdition } from "src/core/interfaces/IRouxEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";
import { RouxEdition } from "src/core/RouxEdition.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { SingleEditionCollection } from "src/core/SingleEditionCollection.sol";
import { CollectionData } from "src/types/DataTypes.sol";
import { ERC721 } from "solady/tokens/ERC721.sol";

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
        // unset the collection in the edition contract
        vm.prank(collectionAdmin);
        edition.setCollection(address(singleEditionCollection), false);

        // attempt to mint, expecting a revert
        vm.prank(user);
        vm.expectRevert(ErrorsLib.RouxEdition_InvalidCaller.selector);
        singleEditionCollection.mint({ to: user, extension: address(0), referrer: address(0), data: "" });
    }

    /// @dev reverts when minting before mintStart
    function test__RevertWhen_MintBeforeMintStart() external {
        // set mintStart to a future timestamp
        uint40 futureMintStart = uint40(block.timestamp + 1 hours);

        // modify the collection parameters before creation
        singleEditionCollectionParams.mintStart = futureMintStart;

        // create a new collection with the updated parameters
        SingleEditionCollection collection =
            _createSingleEditionCollectionWithParams(address(edition), singleEditionCollectionIds);

        // register the collection in the edition contract
        vm.prank(collectionAdmin);
        edition.setCollection(address(collection), true);

        // attempt to mint before mintStart
        vm.prank(user);
        vm.expectRevert(ErrorsLib.Collection_MintNotStarted.selector);
        collection.mint({ to: user, extension: address(0), referrer: address(0), data: "" });
    }

    /// @dev reverts when minting after mintEnd
    function test__RevertWhen_MintAfterMintEnd() external {
        // set mintEnd to current timestamp (immediate end)
        uint40 immediateMintEnd = uint40(block.timestamp);

        // modify the collection parameters before creation
        singleEditionCollectionParams.mintStart = uint40(block.timestamp);
        singleEditionCollectionParams.mintEnd = immediateMintEnd;

        // create a new collection with the updated parameters
        SingleEditionCollection collection =
            _createSingleEditionCollectionWithParams(address(edition), singleEditionCollectionIds);

        // register the collection in the edition contract
        vm.prank(collectionAdmin);
        edition.setCollection(address(collection), true);

        // advance time by 1 second to ensure we're past mintEnd
        vm.warp(block.timestamp + 1);

        // attempt to mint after mintEnd
        vm.prank(user);
        vm.expectRevert(ErrorsLib.Collection_MintEnded.selector);
        collection.mint({ to: user, extension: address(0), referrer: address(0), data: "" });
    }

    /// @dev reverts when minting to the zero address
    function test__RevertWhen_MintToZeroAddress() external {
        vm.prank(user);
        vm.expectRevert(ERC721.TransferToZeroAddress.selector);
        singleEditionCollection.mint({ to: address(0), extension: address(0), referrer: address(0), data: "" });
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev successfully mint collection tokens to token bound account
    function test__SingleEditionCollection_Mint() external {
        // get the ERC-6551 account associated with the collection token
        address erc6551account = _getERC6551AccountSingleEdition(address(singleEditionCollection), 1);

        // expect a TransferBatch event emitted by the edition contract
        vm.expectEmit({ emitter: address(edition) });
        emit TransferBatch({
            operator: address(singleEditionCollection),
            from: address(0),
            to: erc6551account,
            ids: singleEditionCollectionIds,
            amounts: singleEditionCollectionQuantities
        });

        // mint the collection token
        vm.prank(user);
        singleEditionCollection.mint({ to: user, extension: address(0), referrer: address(0), data: "" });

        // assert ownership and balances
        assertEq(singleEditionCollection.ownerOf(1), user);
        assertEq(singleEditionCollection.totalSupply(), 1);
        assertEq(singleEditionCollection.balanceOf(user), 1);

        // assert balances of tokens in the ERC-6551 account
        for (uint256 i = 1; i <= NUM_TOKENS_SINGLE_EDITION_COLLECTION; i++) {
            assertEq(edition.balanceOf(erc6551account, i), 1);
        }

        // assert total supply of tokens in the edition contract
        for (uint256 i = 2; i <= NUM_TOKENS_SINGLE_EDITION_COLLECTION; i++) {
            // tokens were minted to edition owner on `add`
            assertEq(edition.totalSupply(i), 2);
        }
    }

    /// @dev successfully mint collection with gated token
    function test__SingleEditionCollection_Mint_WithGatedTokens() external {
        // set gate to true in addParams
        addParams.gate = true;
        RouxEdition edition_ = _createEdition(collectionAdmin);

        // add gated tokens to the edition
        vm.startPrank(collectionAdmin);
        uint256 gatedTokenId = edition_.add(addParams);
        uint256 gatedTokenId2 = edition_.add(addParams);
        vm.stopPrank();

        // create token array with proper initialization
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = gatedTokenId;
        tokenIds[1] = gatedTokenId2;

        // create collection parameters with updated itemTarget and itemIds
        CollectionData.SingleEditionCreateParams memory params = singleEditionCollectionParams;
        params.itemTarget = address(edition_);
        params.itemIds = tokenIds;

        // create collection using the updated createSingle function
        SingleEditionCollection gatedSingleEditionCollection =
            _createSingleEditionCollectionWithParams(address(edition_), tokenIds);

        // register the collection in the edition contract
        vm.prank(collectionAdmin);
        edition_.setCollection(address(gatedSingleEditionCollection), true);

        // approve and mint collection
        _approveToken(address(gatedSingleEditionCollection), user);

        vm.prank(user);
        gatedSingleEditionCollection.mint({ to: user, extension: address(0), referrer: address(0), data: "" });

        // assert ownership
        assertEq(gatedSingleEditionCollection.ownerOf(1), user);

        // get the ERC-6551 account
        address erc6551account = _getERC6551AccountSingleEdition(address(gatedSingleEditionCollection), 1);

        // assert balances in the ERC-6551 account
        assertEq(edition_.balanceOf(erc6551account, gatedTokenId), 1);
        assertEq(edition_.balanceOf(erc6551account, gatedTokenId2), 1);
    }
}
