// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { BaseTest } from "test/Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { IRouxEdition } from "src/core/interfaces/IRouxEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";
import { IExtension } from "src/periphery/interfaces/IExtension.sol";
import { RouxEdition } from "src/core/RouxEdition.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { MAX_CHILDREN } from "src/libraries/ConstantsLib.sol";

contract Add_RouxCommunityEdition_Integration_Concrete_Test is BaseTest {
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

        vm.prank(users.creator_2);
        uint256 tokenId_ = communityEdition.add(addParams);

        address fundsRecipient_ = controller.fundsRecipient(address(communityEdition), tokenId_);
        uint256 profitShare_ = controller.profitShare(address(communityEdition), tokenId_);

        assertEq(fundsRecipient_, fundsRecipient);
        assertEq(profitShare_, profitShare);
    }

    /// @dev registry data is correctly set after add - not a fork
    function test__AddToken_RegistryDataIsSet() external {
        vm.prank(users.creator_2);
        uint256 tokenId_ = communityEdition.add(addParams);

        (address parentEdition_, uint256 parentTokenId_, uint256 idx) =
            registry.attribution(address(communityEdition), tokenId_);

        assertEq(parentEdition_, address(0));
        assertEq(parentTokenId_, 0);
        assertEq(idx, 0);
    }

    /// @dev registry data is correctly set after add - fork
    function test__AddToken_Fork_RegistryDataIsSet() external {
        (IRouxEdition forkEdition_, uint256 tokenId_) = _createFork(communityEdition, 1, users.creator_1);

        (address parentEdition_, uint256 parentTokenId_, uint256 idx) =
            registry.attribution(address(forkEdition_), tokenId_);

        assertEq(parentEdition_, address(communityEdition));
        assertEq(parentTokenId_, 1);
        assertEq(idx, 0);
    }

    /// @dev registry data is correctly set after add - 2nd level fork
    function test__AddToken_Fork_2ndLevel_RegistryDataIsSet() external {
        (RouxEdition forkEdition_, uint256 tokenId_) = _createFork(communityEdition, 1, users.creator_1);
        (RouxEdition fork2Edition_, uint256 tokenId2_) = _createFork(forkEdition_, tokenId_, users.creator_2);

        (address parentEdition_, uint256 parentTokenId_, uint256 idx) =
            registry.attribution(address(fork2Edition_), tokenId2_);

        assertEq(parentEdition_, address(forkEdition_));
        assertEq(parentTokenId_, tokenId_);
        assertEq(idx, 0);
    }

    /// @dev max num forks is enforced
    function test__AddToken_MaxNumForks() external {
        RouxEdition[] memory communityEditions = new RouxEdition[](MAX_CHILDREN + 1);
        communityEditions[0] = communityEdition;

        for (uint256 i = 1; i <= MAX_CHILDREN; i++) {
            (communityEditions[i],) = _createFork(communityEditions[i - 1], 1, users.creator_1);

            (,, uint256 depth) = registry.root(address(communityEditions[i]), 1);
            assertEq(depth, i);
        }

        RouxEdition newEdition = _createEdition(users.creator_1);

        addParams.fundsRecipient = users.creator_1;
        addParams.parentEdition = address(communityEditions[MAX_CHILDREN]);
        addParams.parentTokenId = 1;

        vm.prank(users.creator_1);
        vm.expectRevert(ErrorsLib.Registry_MaxDepthExceeded.selector);
        newEdition.add(addParams);
    }

    /// @dev extension is set as part of add params
    function test__AddToken_ExtensionIsSet() external {
        IRouxEdition communityEdition_ = _createEdition(users.creator_1);

        addParams.extension = address(mockExtension);

        vm.prank(users.creator_1);
        uint256 tokenId_ = communityEdition_.add(addParams);

        assertTrue(communityEdition_.isRegisteredExtension(tokenId_, address(mockExtension)));
    }

    /// @dev extension is set as part of add params - with mint params
    function test__AddToken_ExtensionIsSet_WithMintParams() external {
        uint128 extPrice = 7 * 10 ** 6;

        IRouxEdition communityEdition_ = _createEdition(users.creator_1);

        addParams.extension = address(mockExtension);
        addParams.options = abi.encode(extPrice);

        vm.prank(users.creator_1);
        uint256 tokenId_ = communityEdition_.add(addParams);

        assertTrue(communityEdition_.isRegisteredExtension(tokenId_, address(mockExtension)));
        assertEq(IExtension(address(mockExtension)).price(address(communityEdition_), tokenId_), extPrice);
    }
}
