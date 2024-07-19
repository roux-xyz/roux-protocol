// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { BaseTest } from "test/Base.t.sol";

import { Ownable } from "solady/auth/Ownable.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";
import { IEditionExtension } from "src/interfaces/IEditionExtension.sol";

import { RouxEdition } from "src/RouxEdition.sol";

contract Add_RouxEdition_Integration_Concrete_Test is BaseTest {
    /* -------------------------------------------- */
    /* setup                                       */
    /* -------------------------------------------- */

    EditionData.AddParams addParams;

    function setUp() public override {
        BaseTest.setUp();

        // copy default add params
        addParams = defaultAddParams;
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev only allowlisted creator can add token when not a fork
    function test__RevertWhen_AddToken_OnlyAllowlist() external {
        // create edition instance with unallowlisted creator (this is possible)
        IRouxEdition edition_ = _createEdition(users.user_0);

        // edition calls factory to get allowlist status when adding token - reverts
        vm.prank(users.user_0);
        vm.expectRevert(IRouxEdition.OnlyAllowlist.selector);
        edition_.add(addParams);
    }

    /* -------------------------------------------- */
    /* write                                       */
    /* -------------------------------------------- */

    /// @dev controller data is set after add
    function test__AddToken_ControllerDataIsSet() external {
        address fundsRecipient = users.split;
        uint256 profitShare = 5_000;

        // modify default add params
        addParams.fundsRecipient = fundsRecipient;
        addParams.profitShare = profitShare;

        // add token
        vm.prank(users.creator_0);
        uint256 tokenId_ = edition.add(addParams);

        // get controller data
        address fundsRecipient_ = controller.fundsRecipient(address(edition), tokenId_);
        uint256 profitShare_ = controller.profitShare(address(edition), tokenId_);

        assertEq(fundsRecipient_, fundsRecipient);
        assertEq(profitShare_, profitShare);
    }

    /// @dev registry data is correctly set after add - not a fork
    function test__AddToken_RegistryDataIsSet() external {
        // add token
        vm.prank(users.creator_0);
        uint256 tokenId_ = edition.add(addParams);

        // check registry data
        (address parentEdition_, uint256 parentTokenId_) = registry.attribution(address(edition), tokenId_);

        assertEq(parentEdition_, address(0));
        assertEq(parentTokenId_, 0);
    }

    /// @dev registry data is correctly set after add - fork
    function test__AddToken_Fork_RegistryDataIsSet() external {
        // create fork
        (IRouxEdition forkEdition_, uint256 tokenId_) = _createFork(edition, 1, users.creator_1);

        // check registry data
        (address parentEdition_, uint256 parentTokenId_) = registry.attribution(address(forkEdition_), tokenId_);

        assertEq(parentEdition_, address(edition));
        assertEq(parentTokenId_, 1);
    }

    /// @dev registry data is correctly set after add - 2nd level fork
    function test__AddToken_Fork_2ndLevel_RegistryDataIsSet() external {
        // create fork
        (RouxEdition forkEdition_, uint256 tokenId_) = _createFork(edition, 1, users.creator_1);

        // create 2nd level fork
        (RouxEdition fork2Edition_, uint256 tokenId2_) = _createFork(forkEdition_, tokenId_, users.creator_2);

        // check registry data
        (address parentEdition_, uint256 parentTokenId_) = registry.attribution(address(fork2Edition_), tokenId2_);

        assertEq(parentEdition_, address(forkEdition_));
        assertEq(parentTokenId_, tokenId_);
    }

    /// @dev extension is set as part of add params
    function test__AddToken_ExtensionIsSet() external {
        // create edition instance
        IRouxEdition edition_ = _createEdition(users.creator_1);

        // modify default add params
        addParams.extension = address(mockExtension);

        // add token
        vm.prank(users.creator_1);
        uint256 tokenId_ = edition_.add(addParams);

        assertTrue(edition_.isExtension(tokenId_, address(mockExtension)));
    }

    /// @dev extension is set as part of add params - with mint params
    function test__AddToken_ExtensionIsSet_WithMintParams() external {
        uint128 extPrice = 7 * 10 ** 6;

        // create edition instance
        IRouxEdition edition_ = _createEdition(users.creator_1);

        // modify default add params
        addParams.extension = address(mockExtension);
        addParams.options = abi.encode(extPrice);

        // add token
        vm.prank(users.creator_1);
        uint256 tokenId_ = edition_.add(addParams);

        assertTrue(edition_.isExtension(tokenId_, address(mockExtension)));
        assertEq(IEditionExtension(address(mockExtension)).price(address(edition_), tokenId_), extPrice);
    }
}
