// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { BaseTest } from "./Base.t.sol";

import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract UpgradeTest is BaseTest {
    function setUp() public virtual override {
        BaseTest.setUp();
    }

    function test__Upgrade() external {
        // assert current implementation
        assertEq(editionBeacon.implementation(), address(editionImpl));

        // new minter array
        address[] memory minters = new address[](1);
        minters[0] = address(freeMinter);

        // deploy new edition implementation
        IRouxEdition newCreatorImpl = new RouxEdition(address(controller), address(registry), minters);

        // set new implementation in beacon
        vm.prank(users.deployer);
        editionBeacon.upgradeTo(address(newCreatorImpl));

        // assert new implementation
        assertEq(editionBeacon.implementation(), address(newCreatorImpl));

        // assert different implementation
        assertNotEq(editionBeacon.implementation(), address(editionImpl));

        // assert new implementation is not the same as the old one
        assertNotEq(address(newCreatorImpl), address(editionImpl));

        // assert user can add new minter
        vm.startPrank(users.creator_0);

        // create instance
        bytes memory params = abi.encode(TEST_CONTRACT_URI, "");
        address newEdition = factory.create(params);

        // add token
        RouxEdition(newEdition).add(
            TEST_TOKEN_URI,
            users.creator_0,
            TEST_TOKEN_MAX_SUPPLY,
            users.creator_0,
            TEST_PROFIT_SHARE,
            address(0),
            0,
            address(freeMinter), // allowlisted minter
            abi.encode(uint40(block.timestamp), uint40(block.timestamp + TEST_TOKEN_MINT_DURATION))
        );

        // validate new token
        assertEq(RouxEdition(newEdition).totalSupply(1), 1);

        // revert when adding another token with non-allowlisted minter
        vm.expectRevert(IRouxEdition.InvalidMinter.selector);
        RouxEdition(newEdition).add(
            TEST_TOKEN_URI,
            users.creator_0,
            TEST_TOKEN_MAX_SUPPLY,
            users.creator_0,
            TEST_PROFIT_SHARE,
            address(0),
            0,
            address(editionMinter), // non-allowlisted minter
            optionalMintParams
        );
    }
}
