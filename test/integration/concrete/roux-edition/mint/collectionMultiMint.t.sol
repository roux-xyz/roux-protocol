// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { CollectionBase } from "test/shared/CollectionBase.t.sol";
import { MultiEditionCollection } from "src/MultiEditionCollection.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";

contract CollectionMultiMint_RouxEdition_Integration_Concrete_Test is CollectionBase {
    /* -------------------------------------------- */
    /* setup                                       */
    /* -------------------------------------------- */

    function setUp() public override {
        CollectionBase.setUp();
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev reverts when unregistered collection is caller
    function test__RevertWhen_NotCollection() external {
        // create editions and tokens
        RouxEdition edition1 = _createEdition(users.creator_1);
        _addToken(edition1);

        RouxEdition edition2 = _createEdition(users.creator_2);
        _addToken(edition2);

        // create array of item targets
        address[] memory itemTargets = new address[](2);
        itemTargets[0] = address(edition1);
        itemTargets[1] = address(edition2);

        // create array of item ids
        uint256[] memory itemIds = new uint256[](2);
        itemIds[0] = 1;
        itemIds[1] = 1;

        // create params for malicious collection
        bytes memory params = abi.encode(
            COLLECTION_NAME,
            COLLECTION_SYMBOL,
            address(collectionAdmin),
            address(collectionAdmin),
            COLLECTION_URI,
            address(mockUSDC),
            uint40(block.timestamp),
            uint40(block.timestamp + MINT_DURATION),
            itemTargets,
            itemIds
        );

        // create malicious collection
        MultiEditionCollection maliciousCollectionImpl = new MultiEditionCollection(
            address(erc6551Registry), address(accountImpl), address(factory), address(controller)
        );

        // create malicious collection proxy
        MultiEditionCollection maliciousCollectionProxy = MultiEditionCollection(
            address(
                new ERC1967Proxy(address(maliciousCollectionImpl), abi.encodeWithSignature("initialize(bytes)", params))
            )
        );

        // approve malicious collection
        _approveToken(address(maliciousCollectionProxy), user);

        // expect revert because malicious collection was not created by collection factory
        vm.prank(user);
        vm.expectRevert(ErrorsLib.RouxEdition_InvalidCaller.selector);
        maliciousCollectionProxy.mint({ to: user, extension: address(0), data: "" });
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev successfully mint collection tokens to token bound account
    function test__MultiEditionCollection_Mint() external {
        // get erc6551 account
        address erc6551account = _getERC6551AccountMultiEdition(address(multiEditionCollection), 1);

        vm.prank(user);
        multiEditionCollection.mint({ to: user, extension: address(0), data: "" });

        // assert owner
        assertEq(multiEditionCollection.ownerOf(1), user);

        // assert total supply
        assertEq(multiEditionCollection.totalSupply(), 1);

        // assert balance
        assertEq(multiEditionCollection.balanceOf(user), 1);

        // assert erc6551 account balance
        assertEq(multiEditionItemTargets[0].balanceOf(erc6551account, 1), 1);
        assertEq(multiEditionItemTargets[1].balanceOf(erc6551account, 1), 1);
        assertEq(multiEditionItemTargets[2].balanceOf(erc6551account, 1), 1);

        // assert total supply
        assertEq(multiEditionItemTargets[0].totalSupply(1), 2);
        assertEq(multiEditionItemTargets[1].totalSupply(1), 2);
        assertEq(multiEditionItemTargets[2].totalSupply(1), 2);
    }
}
