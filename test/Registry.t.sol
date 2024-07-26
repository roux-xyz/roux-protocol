// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IRegistry } from "src/interfaces/IRegistry.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { BaseTest } from "./Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { EditionData } from "src/types/DataTypes.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { MAX_NUM_FORKS } from "src/libraries/ConstantsLib.sol";

contract RegistryTest is BaseTest {
    function setUp() public virtual override {
        BaseTest.setUp();
    }

    function test_RevertsWhen_Root_MaxDepthExceeded() external {
        RouxEdition[] memory editions = _createForks(MAX_NUM_FORKS);

        EditionData.AddParams memory modifiedAddParams = defaultAddParams;
        modifiedAddParams.parentEdition = address(editions[MAX_NUM_FORKS]);
        modifiedAddParams.parentTokenId = 1;

        vm.prank(creator);
        vm.expectRevert(ErrorsLib.Registry_MaxDepthExceeded.selector);
        edition.add(modifiedAddParams);
    }

    function test__RevertWhen_UpgradeToAndCall_OnlyOwner() external {
        vm.prank(creator);
        vm.expectRevert(Ownable.Unauthorized.selector);
        registry.upgradeToAndCall(address(edition), "");
    }

    function test__Root_Depth1() external {
        (RouxEdition forkEdition, uint256 forkTokenId) = _createFork(edition, 1, users.creator_1);

        (address root, uint256 tokenId, uint256 depth) = registry.root(address(forkEdition), forkTokenId);

        assertEq(root, address(edition));
        assertEq(tokenId, 1);
        assertEq(depth, 1);
    }

    function test__Root_Depth2() external {
        RouxEdition[] memory editions = _createForks(2);

        (address root, uint256 tokenId, uint256 depth) = registry.root(address(editions[2]), 1);

        assertEq(root, address(edition));
        assertEq(tokenId, 1);
        assertEq(depth, 2);
    }

    function test__Root_Depth_MaxDepth() external {
        RouxEdition[] memory editions = _createForks(MAX_NUM_FORKS);

        (address root, uint256 tokenId, uint256 depth) = registry.root(address(editions[MAX_NUM_FORKS]), 1);

        assertEq(root, address(edition));
        assertEq(tokenId, 1);
        assertEq(depth, MAX_NUM_FORKS);
    }

    function test__Root_DepthOfN(uint256 num) external {
        uint256 n = bound(num, 1, MAX_NUM_FORKS);
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

    function test__Owner() external {
        assertEq(registry.owner(), address(users.deployer));
    }

    function test__AddToken() external {
        RouxEdition edition1 = _createEdition(users.creator_1);

        vm.prank(users.creator_1);
        edition1.add(defaultAddParams);

        assertEq(edition1.currentToken(), 1);

        (address parentEdition, uint256 parentTokenId) = registry.attribution(address(edition1), 1);

        assertEq(parentEdition, address(0));
        assertEq(parentTokenId, 0);

        (address parentEditionReg, uint256 parentTokenIdReg) = registry.attribution(address(edition1), 1);

        assertEq(parentEditionReg, address(0));
        assertEq(parentTokenIdReg, 0);
    }

    function test__AddToken_WithAttribution() external {
        (RouxEdition forkEdition, uint256 forkTokenId) = _createFork(edition, 1, users.creator_1);

        assertEq(forkEdition.currentToken(), forkTokenId);

        (address parentEdition, uint256 parentTokenId) = registry.attribution(address(forkEdition), forkTokenId);

        assertEq(parentEdition, address(edition));
        assertEq(parentTokenId, 1);
    }
}
