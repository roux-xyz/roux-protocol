    // SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { CollectionBase } from "test/shared/CollectionBase.t.sol";
import { MultiEditionCollection } from "src/MultiEditionCollection.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { EditionData, CollectionData } from "src/types/DataTypes.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";

contract CollectionMultiMint_RouxEdition_Integration_Concrete_Test is CollectionBase {
    /* -------------------------------------------- */
    /* setup                                       */
    /* -------------------------------------------- */
    MultiEditionCollection maliciousCollection;

    function setUp() public override {
        CollectionBase.setUp();

        // create malicious collection params
        maliciousCollection = _createMaliciousCollection();
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev reverts when unregistered collection is caller
    function test__RevertWhen_NotCollection() external {
        // approve malicious collection
        _approveToken(address(maliciousCollection), user);

        vm.prank(user);
        vm.expectRevert(ErrorsLib.RouxEdition_InvalidCaller.selector);
        maliciousCollection.mint({ to: user, extension: address(0), referrer: address(0), data: "" });
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev successfully mint collection tokens to token bound account
    function test__MultiEditionCollection_Mint() external {
        // get erc6551 account
        address erc6551account = _getERC6551AccountMultiEdition(address(multiEditionCollection), 1);

        vm.prank(user);
        multiEditionCollection.mint({ to: user, extension: address(0), referrer: address(0), data: "" });

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

    /* -------------------------------------------- */
    /* utility                                      */
    /* -------------------------------------------- */

    /// @dev create malicious collection
    function _createMaliciousCollection() internal returns (MultiEditionCollection) {
        RouxEdition edition1;
        RouxEdition edition2;
        address[] memory itemTargets;
        uint256[] memory itemIds;
        CollectionData.MultiEditionCreateParams memory maliciousParams;

        {
            // create editions and tokens
            edition1 = _createEdition(users.creator_1);
            _addToken(edition1);

            edition2 = _createEdition(users.creator_2);
            _addToken(edition2);

            // create array of item targets
            itemTargets = new address[](2);
            itemTargets[0] = address(edition1);
            itemTargets[1] = address(edition2);

            // create array of item ids
            itemIds = new uint256[](2);
            itemIds[0] = 1;
            itemIds[1] = 1;

            // create params for malicious collection
            maliciousParams = CollectionData.MultiEditionCreateParams({
                name: COLLECTION_NAME,
                symbol: COLLECTION_SYMBOL,
                curator: address(collectionAdmin),
                collectionFeeRecipient: address(collectionAdmin),
                uri: COLLECTION_URI,
                currency: address(mockUSDC),
                mintStart: uint40(block.timestamp),
                mintEnd: uint40(block.timestamp + MINT_DURATION),
                itemTargets: itemTargets,
                itemIds: itemIds
            });
        }

        // create malicious collection
        MultiEditionCollection maliciousCollectionImpl = new MultiEditionCollection(
            address(erc6551Registry), address(accountImpl), address(factory), address(controller)
        );

        // create malicious collection proxy
        MultiEditionCollection maliciousCollectionProxy = MultiEditionCollection(
            address(
                new ERC1967Proxy(
                    address(maliciousCollectionImpl),
                    abi.encodeWithSignature("initialize(bytes)", abi.encode(maliciousParams))
                )
            )
        );

        return maliciousCollectionProxy;
    }
}
