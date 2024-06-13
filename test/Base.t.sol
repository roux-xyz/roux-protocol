// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.25;

import "forge-std/Test.sol";

import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { ERC1967Proxy } from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { Controller } from "src/Controller.sol";
import { IController } from "src/interfaces/IController.sol";
import { IRegistry } from "src/interfaces/IRegistry.sol";
import { Registry } from "src/Registry.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { RouxEditionFactory } from "src/RouxEditionFactory.sol";

import { EditionMinter } from "src/minters/EditionMinter.sol";
import { DefaultEditionMinter } from "src/minters/DefaultEditionMinter.sol";
import { FreeEditionMinter } from "src/minters/FreeEditionMinter.sol";
import { EditionBatchMinter } from "src/minters/EditionBatchMinter.sol";

import { ERC6551Account } from "src/ERC6551Account.sol";
import { ERC6551Registry } from "erc6551/ERC6551Registry.sol";

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

    // optional mint params
    bytes optionalMintParams;

    // registry
    IRegistry.RegistryData internal registryData;
    Registry internal registryImpl;
    Registry internal registry;

    // controller
    IController.ControllerData internal defaultControllerData;
    Controller internal controllerImpl;
    Controller internal controller;

    // minters
    EditionMinter internal editionMinterImpl;
    EditionMinter internal editionMinter;
    DefaultEditionMinter internal defaultMinterImpl;
    DefaultEditionMinter internal defaultMinter;
    FreeEditionMinter internal freeMinterImpl;
    FreeEditionMinter internal freeMinter;
    EditionBatchMinter internal editionBatchMinterImpl;
    EditionBatchMinter internal editionBatchMinter;

    // edition
    RouxEdition internal editionImpl;
    RouxEdition internal edition;
    RouxEditionFactory internal factoryImpl;
    RouxEditionFactory internal factory;

    // erc6551
    ERC6551Registry internal erc6551Registry;
    ERC6551Account internal accountImpl;

    // proxy
    UpgradeableBeacon internal editionBeacon;

    // users
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

        _deployRegistry();
        _deployController();
        _deployEditionMinter();
        _deployEditionBatchMinter();
        _deployDefaultMinter();
        _deployFreeMinter();
        _deployEditionBeacon();
        _deployEditionFactory();
        _setOptionalSaleData();
        _deployTokenBoundContracts();
        _allowlistUsers();
        _deployEdition();
        _addToken();
    }

    function _deployRegistry() internal {
        // deployer
        vm.startPrank(users.deployer);

        // registry deployment
        registryImpl = new Registry();
        vm.label({ account: address(registryImpl), newLabel: "RegistryImplementation" });

        // encode params
        bytes memory initData = abi.encodeWithSelector(registryImpl.initialize.selector);

        // deploy proxy
        registry = Registry(address(new ERC1967Proxy(address(registryImpl), initData)));
        vm.label({ account: address(registry), newLabel: "RegistryProxy" });

        vm.stopPrank();
    }

    function _deployController() internal {
        // deployer
        vm.startPrank(users.deployer);

        // controller deployment
        controllerImpl = new Controller(address(registry));
        vm.label({ account: address(controllerImpl), newLabel: "ControllerImplementation" });

        // encode params
        bytes memory initData = abi.encodeWithSelector(controllerImpl.initialize.selector);

        // deploy proxy
        controller = Controller(address(new ERC1967Proxy(address(controllerImpl), initData)));
        vm.label({ account: address(controller), newLabel: "ControllerProxy" });

        vm.stopPrank();
    }

    function _deployEditionMinter() internal {
        // deployer
        vm.startPrank(users.deployer);

        // edition minter implementation deployment
        editionMinterImpl = new EditionMinter(address(controller));
        vm.label({ account: address(editionMinterImpl), newLabel: "EditionMinterImplementation" });

        // encode params
        bytes memory initData = abi.encodeWithSelector(editionMinterImpl.initialize.selector);

        // deploy proxy
        editionMinter = EditionMinter(address(new ERC1967Proxy(address(editionMinterImpl), initData)));
        vm.label({ account: address(editionMinter), newLabel: "EditionMinterProxy" });

        vm.stopPrank();
    }

    function _deployEditionBatchMinter() internal {
        // deployer
        vm.startPrank(users.deployer);

        // edition minter implementation deployment
        editionBatchMinterImpl = new EditionBatchMinter(address(controller));
        vm.label({ account: address(editionBatchMinterImpl), newLabel: "EditionBatchMinterImplementation" });

        // encode params
        bytes memory initData = abi.encodeWithSelector(editionBatchMinterImpl.initialize.selector);

        // deploy proxy
        editionBatchMinter = EditionBatchMinter(address(new ERC1967Proxy(address(editionBatchMinterImpl), initData)));
        vm.label({ account: address(editionBatchMinter), newLabel: "EditionBatchMinterProxy" });

        vm.stopPrank();
    }

    function _deployDefaultMinter() internal {
        // deployer
        vm.startPrank(users.deployer);

        // default minter implementation deployment
        defaultMinterImpl = new DefaultEditionMinter(address(controller));
        vm.label({ account: address(defaultMinterImpl), newLabel: "DefaultMinterImplementation" });

        // encode params
        bytes memory initData = abi.encodeWithSelector(defaultMinterImpl.initialize.selector);

        // deploy proxy
        defaultMinter = DefaultEditionMinter(address(new ERC1967Proxy(address(defaultMinterImpl), initData)));
        vm.label({ account: address(defaultMinter), newLabel: "DefaultMinterProxy" });

        vm.stopPrank();
    }

    function _deployFreeMinter() internal {
        // deployer
        vm.startPrank(users.deployer);

        // default minter implementation deployment
        freeMinterImpl = new FreeEditionMinter(address(controller));
        vm.label({ account: address(freeMinterImpl), newLabel: "FreeMinterImplementation" });

        // encode params
        bytes memory initData = abi.encodeWithSelector(freeMinterImpl.initialize.selector);

        // deploy proxy
        freeMinter = FreeEditionMinter(address(new ERC1967Proxy(address(freeMinterImpl), initData)));
        vm.label({ account: address(freeMinter), newLabel: "FreeMinterProxy" });

        vm.stopPrank();
    }

    function _deployEditionBeacon() internal {
        // deployer
        vm.startPrank(users.deployer);

        // set minters
        address[] memory minters = new address[](3);
        minters[0] = address(editionMinter);
        minters[1] = address(defaultMinter);
        minters[2] = address(freeMinter);

        // edition deployment
        editionImpl = new RouxEdition(address(controller), address(registry));
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

    function _deployTokenBoundContracts() internal {
        // deployer
        vm.startPrank(users.deployer);

        // tokenbound deployments
        erc6551Registry = new ERC6551Registry();
        accountImpl = new ERC6551Account(address(erc6551Registry));

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

        vm.stopPrank();
    }

    function _deployEdition() internal {
        // user
        vm.startPrank(users.creator_0);

        // create edition instance
        bytes memory params = abi.encode(TEST_CONTRACT_URI);
        edition = RouxEdition(factory.create(params));

        vm.stopPrank();
    }

    function _addToken() internal {
        vm.startPrank(users.creator_0);

        /* add token */
        RouxEdition(edition).add(
            TEST_TOKEN_URI,
            address(users.creator_0),
            TEST_TOKEN_MAX_SUPPLY,
            address(users.creator_0),
            TEST_PROFIT_SHARE,
            address(0),
            0,
            address(editionMinter),
            optionalMintParams
        );

        vm.stopPrank();
    }

    function _setOptionalSaleData() internal {
        optionalMintParams = _encodeMintParams(
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
            // create edition instance
            bytes memory params = abi.encode(TEST_CONTRACT_URI);
            RouxEdition instance = RouxEdition(factory.create(params));
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
                optionalMintParams
            );

            vm.stopPrank();
        }

        return editions;
    }

    function _addMultipleTokens(uint256 num) internal {
        for (uint256 i = 0; i < num; i++) {
            _addToken();
        }
    }
}
