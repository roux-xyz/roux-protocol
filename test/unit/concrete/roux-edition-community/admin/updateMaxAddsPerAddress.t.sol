// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { BaseTest } from "test/Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { RouxCommunityEdition } from "src/core/RouxCommunityEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";

contract UpdateMaxAddsPerAddress_RouxCommunityEdition_Unit_Concrete_Test is BaseTest {
    EditionData.AddParams addParams;
    /* -------------------------------------------- */
    /* setup                                        */
    /* -------------------------------------------- */

    function setUp() public override {
        BaseTest.setUp();
        addParams = defaultAddParams;
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev reverts when not owner
    function test__RevertWhen_UpdateMaxAddsPerAddress_NotOwner() external {
        vm.prank(user);
        vm.expectRevert(Ownable.Unauthorized.selector);
        RouxCommunityEdition(address(communityEdition)).updateMaxAddsPerAddress(2);
    }

    /// @dev reverts when incorrect role is granted
    function test__RevertWhen_IncorrectRoleGranted() external {
        uint256 ROLE = RouxCommunityEdition(address(communityEdition)).ALLOWLIST_ADMIN_ROLE();

        vm.prank(creator);
        OwnableRoles(address(communityEdition)).grantRoles(user, ROLE);

        vm.prank(user);
        vm.expectRevert(Ownable.Unauthorized.selector);
        RouxCommunityEdition(address(communityEdition)).updateMaxAddsPerAddress(2);
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev successfully updates max adds per address
    function test__UpdateMaxAddsPerAddress() external {
        uint32 newMaxAdds = 2;

        vm.prank(creator);
        RouxCommunityEdition(address(communityEdition)).updateMaxAddsPerAddress(newMaxAdds);

        assertEq(RouxCommunityEdition(address(communityEdition)).maxAddsPerAddress(), newMaxAdds);

        vm.prank(users.creator_2);
        communityEdition.add(addParams);

        vm.prank(users.creator_2);
        communityEdition.add(addParams);
    }

    /// @dev update max adds per address - admin role
    function test__UpdateMaxAddsPerAddress_AdminRole() external {
        uint32 newMaxAdds = 2;

        uint256 ROLE = RouxCommunityEdition(address(communityEdition)).ADMIN_ROLE();

        vm.prank(creator);
        OwnableRoles(address(communityEdition)).grantRoles(user, ROLE);

        vm.prank(user);
        RouxCommunityEdition(address(communityEdition)).updateMaxAddsPerAddress(newMaxAdds);

        assertEq(RouxCommunityEdition(address(communityEdition)).maxAddsPerAddress(), newMaxAdds);
    }
}
