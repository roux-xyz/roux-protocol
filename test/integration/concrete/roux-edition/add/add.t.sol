// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { BaseTest } from "test/Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";
import { IEditionExtension } from "src/interfaces/IEditionExtension.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { MAX_NUM_FORKS } from "src/libraries/ConstantsLib.sol";

contract Add_RouxEdition_Integration_Concrete_Test is BaseTest {
    /* -------------------------------------------- */
    /* setup                                       */
    /* -------------------------------------------- */

    EditionData.AddParams addParams;

    function setUp() public override {
        BaseTest.setUp();
        addParams = defaultAddParams;
    }

    /* -------------------------------------------- */
    /* write                                       */
    /* -------------------------------------------- */

    /// @dev controller data is set after add
    function test__AddToken_ControllerDataIsSet() external {
        address fundsRecipient = users.split;
        uint256 profitShare = 5_000;

        addParams.fundsRecipient = fundsRecipient;
        addParams.profitShare = profitShare;

        vm.prank(users.creator_0);
        uint256 tokenId_ = edition.add(addParams);

        address fundsRecipient_ = controller.fundsRecipient(address(edition), tokenId_);
        uint256 profitShare_ = controller.profitShare(address(edition), tokenId_);

        assertEq(fundsRecipient_, fundsRecipient);
        assertEq(profitShare_, profitShare);
    }

    /// @dev registry data is correctly set after add - not a fork
    function test__AddToken_RegistryDataIsSet() external {
        vm.prank(users.creator_0);
        uint256 tokenId_ = edition.add(addParams);

        (address parentEdition_, uint256 parentTokenId_) = registry.attribution(address(edition), tokenId_);

        assertEq(parentEdition_, address(0));
        assertEq(parentTokenId_, 0);
    }

    /// @dev registry data is correctly set after add - fork
    function test__AddToken_Fork_RegistryDataIsSet() external {
        (IRouxEdition forkEdition_, uint256 tokenId_) = _createFork(edition, 1, users.creator_1);

        (address parentEdition_, uint256 parentTokenId_) = registry.attribution(address(forkEdition_), tokenId_);

        assertEq(parentEdition_, address(edition));
        assertEq(parentTokenId_, 1);
    }

    /// @dev registry data is correctly set after add - 2nd level fork
    function test__AddToken_Fork_2ndLevel_RegistryDataIsSet() external {
        (RouxEdition forkEdition_, uint256 tokenId_) = _createFork(edition, 1, users.creator_1);
        (RouxEdition fork2Edition_, uint256 tokenId2_) = _createFork(forkEdition_, tokenId_, users.creator_2);

        (address parentEdition_, uint256 parentTokenId_) = registry.attribution(address(fork2Edition_), tokenId2_);

        assertEq(parentEdition_, address(forkEdition_));
        assertEq(parentTokenId_, tokenId_);
    }

    /// @dev max num forks is enforced
    function test__AddToken_MaxNumForks() external {
        RouxEdition[] memory editions = new RouxEdition[](MAX_NUM_FORKS + 1);
        editions[0] = edition;

        for (uint256 i = 1; i <= MAX_NUM_FORKS; i++) {
            (editions[i],) = _createFork(editions[i - 1], 1, users.creator_1);

            (,, uint256 depth) = registry.root(address(editions[i]), 1);
            assertEq(depth, i);
        }

        RouxEdition newEdition = _createEdition(users.creator_1);

        addParams.fundsRecipient = users.creator_1;
        addParams.parentEdition = address(editions[MAX_NUM_FORKS]);
        addParams.parentTokenId = 1;

        vm.prank(users.creator_1);
        vm.expectRevert(ErrorsLib.Registry_MaxDepthExceeded.selector);
        newEdition.add(addParams);
    }

    /// @dev extension is set as part of add params
    function test__AddToken_ExtensionIsSet() external {
        IRouxEdition edition_ = _createEdition(users.creator_1);

        addParams.extension = address(mockExtension);

        vm.prank(users.creator_1);
        uint256 tokenId_ = edition_.add(addParams);

        assertTrue(edition_.isExtension(tokenId_, address(mockExtension)));
    }

    /// @dev extension is set as part of add params - with mint params
    function test__AddToken_ExtensionIsSet_WithMintParams() external {
        uint128 extPrice = 7 * 10 ** 6;

        IRouxEdition edition_ = _createEdition(users.creator_1);

        addParams.extension = address(mockExtension);
        addParams.options = abi.encode(extPrice);

        vm.prank(users.creator_1);
        uint256 tokenId_ = edition_.add(addParams);

        assertTrue(edition_.isExtension(tokenId_, address(mockExtension)));
        assertEq(IEditionExtension(address(mockExtension)).price(address(edition_), tokenId_), extPrice);
    }
}
