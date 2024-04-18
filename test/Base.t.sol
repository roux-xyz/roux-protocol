// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.25;

import "forge-std/Test.sol";

import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { ERC1967Proxy } from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { RouxAdministrator } from "src/RouxAdministrator.sol";
import { IRouxAdministrator } from "src/interfaces/IRouxAdministrator.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { RouxEditionFactory } from "src/RouxEditionFactory.sol";

import { EditionMinter } from "src/minters/EditionMinter.sol";
import { DefaultEditionMinter } from "src/minters/DefaultEditionMinter.sol";

import { ERC6551Account } from "src/ERC6551Account.sol";
import { ERC6551Registry } from "erc6551/ERC6551Registry.sol";

import { ICollection } from "src/interfaces/ICollection.sol";
import { Collection } from "src/Collection.sol";
import { CollectionFactory } from "src/CollectionFactory.sol";

import { Events } from "./utils/Events.sol";
import { Constants } from "./utils/Constants.sol";

/**
 * @title Base test
 *
 * @author Roux
 *
 */
abstract contract BaseTest is Test, Events, Constants {
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

    bytes optionalSaleData;
    IRouxAdministrator.AdministratorData internal defaultAdministratorData;

    RouxAdministrator internal administratorImpl;
    RouxAdministrator internal administrator;

    EditionMinter internal editionMinter;
    DefaultEditionMinter internal defaultMinter;

    RouxEdition internal editionImpl;
    RouxEdition internal edition;
    RouxEditionFactory internal factoryImpl;
    RouxEditionFactory internal factory;

    ERC6551Registry internal erc6551Registry;
    ERC6551Account internal accountImpl;
    Collection internal collectionImpl;
    Collection internal collection;
    CollectionFactory internal collectionFactoryImpl;
    CollectionFactory internal collectionFactory;

    UpgradeableBeacon internal editionBeacon;
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
        _deployEdition();
        _deployEditionFactory();
        _deployEditionMinter();
        _deployDefaultMinter();
        _setOptionalSaleData();
        _deployTokenBoundContracts();
        _deployCollection();
        _deployCollectionFactory();
        _allowlistUsers();
        _addToken();
        _addCollection();
    }

    function _deployAdministrator() internal {
        // deployer
        vm.startPrank(users.deployer);

        // administrator deployment
        administratorImpl = new RouxAdministrator();
        vm.label({ account: address(administratorImpl), newLabel: "RouxAdministratorImplementation" });

        // encode params
        bytes memory initData = abi.encodeWithSelector(factory.initialize.selector);

        // deploy proxy
        administrator = RouxAdministrator(address(new ERC1967Proxy(address(administratorImpl), initData)));
        vm.label({ account: address(administrator), newLabel: "RouxAdministratorProxy" });

        vm.stopPrank();
    }

    function _deployEdition() internal {
        // deployer
        vm.startPrank(users.deployer);

        // edition deployment
        editionImpl = new RouxEdition(address(administrator));
        vm.label({ account: address(editionImpl), newLabel: "Edition" });

        // beacon deployment
        editionBeacon = new UpgradeableBeacon(address(editionImpl), users.deployer);
        vm.label({ account: address(editionBeacon), newLabel: "EditionBeacon" });

        vm.stopPrank();
    }

    function _deployEditionFactory() internal {
        // deployer
        vm.startPrank(users.deployer);

        // factory deployment
        factoryImpl = new RouxEditionFactory(address(editionBeacon));
        vm.label({ account: address(factory), newLabel: "EditionFactoryImplementation" });

        // encode params
        bytes memory initData = abi.encodeWithSelector(factory.initialize.selector);

        // Deploy proxy
        factory = RouxEditionFactory(address(new ERC1967Proxy(address(factoryImpl), initData)));
        vm.label({ account: address(factory), newLabel: "RouxCreatorFactory" });

        vm.stopPrank();
    }

    function _deployEditionMinter() internal {
        // deployer
        vm.startPrank(users.deployer);

        // edition minter deployment
        editionMinter = new EditionMinter(address(administrator));
        vm.label({ account: address(editionMinter), newLabel: "EditionMinter" });

        vm.stopPrank();
    }

    function _deployDefaultMinter() internal {
        // deployer
        vm.startPrank(users.deployer);

        // edition minter deployment
        defaultMinter = new DefaultEditionMinter(address(administrator));
        vm.label({ account: address(defaultMinter), newLabel: "DefaultMinter" });

        vm.stopPrank();
    }

    function _deployTokenBoundContracts() internal {
        // deployer
        vm.startPrank(users.deployer);

        // tokenbound deployments
        erc6551Registry = new ERC6551Registry();
        accountImpl = new ERC6551Account(address(erc6551Registry));

        vm.stopPrank();
    }

    function _deployCollection() internal {
        // deployer
        vm.startPrank(users.deployer);

        // collection implementation deployment
        collectionImpl = new Collection(address(erc6551Registry), address(accountImpl), address(factory));
        vm.label({ account: address(collectionImpl), newLabel: "CollectionImplementation" });

        // collection beacon deployment
        collectionBeacon = new UpgradeableBeacon(address(collectionImpl), users.deployer);
        vm.label({ account: address(editionBeacon), newLabel: "CollectionBeacon" });

        vm.stopPrank();
    }

    function _deployCollectionFactory() internal {
        // deployer
        vm.startPrank(users.deployer);

        // collection factory impl
        collectionFactoryImpl = new CollectionFactory(address(collectionBeacon));
        vm.label({ account: address(collectionFactoryImpl), newLabel: "CollectionFactoryImplementation" });

        // encode params
        bytes memory initData = abi.encodeWithSelector(collectionFactory.initialize.selector);

        // deploy proxy
        collectionFactory = CollectionFactory(address(new ERC1967Proxy(address(collectionFactoryImpl), initData)));
        vm.label({ account: address(factory), newLabel: "RouxCollectionFactory" });

        vm.stopPrank();
    }

    function _allowlistUsers() internal {
        vm.startPrank(users.deployer);

        // add editions to allowlist
        address[] memory allowlist = new address[](2);
        allowlist[0] = address(users.creator_0);
        allowlist[1] = address(users.creator_1);
        factory.addAllowlist(allowlist);

        // add curators to curator allowlist
        address[] memory curatorAllowlist = new address[](3);
        curatorAllowlist[0] = address(users.creator_0);
        curatorAllowlist[1] = address(users.creator_1);
        curatorAllowlist[2] = address(users.curator_0);
        collectionFactory.addAllowlist(curatorAllowlist);

        vm.stopPrank();
    }

    function _addToken() internal {
        // user
        vm.startPrank(users.creator_0);

        // create edition instance
        edition = RouxEdition(factory.create(""));

        /* add token */
        edition.add(
            TEST_TOKEN_URI,
            address(users.creator_0),
            TEST_TOKEN_MAX_SUPPLY,
            address(users.creator_0),
            TEST_PROFIT_SHARE,
            address(0),
            0,
            address(editionMinter),
            optionalSaleData
        );

        vm.stopPrank();
    }

    function _addCollection() internal {
        vm.startPrank(users.creator_0);

        /* create target array for collection */
        address[] memory collectionItemTargets = new address[](1);
        collectionItemTargets[0] = address(edition);

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

    function _setOptionalSaleData() internal {
        optionalSaleData = _encodeMintParams(
            TEST_TOKEN_PRICE,
            uint40(block.timestamp),
            uint40(block.timestamp) + TEST_TOKEN_MINT_DURATION,
            type(uint16).max
        );
    }

    /* -------------------------------------------- */
    /* utility functions                            */
    /* -------------------------------------------- */

    function _encodeMintParams(
        uint128 price,
        uint40 mintStart,
        uint40 mintEnd,
        uint16 maxMintable
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(price, mintStart, mintEnd, maxMintable);
    }

    function _createUser(string memory name) internal returns (address payable addr) {
        addr = payable(makeAddr(name));
        vm.label({ account: addr, newLabel: name });
        vm.deal({ account: addr, newBalance: 100 ether });
    }

    function _createForks(uint256 forks) internal returns (RouxEdition[] memory) {
        /* allowlist edition2 */
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
        RouxEdition[] memory editions = new RouxEdition[](num);
        editions[0] = edition;

        for (uint256 i = 1; i < num; i++) {
            address user = userArr[i % userArr.length];
            vm.startPrank(user);

            /* create edition instance */
            RouxEdition instance = RouxEdition(factory.create(""));
            editions[i] = instance;

            /* create forked token with attribution */
            instance.add(
                TEST_TOKEN_URI,
                user,
                TEST_TOKEN_MAX_SUPPLY,
                user,
                TEST_PROFIT_SHARE,
                address(editions[i - 1]),
                1,
                address(editionMinter),
                optionalSaleData
            );

            vm.stopPrank();
        }

        return editions;
    }
}
