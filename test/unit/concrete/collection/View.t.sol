// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { CollectionBase } from "test/shared/CollectionBase.t.sol";
import { SingleEditionCollection } from "src/SingleEditionCollection.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { CollectionData, EditionData } from "src/types/DataTypes.sol";
import { Initializable } from "solady/utils/Initializable.sol";

contract Price_SingleEditionCollection_Unit_Concrete_Test is CollectionBase {
    /* -------------------------------------------- */
    /* setup                                        */
    /* -------------------------------------------- */

    function setUp() public virtual override {
        CollectionBase.setUp();
    }

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    /// @dev returns correct owner
    function test__Owner() external view {
        assertEq(singleEditionCollection.owner(), address(collectionAdmin));
    }

    /// @dev returns correct curator
    function test__Curator() external view {
        assertEq(singleEditionCollection.curator(), address(collectionAdmin));
    }

    /// @dev returns correct currency address
    function test__Currency() external view {
        assertEq(singleEditionCollection.currency(), address(mockUSDC));
    }

    /// @dev returns correct total supply
    function test__TotalSupply() external view {
        assertEq(singleEditionCollection.totalSupply(), 0);
    }

    /// @dev returns correct uri
    function test__TokenUri() external view {
        assertEq(singleEditionCollection.tokenURI(10), COLLECTION_URI);
    }

    /// @dev returns correct contract uri
    function test__ContractUri() external view {
        assertEq(singleEditionCollection.contractURI(), COLLECTION_URI);
    }

    /// @dev return collection
    function test__Collection_SingleEdition() external view {
        (address[] memory itemTargets, uint256[] memory itemIds) = singleEditionCollection.collection();
        assertEq(itemIds.length, NUM_TOKENS_SINGLE_EDITION_COLLECTION);
        assertEq(itemTargets[0], address(edition));

        for (uint256 i = 0; i < NUM_TOKENS_SINGLE_EDITION_COLLECTION; i++) {
            assertEq(itemIds[i], i + 1);
        }
    }
}
