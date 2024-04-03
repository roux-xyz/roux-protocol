// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import { IRouxCreator } from "src/interfaces/IRouxCreator.sol";
import { RouxCreator } from "src/RouxCreator.sol";
import { RouxCreatorFactory } from "src/RouxCreatorFactory.sol";

import { ERC6551Account } from "src/ERC6551Account.sol";
import { ERC6551Registry } from "erc6551/ERC6551Registry.sol";

import { ICollection } from "src/interfaces/ICollection.sol";
import { Collection } from "src/Collection.sol";
import { CollectionFactory } from "src/CollectionFactory.sol";

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

    RouxCreator internal creatorImpl;
    RouxCreator internal creator;
    RouxCreatorFactory internal factory;

    ERC6551Registry internal erc6551Registry;
    ERC6551Account internal accountImpl;
    Collection internal collectionImpl;
    Collection internal collection;
    CollectionFactory internal collectionFactory;

    UpgradeableBeacon internal creatorBeacon;

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

        /* creator deployment */
        creatorImpl = new RouxCreator();
        vm.label({ account: address(creatorImpl), newLabel: "Creator Implementation" });

        /* beacon deployment */
        creatorBeacon = new UpgradeableBeacon(address(creatorImpl), users.deployer);
        vm.label({ account: address(creatorBeacon), newLabel: "Creator Beacon" });

        /* factory deployment */
        factory = new RouxCreatorFactory(address(creatorBeacon));
        vm.label({ account: address(factory), newLabel: "Creator Factory" });

        /* tokenbound deployments */
        erc6551Registry = new ERC6551Registry();
        accountImpl = new ERC6551Account(address(erc6551Registry));

        /* collection deployments */
        collectionImpl = new Collection(address(erc6551Registry), address(accountImpl));
        collectionFactory = new CollectionFactory(address(collectionImpl));

        /* add creators to allowlist */
        address[] memory allowlist = new address[](3);
        allowlist[0] = address(users.creator_0);
        allowlist[1] = address(users.creator_1);
        allowlist[2] = address(users.creator_2);
        factory.addAllowlist(allowlist);

        vm.stopPrank();

        /* creator */
        vm.startPrank(users.creator_0);

        /* create token instance */
        creator = RouxCreator(factory.create());

        /* add token */
        creator.add(
            TEST_TOKEN_MAX_SUPPLY, TEST_TOKEN_PRICE, uint40(block.timestamp), TEST_TOKEN_MINT_DURATION, TEST_TOKEN_URI
        );

        /* create target array for collection */
        address[] memory collectionItemTargets = new address[](1);
        collectionItemTargets[0] = address(creator);

        /* create token id array for collection */
        uint256[] memory collectionItemIds = new uint256[](1);
        collectionItemIds[0] = 1;

        /* encode collection params */
        bytes memory collectionParams = abi.encode(TEST_TOKEN_URI, collectionItemTargets, collectionItemIds);

        /* create collection instance */
        collection = Collection(collectionFactory.create(collectionParams));

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
