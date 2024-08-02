// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { ControllerBase } from "test/shared/ControllerBase.t.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { REFERRAL_FEE, PLATFORM_FEE } from "src/libraries/FeesLib.sol";
import { MAX_CHILDREN } from "src/libraries/ConstantsLib.sol";

contract Attribution_Registry_Integration_Concrete_Test is ControllerBase {
    function setUp() public override {
        ControllerBase.setUp();
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev reverts when max depth exceeded
    function test_RevertsWhen_Root_MaxDepthExceeded() external {
        RouxEdition[] memory editions = _createForks(MAX_CHILDREN);

        EditionData.AddParams memory modifiedAddParams = defaultAddParams;
        modifiedAddParams.parentEdition = address(editions[MAX_CHILDREN]);
        modifiedAddParams.parentTokenId = 1;

        vm.prank(creator);
        vm.expectRevert(ErrorsLib.Registry_MaxDepthExceeded.selector);
        edition.add(modifiedAddParams);
    }

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    /// @dev returns correct root
    function test__Root_Depth1() external {
        (RouxEdition forkEdition, uint256 forkTokenId) = _createFork(edition, 1, users.creator_1);

        (address root, uint256 tokenId, uint256 depth) = registry.root(address(forkEdition), forkTokenId);

        assertEq(root, address(edition));
        assertEq(tokenId, 1);
        assertEq(depth, 1);
    }

    /// @dev returns correct root
    function test__Root_Depth2() external {
        RouxEdition[] memory editions = _createForks(2);

        (address root, uint256 tokenId, uint256 depth) = registry.root(address(editions[2]), 1);

        assertEq(root, address(edition));
        assertEq(tokenId, 1);
        assertEq(depth, 2);
    }

    /// @dev returns correct root
    function test__Root_Depth_MaxDepth() external {
        RouxEdition[] memory editions = _createForks(MAX_CHILDREN);

        (address root, uint256 tokenId, uint256 depth) = registry.root(address(editions[MAX_CHILDREN]), 1);

        assertEq(root, address(edition));
        assertEq(tokenId, 1);
        assertEq(depth, MAX_CHILDREN);
    }

    /// @dev returns correct root
    function test__Root_DepthOfN(uint256 num) external {
        uint256 n = bound(num, 1, MAX_CHILDREN);
        RouxEdition[] memory editions = _createForks(n);

        (address root, uint256 tokenId, uint256 depth) = registry.root(address(editions[n]), 1);

        assertEq(root, address(edition));
        assertEq(tokenId, 1);
        assertEq(depth, n);

        assertEq(editions.length, n + 1);
        for (uint256 i = 0; i < n + 1; i++) {
            assertEq(factory.isEdition(address(editions[i])), true);
        }
    }
}
