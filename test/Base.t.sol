// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { IRouxCreator } from "src/interfaces/IRouxCreator.sol";
import { RouxCreator } from "src/RouxCreator.sol";
import { RouxCreatorFactory } from "src/RouxCreatorFactory.sol";

import "./Constants.t.sol";

/**
 * @title Base test
 *
 * @author Roux
 *
 */
abstract contract BaseTest is Test {
    /* -------------------------------------------- */
    /* structures                                   */
    /* -------------------------------------------- */

    /**
     * @notice user accounts
     */
    struct Users {
        address payable deployer;
        address payable user_0;
        address payable user_1;
        address payable user_2;
        address payable user_3;
        address payable creator_0;
        address payable creator_1;
        address payable creator_2;
        address payable curator_0;
        address payable admin;
    }

    /* -------------------------------------------- */
    /* state                                        */
    /* -------------------------------------------- */

    IRouxCreator internal creatorImpl;
    IRouxCreator internal creator;
    RouxCreatorFactory internal factory;
    Users internal users;

    /* -------------------------------------------- */
    /* setup                                        */
    /* -------------------------------------------- */

    function setUp() public virtual {
        users = Users({
            deployer: createUser("deployer"),
            user_0: createUser("user_0"),
            user_1: createUser("user_1"),
            user_2: createUser("user_2"),
            user_3: createUser("user_3"),
            creator_0: createUser("creator_0"),
            creator_1: createUser("creator_1"),
            creator_2: createUser("creator_2"),
            curator_0: createUser("curator_0"),
            admin: createUser("admin")
        });

        /* deployer */
        vm.startPrank(users.deployer);

        /* creator deployments */
        creatorImpl = new RouxCreator();
        factory = new RouxCreatorFactory(address(creatorImpl));

        vm.stopPrank();

        /* creator */
        vm.startPrank(users.creator_0);

        /* encode params */
        bytes memory params = abi.encode(address(users.creator_0));

        /* create token instance */
        creator = RouxCreator(factory.create(params));

        /* add token */
        creator.add(TEST_TOKEN_MAX_SUPPLY, TEST_TOKEN_PRICE, TEST_TOKEN_URI);

        vm.stopPrank();
    }

    /* -------------------------------------------- */
    /* utility functions                            */
    /* -------------------------------------------- */

    function createUser(string memory name) internal returns (address payable addr) {
        addr = payable(makeAddr(name));
        vm.label({ account: addr, newLabel: name });
        vm.deal({ account: addr, newBalance: 100 ether });
    }
}
