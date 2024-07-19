// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { BaseTest } from "./Base.t.sol";

import { ERC6551Account } from "src/ERC6551Account.sol";
import { ICollection } from "src/interfaces/ICollection.sol";
import { SingleEditionCollection } from "src/SingleEditionCollection.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { Ownable } from "solady/auth/Ownable.sol";

import { CollectionData } from "src/types/DataTypes.sol";

contract SingleEditionCollectionTest is BaseTest {
    uint256[] tokenIds;
    uint256[] quantities;
    uint256 collectionId;
    SingleEditionCollection collection;

    // set test single edition collection minter
    address testMinter;

    function setUp() public virtual override {
        BaseTest.setUp();

        // create collection
        (tokenIds, quantities, collection) = _createSingleEditionCollection(edition, 5);

        // set collection
        vm.prank(users.creator_0);
        edition.setCollection(tokenIds, address(collection), true);

        // set test single edition collection minter
        testMinter = address(users.user_0);

        // approve single edition collection to spend mock usdc
        _approveToken(address(collection), testMinter);
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    function test__RevertWhen_NonOwnerUpdateMintParams() external {
        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(users.user_0);
        collection.updateMintParams("");
    }

    function test__RevertWhen_InvalidItemTarget() external {
        address invalidItemTarget = address(0x123);
        uint256[] memory invalidItemIds = new uint256[](1);
        invalidItemIds[0] = 1;

        vm.expectRevert(ICollection.InvalidItems.selector);
        _createCollectionWithParams(invalidItemTarget, invalidItemIds);
    }

    function test__RevertWhen_InvalidItemId_Zero() external {
        uint256[] memory invalidItemIds = new uint256[](1);
        invalidItemIds[0] = 0;

        vm.expectRevert(ICollection.InvalidItems.selector);
        _createCollectionWithParams(address(edition), invalidItemIds);
    }

    function test__RevertWhen_InvalidItemId_NonExistent() external {
        uint256[] memory invalidItemIds = new uint256[](1);
        invalidItemIds[0] = 999;

        vm.expectRevert(ICollection.InvalidItems.selector);
        _createCollectionWithParams(address(edition), invalidItemIds);
    }

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    function test__Name() external {
        assertEq(collection.name(), COLLECTION_NAME, "collection name");
    }

    function test__Symbol() external {
        assertEq(collection.symbol(), COLLECTION_SYMBOL, "collection symbol");
    }

    function test__Owner() external {
        assertEq(collection.owner(), address(users.creator_0), "collection owner");
    }

    function test__Curator() external {
        assertEq(collection.curator(), address(users.creator_0), "collection curator");
    }

    function test__CollectionPrice() external {
        uint256 collectionPrice = collection.price();
        assertEq(collectionPrice, SINGLE_EDITION_COLLECTION_PRICE, "collection price");
    }

    function test__TokenURI() external {
        assertEq(ERC721(address(collection)).tokenURI(1), COLLECTION_URI, "collection tokenURI");
    }

    function test__Collection() external {
        (address[] memory itemTargets, uint256[] memory itemIds) = collection.collection();
        assertEq(itemTargets.length, 1, "Item targets length");
        assertEq(itemTargets[0], address(edition), "Item target");
        assertEq(itemIds.length, tokenIds.length, "Item IDs length");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            assertEq(itemIds[i], tokenIds[i], "Item ID");
        }
    }

    function test__TotalSupply() external {
        assertEq(collection.totalSupply(), 0, "Initial total supply");

        vm.prank(users.user_0);
        collection.mint(users.user_0, address(0), "");

        assertEq(collection.totalSupply(), 1, "Total supply after mint");
    }

    function test__Exists() external {
        assertFalse(collection.exists(1), "Token should not exist initially");

        vm.prank(users.user_0);
        collection.mint(users.user_0, address(0), "");

        assertTrue(collection.exists(1), "Token should exist after mint");
        assertFalse(collection.exists(2), "Non-existent token should not exist");
    }

    function test__SupportsInterface() external {
        assertTrue(collection.supportsInterface(type(ICollection).interfaceId), "Should support ICollection interface");
        assertTrue(collection.supportsInterface(type(IERC721).interfaceId), "Should support IERC721 interface");
        assertFalse(collection.supportsInterface(bytes4(0xffffffff)), "Should not support random interface");
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    function test__MintCollectionAndTransfer() external {
        vm.prank(users.user_0);
        collection.mint(users.user_0, address(0), "");
        assertEq(collection.ownerOf(1), users.user_0);

        assertEq(collection.balanceOf(users.user_0), 1, "collection balanceOf");

        vm.prank(users.user_0);
        collection.transferFrom(users.user_0, users.user_1, 1);

        assertEq(collection.ownerOf(1), users.user_1, "collection ownerOf");
        assertEq(collection.balanceOf(users.user_0), 0, "collection balanceOf user_0");
    }

    function test__MintMultipleTokens() external {
        vm.startPrank(users.user_0);
        collection.mint(users.user_1, address(0), "");
        collection.mint(users.user_2, address(0), "");
        vm.stopPrank();

        assertEq(collection.ownerOf(1), users.user_1, "User 1 should own first token");
        assertEq(collection.ownerOf(2), users.user_2, "User 2 should own second token");
    }

    function test__MintAndVerifyERC6551Account() external {
        vm.prank(users.user_0);
        collection.mint(users.user_1, address(0), "");

        address expectedERC6551Account = erc6551Registry.account(
            address(accountImpl), keccak256("ROUX_SINGLE_EDITION_COLLECTION"), block.chainid, address(collection), 1
        );

        for (uint256 i = 0; i < tokenIds.length; i++) {
            assertEq(edition.balanceOf(expectedERC6551Account, tokenIds[i]), 1, "ERC6551 account should own token ");
        }
    }

    function test__MintCollection_AndTransferToken() external {
        // get expected erc6551 account
        address erc6551account = erc6551Registry.account(
            address(accountImpl), keccak256("ROUX_SINGLE_EDITION_COLLECTION"), block.chainid, address(collection), 1
        );

        vm.prank(users.user_0);
        collection.mint(users.user_0, address(0), "");

        assertEq(collection.balanceOf(users.user_0), 1, "collection balanceOf");
        assertEq(collection.ownerOf(1), users.user_0, "collection ownerOf");

        assertEq(edition.balanceOf(erc6551account, 1), 1, "1155 balanceOf prior to transfer");

        bytes memory data = abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256,uint256,bytes)", erc6551account, users.user_1, 1, 1, ""
        );

        vm.prank(users.user_0);
        ERC6551Account(payable(erc6551account)).execute(address(edition), 0, data, ERC6551Account.Operation.Call);

        assertEq(edition.balanceOf(erc6551account, 1), 0, "1155 balanceOf account post transfer");
        assertEq(edition.balanceOf(users.user_1, 1), 1, "1155 balanceOf id post transfer");
    }

    function test__UpdateMintParams() external {
        bytes memory newMintParams = abi.encode(0.3 ether, uint40(block.timestamp), uint40(block.timestamp + 2 days));

        vm.prank(users.creator_0);
        collection.updateMintParams(newMintParams);

        assertEq(collection.price(), 0.3 ether, "Updated collection price");
    }

    function test__ValidateItems_Success() external {
        // This test verifies that creation succeeds with valid parameters
        (uint256[] memory validItemIds,,) = _createSingleEditionCollection(edition, 1);

        (address[] memory itemTargets, uint256[] memory itemIds) = collection.collection();
        assertEq(itemTargets[0], address(edition), "Item target should be the edition address");
        assertEq(itemIds[0], validItemIds[0], "Item ID should match the created token");
    }
}
