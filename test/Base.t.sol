// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { ERC1967Proxy } from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { RouxAdministrator } from "src/RouxAdministrator.sol";
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

    RouxAdministrator internal administratorImpl;
    RouxAdministrator internal administrator;

    RouxCreator internal creatorImpl;
    RouxCreator internal creator;
    RouxCreatorFactory internal factoryImpl;
    RouxCreatorFactory internal factory;

    ERC6551Registry internal erc6551Registry;
    ERC6551Account internal accountImpl;
    Collection internal collectionImpl;
    Collection internal collection;
    CollectionFactory internal collectionFactoryImpl;
    CollectionFactory internal collectionFactory;

    UpgradeableBeacon internal creatorBeacon;
    UpgradeableBeacon internal collectionBeacon;

    Users internal users;

    /* -------------------------------------------- */
    /* setup                                        */
    /* -------------------------------------------- */

    function setUp() public virtual {
        users = Users({
            deployer: _createUser("deployer"),
            user_0: _createUser("user_0"),
            user_1: _createUser("user_1"),
            user_2: _createUser("user_2"),
            user_3: _createUser("user_3"),
            creator_0: _createUser("creator_0"),
            creator_1: _createUser("creator_1"),
            creator_2: _createUser("creator_2"),
            curator_0: _createUser("curator_0"),
            admin: _createUser("admin")
        });

        _deployAdministrator();
        _deployCreator();
        _deployCreatorFactory();
        _deployTokenBoundContracts();
        _deployCollection();
        _deployCollectionFactory();
        _allowlistUsers();
        _addToken();
        _addCollection();
    }

    function _deployAdministrator() internal {
        /* deployer */
        vm.startPrank(users.deployer);

        /* administrator deployment */
        administratorImpl = new RouxAdministrator();
        vm.label({ account: address(administratorImpl), newLabel: "Roux Administrator Implementation" });

        /* deploy proxy */
        administrator = RouxAdministrator(address(new ERC1967Proxy(address(administratorImpl), "")));
        vm.label({ account: address(administrator), newLabel: "Roux Administrator Proxy" });

        vm.stopPrank();
    }

    function _deployCreator() internal {
        /* deployer */
        vm.startPrank(users.deployer);

        /* creator deployment */
        creatorImpl = new RouxCreator(address(administrator));
        vm.label({ account: address(creatorImpl), newLabel: "Creator" });

        /* beacon deployment */
        creatorBeacon = new UpgradeableBeacon(address(creatorImpl), users.deployer);
        vm.label({ account: address(creatorBeacon), newLabel: "Creator Beacon" });

        vm.stopPrank();
    }

    function _deployCreatorFactory() internal {
        /* deployer */
        vm.startPrank(users.deployer);

        /* factory deployment */
        factoryImpl = new RouxCreatorFactory(address(creatorBeacon));
        vm.label({ account: address(factory), newLabel: "Creator Factory Implementation" });

        /* encode params */
        bytes memory initData = abi.encodeWithSelector(factory.initialize.selector);

        /* Deploy proxy */
        factory = RouxCreatorFactory(address(new ERC1967Proxy(address(factoryImpl), initData)));
        vm.label({ account: address(factory), newLabel: "Roux Creator Factory" });

        vm.stopPrank();
    }

    function _deployTokenBoundContracts() internal {
        /* deployer */
        vm.startPrank(users.deployer);

        /* tokenbound deployments */
        erc6551Registry = new ERC6551Registry();
        accountImpl = new ERC6551Account(address(erc6551Registry));

        vm.stopPrank();
    }

    function _deployCollection() internal {
        /* deployer */
        vm.startPrank(users.deployer);

        /* collection implementation deployment */
        collectionImpl = new Collection(address(erc6551Registry), address(accountImpl), address(factory));
        vm.label({ account: address(collectionImpl), newLabel: "Collection Implementation" });

        /* collection beacon deployment */
        collectionBeacon = new UpgradeableBeacon(address(collectionImpl), users.deployer);
        vm.label({ account: address(creatorBeacon), newLabel: "Collection Beacon" });

        vm.stopPrank();
    }

    function _deployCollectionFactory() internal {
        /* deployer */
        vm.startPrank(users.deployer);

        /* collection factory impl */
        collectionFactoryImpl = new CollectionFactory(address(collectionBeacon));
        vm.label({ account: address(collectionFactoryImpl), newLabel: "Collection Factory Implementation" });

        /* encode params */
        bytes memory initData = abi.encodeWithSelector(collectionFactory.initialize.selector);

        /* deploy proxy */
        collectionFactory = CollectionFactory(address(new ERC1967Proxy(address(collectionFactoryImpl), initData)));
        vm.label({ account: address(factory), newLabel: "Roux Collection Factory" });

        vm.stopPrank();
    }

    function _allowlistUsers() internal {
        vm.startPrank(users.deployer);

        /* add creators to allowlist */
        address[] memory allowlist = new address[](2);
        allowlist[0] = address(users.creator_0);
        allowlist[1] = address(users.creator_1);
        factory.addAllowlist(allowlist);

        /* add curators to curator allowlist */
        address[] memory curatorAllowlist = new address[](3);
        curatorAllowlist[0] = address(users.creator_0);
        curatorAllowlist[1] = address(users.creator_1);
        curatorAllowlist[2] = address(users.curator_0);
        collectionFactory.addAllowlist(curatorAllowlist);

        vm.stopPrank();
    }

    function _addToken() internal {
        /* creator */
        vm.startPrank(users.creator_0);

        /* create token instance */
        creator = RouxCreator(factory.create());

        /* add token */
        creator.add(
            TEST_TOKEN_MAX_SUPPLY, // max supply
            TEST_TOKEN_PRICE, // token price
            uint40(block.timestamp), // mint start
            TEST_TOKEN_MINT_DURATION, // mint duration
            TEST_TOKEN_URI, // token uri
            users.creator_0, // funds recipient
            address(0), // attribution parent
            0, // parent id
            TEST_PROFIT_SHARE // profit share in bps
        );

        vm.stopPrank();
    }

    function _addCollection() internal {
        vm.startPrank(users.creator_0);

        /* create target array for collection */
        address[] memory collectionItemTargets = new address[](1);
        collectionItemTargets[0] = address(creator);

        /* create token id array for collection */
        uint256[] memory collectionItemIds = new uint256[](1);
        collectionItemIds[0] = 1;

        /* encode collection params */
        bytes memory collectionParams = abi.encode(
            TEST_COLLECTION_NAME, TEST_COLLECTION_SYMBOL, TEST_TOKEN_URI, collectionItemTargets, collectionItemIds
        );

        /* create collection instance */
        collection = Collection(collectionFactory.create(collectionParams));

        vm.stopPrank();
    }

    /* -------------------------------------------- */
    /* utility functions                            */
    /* -------------------------------------------- */

    function _createUser(string memory name) internal returns (address payable addr) {
        addr = payable(makeAddr(name));
        vm.label({ account: addr, newLabel: name });
        vm.deal({ account: addr, newBalance: 100 ether });
    }

    function _createForks(uint256 forks) internal returns (RouxCreator[] memory) {
        /* allowlist creator2 */
        vm.prank(users.deployer);
        address[] memory allowlist = new address[](1);
        allowlist[0] = address(users.creator_2);
        factory.addAllowlist(allowlist);

        /* user array */
        address[] memory userArr = new address[](3);
        userArr[0] = users.creator_0;
        userArr[1] = users.creator_1;
        userArr[2] = users.creator_2;

        uint256 num = forks + 1;
        RouxCreator[] memory creators = new RouxCreator[](num);
        creators[0] = creator;

        for (uint256 i = 1; i < num; i++) {
            address user = userArr[i % userArr.length];
            vm.startPrank(user);

            /* create creator instance */
            RouxCreator edition = RouxCreator(factory.create());
            creators[i] = edition;

            /* create forked token with attribution */
            edition.add(
                TEST_TOKEN_MAX_SUPPLY,
                TEST_TOKEN_PRICE,
                uint40(block.timestamp),
                TEST_TOKEN_MINT_DURATION,
                TEST_TOKEN_URI,
                user,
                address(creators[i - 1]),
                1,
                TEST_PROFIT_SHARE
            );
            vm.stopPrank();
        }

        return creators;
    }
}
