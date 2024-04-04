// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import { BaseTest } from "./Base.t.sol";

import { ERC6551Account } from "src/ERC6551Account.sol";
import { ICollection } from "src/interfaces/ICollection.sol";
import { Collection } from "src/Collection.sol";
import { RouxCreator } from "src/RouxCreator.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "./Constants.t.sol";

contract CollectionTest is BaseTest {
    address account;

    function setUp() public virtual override {
        BaseTest.setUp();
    }

    function test__RevertWhen_InvalidItems_ZeroAddress() external {
        address[] memory collectionItemTargets = new address[](1);
        collectionItemTargets[0] = address(0);

        uint256[] memory collectionItemIds = new uint256[](1);
        collectionItemIds[0] = 1;

        vm.prank(users.creator_0);
        vm.expectRevert(ICollection.InvalidItems.selector);
        Collection(address(collection)).addItems(collectionItemTargets, collectionItemIds);
    }

    function test__RevertWhen_InvalidItems_LengthMismatch() external {
        address[] memory collectionItemTargets = new address[](2);
        collectionItemTargets[0] = address(users.creator_0);
        collectionItemTargets[1] = address(users.creator_0);

        uint256[] memory collectionItemIds = new uint256[](1);
        collectionItemIds[0] = 1;

        vm.prank(users.creator_0);
        vm.expectRevert(ICollection.InvalidItems.selector);
        Collection(address(collection)).addItems(collectionItemTargets, collectionItemIds);
    }

    function test__RevertWhen_InvalidItems_InvalidTokenId() external {
        /* create new item */
        vm.startPrank(users.creator_0);
        creator.add(
            TEST_TOKEN_MAX_SUPPLY,
            TEST_TOKEN_PRICE,
            uint40(block.timestamp),
            TEST_TOKEN_MINT_DURATION,
            "https://new-token-2.com"
        );

        address[] memory collectionItemTargets = new address[](2);
        collectionItemTargets[0] = address(creator);
        collectionItemTargets[1] = address(creator);

        uint256[] memory collectionItemIds = new uint256[](2);
        collectionItemIds[0] = 1;
        collectionItemIds[1] = 3;

        vm.expectRevert(ICollection.InvalidItems.selector);
        Collection(address(collection)).addItems(collectionItemTargets, collectionItemIds);
    }

    function test__Name() external {
        assertEq(collection.name(), TEST_COLLECTION_NAME, "collection name");
    }

    function test__Symbol() external {
        assertEq(collection.symbol(), TEST_COLLECTION_SYMBOL, "collection symbol");
    }

    function test__Owner() external {
        assertEq(collection.owner(), address(users.creator_0), "collection owner");
    }

    function test__Curator() external {
        assertEq(collection.curator(), address(users.creator_0), "collection curator");
    }

    function test__CollectionPrice() external {
        uint256 collectionPrice = collection.collectionPrice();
        assertEq(collectionPrice, TEST_TOKEN_PRICE, "collection price");
    }

    function test__TokenURI() external {
        assertEq(ERC721(address(collection)).tokenURI(1), TEST_TOKEN_URI, "collection tokenURI");
    }

    function test__MintERC1155() external {
        uint256 collectionPrice = collection.collectionPrice();

        vm.prank(users.user_0);
        uint256 collectionTokenId = collection.mint{ value: collectionPrice }();

        account =
            erc6551Registry.account(address(accountImpl), 0, block.chainid, address(collection), collectionTokenId);

        assertEq(collection.balanceOf(users.user_0), 1, "collection balanceOf");
        assertEq(collection.ownerOf(1), users.user_0, "collection ownerOf");

        assertEq(creator.balanceOf(account, 1), 1, "1155 balanceOf");

        (uint256 chainId, address tokenContract, uint256 tokenId) = ERC6551Account(payable(account)).token();
        assertEq(chainId, block.chainid, "chainId");
        assertEq(tokenContract, address(collection), "tokenContract");

        assertEq(ERC6551Account(payable(account)).owner(), users.user_0, "collection owner");
    }

    function test__MintAndTransferERC1155() external {
        uint256 collectionPrice = collection.collectionPrice();

        vm.prank(users.user_0);
        uint256 collectionTokenId = collection.mint{ value: collectionPrice }();

        account =
            erc6551Registry.account(address(accountImpl), 0, block.chainid, address(collection), collectionTokenId);

        assertEq(collection.balanceOf(users.user_0), 1, "collection balanceOf");
        assertEq(collection.ownerOf(1), users.user_0, "collection ownerOf");

        assertEq(creator.balanceOf(account, 1), 1, "1155 balanceOf prior to transfer");

        bytes memory data = abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256,uint256,bytes)", account, users.user_1, 1, 1, ""
        );

        vm.prank(users.user_0);
        ERC6551Account(payable(account)).execute(address(creator), 0, data, ERC6551Account.Operation.Call);

        assertEq(creator.balanceOf(account, 1), 0, "1155 balanceOf account post transfer");
        assertEq(creator.balanceOf(users.user_1, 1), 1, "1155 balanceOf id post transfer");
    }

    function test__AddItems() external {
        /* create new item */
        vm.startPrank(users.creator_0);
        creator.add(
            TEST_TOKEN_MAX_SUPPLY,
            TEST_TOKEN_PRICE,
            uint40(block.timestamp),
            TEST_TOKEN_MINT_DURATION,
            "https://new-token-2.com"
        );

        /* create new contract and item */
        address newCreatorContract = factory.create();
        RouxCreator(newCreatorContract).add(
            TEST_TOKEN_MAX_SUPPLY,
            TEST_TOKEN_PRICE,
            uint40(block.timestamp),
            TEST_TOKEN_MINT_DURATION,
            "https://new-token-3.com"
        );

        /* add new item to collection */
        address[] memory collectionItemTargets = new address[](2);
        collectionItemTargets[0] = address(creator);
        collectionItemTargets[1] = newCreatorContract;

        uint256[] memory collectionItemIds = new uint256[](2);
        collectionItemIds[0] = 2;
        collectionItemIds[1] = 1;

        Collection(address(collection)).addItems(collectionItemTargets, collectionItemIds);

        (address[] memory itemTargets, uint256[] memory itemIds) = collection.collection();

        assertEq(itemTargets.length, 3, "collection item targets length");
        assertEq(itemIds.length, 3, "collection item ids length");

        assertEq(itemTargets[0], address(creator), "collection item target 0");
        assertEq(itemIds[0], 1, "collection item id 0");

        assertEq(itemTargets[1], address(creator), "collection item target 1");
        assertEq(itemIds[1], 2, "collection item id 1");

        assertEq(itemTargets[2], newCreatorContract, "collection item target 2");
        assertEq(itemIds[2], 1, "collection item id 2");

        vm.stopPrank();

        /* mint collection */
        uint256 collectionPrice = collection.collectionPrice();

        vm.prank(users.user_0);
        uint256 collectionTokenId = collection.mint{ value: collectionPrice }();

        account =
            erc6551Registry.account(address(accountImpl), 0, block.chainid, address(collection), collectionTokenId);

        assertEq(collection.balanceOf(users.user_0), 1, "collection balanceOf");
        assertEq(collection.ownerOf(1), users.user_0, "collection ownerOf");

        assertEq(creator.balanceOf(account, 1), 1, "1155 balanceOf id 1");
        assertEq(creator.balanceOf(account, 2), 1, "1155 balanceOf id 2");
        assertEq(RouxCreator(newCreatorContract).balanceOf(account, 1), 1, "new 1155 balanceOf id 1");
    }
}
