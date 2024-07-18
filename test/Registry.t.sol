// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IRegistry } from "src/interfaces/IRegistry.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { BaseTest } from "./Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";

import { EditionData } from "src/types/DataTypes.sol";

contract RegistryTest is BaseTest {
    function setUp() public virtual override {
        BaseTest.setUp();
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    function test_RevertsWhen_Root_MaxDepthExceeded() external {
        // create forks up to max depth
        RouxEdition[] memory editions = _createForks(MAX_FORK_DEPTH);

        // copy default add params
        EditionData.AddParams memory modifiedAddParams = defaultAddParams;

        // modify default add params
        modifiedAddParams.parentEdition = address(editions[MAX_FORK_DEPTH]);
        modifiedAddParams.parentTokenId = 1;

        // attempt to add another fork
        vm.prank(users.creator_0);
        vm.expectRevert(IRegistry.MaxDepthExceeded.selector);
        edition.add(modifiedAddParams);
    }

    function test__RevertWhen_UpgradeToAndCall_OnlyOwner() external {
        // attempt to upgrade to and call
        vm.prank(users.creator_0);
        vm.expectRevert(Ownable.Unauthorized.selector);
        registry.upgradeToAndCall(address(edition), "");
    }

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    function test__Root_Depth1() external {
        // create fork
        (RouxEdition forkEdition, uint256 forkTokenId) = _createFork(edition, 1, users.creator_1);

        /* get root */
        (address root, uint256 tokenId, uint256 depth) = registry.root(address(forkEdition), forkTokenId);

        assertEq(root, address(edition));
        assertEq(tokenId, 1);
        assertEq(depth, 1);
    }

    function test__Root_Depth2() external {
        RouxEdition[] memory editions = _createForks(2);

        /* get root */
        (address root, uint256 tokenId, uint256 depth) = registry.root(address(editions[2]), 1);

        assertEq(root, address(edition));
        assertEq(tokenId, 1);
        assertEq(depth, 2);
    }

    function test__Root_Depth_MaxDepth() external {
        RouxEdition[] memory editions = _createForks(MAX_FORK_DEPTH);

        /* get root */
        (address root, uint256 tokenId, uint256 depth) = registry.root(address(editions[MAX_FORK_DEPTH]), 1);

        assertEq(root, address(edition));
        assertEq(tokenId, 1);
        assertEq(depth, MAX_FORK_DEPTH);
    }

    function test__Root_DepthOfN(uint256 num) external {
        uint256 n = bound(num, 1, MAX_FORK_DEPTH);
        RouxEdition[] memory editions = _createForks(n);

        /* get root */
        (address root, uint256 tokenId, uint256 depth) = registry.root(address(editions[n]), 1);

        assertEq(root, address(edition));
        assertEq(tokenId, 1);
        assertEq(depth, n);

        /* sanity checks */
        assertEq(editions.length, n + 1); // original + n forks
        for (uint256 i = 0; i < n + 1; i++) {
            assertEq(factory.isEdition(address(editions[i])), true);
        }
    }

    function test__Owner() external {
        assertEq(registry.owner(), address(users.deployer));
    }

    /* -------------------------------------------- */
    /* write                                       */
    /* -------------------------------------------- */

    function test__AddToken() external {
        // create edition instance
        RouxEdition edition1 = _createEdition(users.creator_1);

        // add token
        vm.prank(users.creator_1);
        edition1.add(defaultAddParams);

        // check token data
        assertEq(edition1.currentToken(), 1);

        // get attribution from edition
        (address parentEdition, uint256 parentTokenId) = registry.attribution(address(edition1), 1);

        // verify attribution
        assertEq(parentEdition, address(0));
        assertEq(parentTokenId, 0);

        // get attribution from registry
        (address parentEditionReg, uint256 parentTokenIdReg) = registry.attribution(address(edition1), 1);

        // verify attribution
        assertEq(parentEditionReg, address(0));
        assertEq(parentTokenIdReg, 0);
    }

    function test__AddToken_WithAttribution() external {
        // create fork
        (RouxEdition forkEdition, uint256 forkTokenId) = _createFork(edition, 1, users.creator_1);

        // check token data
        assertEq(forkEdition.currentToken(), forkTokenId);

        // get attribution
        (address parentEdition, uint256 parentTokenId) = registry.attribution(address(forkEdition), forkTokenId);

        // verify attribution
        assertEq(parentEdition, address(edition));
        assertEq(parentTokenId, 1);
    }
}
