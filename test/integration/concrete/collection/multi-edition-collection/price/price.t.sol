// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { CollectionBase } from "test/shared/CollectionBase.t.sol";
import { MultiEditionCollection } from "src/MultiEditionCollection.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { CollectionData, EditionData } from "src/types/DataTypes.sol";
import { Initializable } from "solady/utils/Initializable.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";

contract Price_MultiEditionCollection_Integration_Concrete_Test is CollectionBase {
    /* -------------------------------------------- */
    /* setup                                        */
    /* -------------------------------------------- */

    function setUp() public virtual override {
        CollectionBase.setUp();
    }

    /* -------------------------------------------- */
    /* view                                      */
    /* -------------------------------------------- */

    /// @dev returns correct price
    function test__Price() external view {
        assertEq(multiEditionCollection.price(), TOKEN_PRICE * 3);
    }

    /// @dev returns correct price, multiple editions and prices
    function test__Price_MultipleEditions() external {
        EditionData.AddParams memory addParamsEdition1 = defaultAddParams;
        addParamsEdition1.defaultPrice = TOKEN_PRICE + 3;

        EditionData.AddParams memory addParamsEdition2 = defaultAddParams;
        addParamsEdition2.defaultPrice = TOKEN_PRICE + 6;

        EditionData.AddParams memory addParamsEdition3 = defaultAddParams;
        addParamsEdition3.defaultPrice = TOKEN_PRICE + 9;

        RouxEdition edition1 = _createEdition(creator);
        RouxEdition edition2 = _createEdition(creator);
        RouxEdition edition3 = _createEdition(creator);

        vm.startPrank(creator);
        edition1.add(addParamsEdition1);
        edition2.add(addParamsEdition2);
        edition3.add(addParamsEdition3);
        vm.stopPrank();

        uint256 total = edition1.defaultPrice(1) + edition2.defaultPrice(1) + edition3.defaultPrice(1);

        // create multi edition collection params
        RouxEdition[] memory itemTargets = new RouxEdition[](3);
        itemTargets[0] = RouxEdition(edition1);
        itemTargets[1] = RouxEdition(edition2);
        itemTargets[2] = RouxEdition(edition3);

        uint256[] memory itemIds = new uint256[](3);
        itemIds[0] = 1;
        itemIds[1] = 1;
        itemIds[2] = 1;

        // create multi edition collection

        MultiEditionCollection multiEditionCollection_ = _createMultiEditionCollection(itemTargets, itemIds);

        assertEq(multiEditionCollection_.price(), total);
    }
}
