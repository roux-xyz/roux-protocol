// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { CollectionBase } from "test/shared/CollectionBase.t.sol";
import { SingleEditionCollection } from "src/SingleEditionCollection.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";

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

    /// @dev returns correct price
    function test__Price() external view {
        assertEq(singleEditionCollection.price(), SINGLE_EDITION_COLLECTION_PRICE);
    }
}
