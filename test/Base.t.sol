// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { ERC1967Proxy } from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Ownable } from "solady/auth/Ownable.sol";

import { Controller } from "src/Controller.sol";
import { IController } from "src/interfaces/IController.sol";
import { IRegistry } from "src/interfaces/IRegistry.sol";
import { Registry } from "src/Registry.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { RouxEditionFactory } from "src/RouxEditionFactory.sol";

import { ERC6551Account } from "src/ERC6551Account.sol";
import { ERC6551Registry } from "erc6551/ERC6551Registry.sol";

import { CollectionFactory } from "src/CollectionFactory.sol";
import { SingleEditionCollection } from "src/SingleEditionCollection.sol";
import { MultiEditionCollection } from "src/MultiEditionCollection.sol";
import { ICollection } from "src/interfaces/ICollection.sol";

import { Events } from "./utils/Events.sol";
import { Defaults } from "./utils/Defaults.sol";

import { EditionData, CollectionData } from "src/types/DataTypes.sol";

import { MockUSDC } from "src/mocks/MockUSDC.sol";
import { MockCreateX } from "src/mocks/MockCreateX.sol";

/**
 * @title Base test
 * @author Roux
 */
abstract contract BaseTest is Test, Events, Defaults {
    /* -------------------------------------------- */
    /* constants                                    */
    /* -------------------------------------------- */
    string public constant ROUX_EDITION_IMPL = "RouxEditionImpl";
    string public constant ROUX_EDITION_BEACON = "RouxEditionBeacon";
    string public constant ROUX_EDITION_FACTORY_IMPL = "RouxEditionFactoryImpl";
    string public constant ROUX_EDITION_FACTORY_PROXY = "RouxEditionFactoryProxy";
    string public constant SINGLE_EDITION_COLLECTION_IMPL = "SingleEditionCollectionImpl";
    string public constant SINGLE_EDITION_COLLECTION_BEACON = "SingleEditionCollectionBeacon";
    string public constant MULTI_EDITION_COLLECTION_IMPL = "MultiEditionCollectionImpl";
    string public constant MULTI_EDITION_COLLECTION_BEACON = "MultiEditionCollectionBeacon";
    string public constant COLLECTION_FACTORY_IMPL = "CollectionFactoryImpl";
    string public constant COLLECTION_FACTORY_PROXY = "CollectionFactoryProxy";

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

    // mocks
    MockUSDC internal mockUSDC;
    MockCreateX internal createX;

    // registry
    Registry internal registryImpl;
    Registry internal registry;

    // controller
    Controller internal controllerImpl;
    Controller internal controller;

    // edition
    RouxEdition internal editionImpl;
    RouxEdition internal edition;
    RouxEditionFactory internal factoryImpl;
    RouxEditionFactory internal factory;

    // erc6551
    ERC6551Registry internal erc6551Registry;
    ERC6551Account internal accountImpl;

    // collection
    CollectionFactory internal collectionFactoryImpl;
    CollectionFactory internal collectionFactory;
    SingleEditionCollection internal singleEditionCollectionImpl;
    SingleEditionCollection internal singleEditionCollection;
    MultiEditionCollection internal multiEditionCollectionImpl;
    MultiEditionCollection internal multiEditionCollection;

    // proxy
    UpgradeableBeacon internal editionBeacon;
    UpgradeableBeacon internal singleEditionCollectionBeacon;
    UpgradeableBeacon internal multiEditionCollectionBeacon;

    // users
    Users internal users;
    address[] creatorArray = new address[](3);

    // default add params
    EditionData.AddParams internal defaultAddParams;

    /* -------------------------------------------- */
    /* setup                                        */
    /* -------------------------------------------- */

    function setUp() public virtual {
        // deploy mock USDC
        _deployMockUSDC();

        // deploy CreateX
        _deployCreateX();

        // create user accounts
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

        // set creator array
        creatorArray[0] = users.creator_0;
        creatorArray[1] = users.creator_1;
        creatorArray[2] = users.creator_2;

        // start prank
        vm.startPrank(users.deployer);

        // set default add params
        _setDefaultAddParams();

        // deploy registry and controller
        registry = _deployRegistry();
        controller = _deployController(address(registry), address(mockUSDC));

        // deploy token bound contracts
        (erc6551Registry, accountImpl) = _deployTokenBoundContracts();

        // deploy roux edition impl using create3
        editionImpl = _deployEditionImpl({
            controller_: address(controller),
            registry_: address(registry),
            rouxEditionFactory_: _computeCreate3Address(ROUX_EDITION_FACTORY_PROXY),
            collectionFactory_: _computeCreate3Address(COLLECTION_FACTORY_PROXY)
        });

        // deploy roux edition beacon using create3
        editionBeacon = _deployEditionBeacon({ rouxEditionImpl_: _computeCreate3Address(ROUX_EDITION_IMPL) });

        // deploy roux edition factory implementation using create3
        factoryImpl = _deployEditionFactoryImpl({ editionBeacon_: _computeCreate3Address(ROUX_EDITION_BEACON) });

        // deploy roux edition factory proxy using create3
        factory = _deployEditionFactoryProxy({ factoryImpl_: _computeCreate3Address(ROUX_EDITION_FACTORY_IMPL) });

        // deploy single edition collection implementation using create3
        singleEditionCollectionImpl = _deploySingleEditionCollectionImpl({
            erc6551registry_: address(erc6551Registry),
            accountImpl_: address(accountImpl),
            rouxEditionFactory_: _computeCreate3Address(ROUX_EDITION_FACTORY_PROXY)
        });

        // deploy single edition collection beacon using create3
        singleEditionCollectionBeacon = _deploySingleEditionCollectionBeacon({
            singleEditionCollectionImpl_: _computeCreate3Address(SINGLE_EDITION_COLLECTION_IMPL)
        });

        // deploy multi edition collection implementation using create3
        multiEditionCollectionImpl = _deployMultiEditionCollectionImpl({
            erc6551registry_: address(erc6551Registry),
            accountImpl_: address(accountImpl),
            rouxEditionFactory_: _computeCreate3Address(ROUX_EDITION_FACTORY_PROXY),
            controller_: address(controller)
        });

        // deploy multi edition collection beacon using create3
        multiEditionCollectionBeacon = _deployMultiEditionCollectionBeacon({
            multiEditionCollectionImpl_: _computeCreate3Address(MULTI_EDITION_COLLECTION_IMPL)
        });

        // deploy collection factory implementation using create3
        collectionFactoryImpl = _deployCollectionFactoryImpl({
            singleEditionCollectionBeacon_: _computeCreate3Address(SINGLE_EDITION_COLLECTION_BEACON),
            multiEditionCollectionBeacon_: _computeCreate3Address(MULTI_EDITION_COLLECTION_BEACON)
        });

        // deploy collection factory proxy using create3
        collectionFactory =
            _deployCollectionFactoryProxy({ collectionFactoryImpl_: _computeCreate3Address(COLLECTION_FACTORY_IMPL) });

        vm.stopPrank();

        // allowlist users
        _allowlistUsers();

        // deploy test edition
        _deployEdition();

        // add default token
        _addToken(edition);
    }

    function _deployMockUSDC() internal {
        mockUSDC = new MockUSDC();
        vm.label({ account: address(mockUSDC), newLabel: "MockUSDC" });
    }

    function _deployCreateX() internal {
        createX = new MockCreateX();
        vm.label({ account: address(createX), newLabel: "CreateX" });
    }

    function _setDefaultAddParams() internal {
        defaultAddParams = EditionData.AddParams({
            tokenUri: TOKEN_URI,
            creator: users.creator_0,
            maxSupply: MAX_SUPPLY,
            fundsRecipient: users.creator_0,
            defaultPrice: TOKEN_PRICE,
            mintStart: uint40(block.timestamp),
            mintEnd: uint40(block.timestamp + MINT_DURATION),
            profitShare: PROFIT_SHARE,
            parentEdition: address(0),
            parentTokenId: 0,
            extension: address(0),
            options: new bytes(0)
        });
    }

    function _deployRegistry() internal returns (Registry) {
        // deploy registry implementation contract
        registryImpl = new Registry();
        vm.label({ account: address(registryImpl), newLabel: "RegistryImplementation" });

        // encode init data
        bytes memory initData = abi.encodeWithSelector(registryImpl.initialize.selector);

        // deploy proxy
        Registry registry_ = Registry(address(new ERC1967Proxy(address(registryImpl), initData)));
        vm.label({ account: address(registry_), newLabel: "RegistryProxy" });

        return registry_;
    }

    function _deployController(address registry_, address currency_) internal returns (Controller) {
        // controller deployment
        controllerImpl = new Controller(registry_, currency_);
        vm.label({ account: address(controllerImpl), newLabel: "ControllerImplementation" });

        // encode init data
        bytes memory initData = abi.encodeWithSelector(controllerImpl.initialize.selector);

        // deploy proxy
        Controller controller_ = Controller(address(new ERC1967Proxy(address(controllerImpl), initData)));
        vm.label({ account: address(controller_), newLabel: "ControllerProxy" });

        return controller_;
    }

    function _deployTokenBoundContracts() internal returns (ERC6551Registry, ERC6551Account) {
        // deploy token bound contracts
        ERC6551Registry erc6551Registry_ = new ERC6551Registry();
        ERC6551Account accountImpl_ = new ERC6551Account(address(erc6551Registry_));

        // label contracts
        vm.label({ account: address(erc6551Registry_), newLabel: "ERC6551Registry" });
        vm.label({ account: address(accountImpl_), newLabel: "ERC6551Account" });

        return (erc6551Registry_, accountImpl_);
    }

    function _deployEditionImpl(
        address controller_,
        address registry_,
        address rouxEditionFactory_,
        address collectionFactory_
    )
        internal
        returns (RouxEdition)
    {
        // generate salt
        bytes32 salt = _generateCreate3Salt(ROUX_EDITION_IMPL);

        // get creation code
        bytes memory creationCode = type(RouxEdition).creationCode;

        // generate init code
        bytes memory initCode =
            abi.encodePacked(creationCode, abi.encode(controller_, registry_, rouxEditionFactory_, collectionFactory_));

        // deploy RouxEdition implementation
        RouxEdition rouxEditionImpl_ = RouxEdition(createX.deployCreate3(salt, initCode));
        vm.label({ account: address(rouxEditionImpl_), newLabel: "RouxEdition Implementation" });

        // validate computed address
        assertEq(
            address(rouxEditionImpl_),
            _computeCreate3Address(ROUX_EDITION_IMPL),
            "edition implementation address mismatch"
        );

        return rouxEditionImpl_;
    }

    function _deployEditionBeacon(address rouxEditionImpl_) internal returns (UpgradeableBeacon) {
        // generate salt
        bytes32 salt = _generateCreate3Salt(ROUX_EDITION_BEACON);

        // get creation code for upgradeable beacon
        bytes memory creationCode = type(UpgradeableBeacon).creationCode;

        // generate init code
        bytes memory initCode = abi.encodePacked(creationCode, abi.encode(rouxEditionImpl_, users.deployer));

        // deploy RouxEdition beacon
        UpgradeableBeacon editionBeacon_ = UpgradeableBeacon(createX.deployCreate3(salt, initCode));
        vm.label({ account: address(editionBeacon_), newLabel: "EditionBeacon" });

        // validate computed address
        assertEq(
            address(editionBeacon_), _computeCreate3Address(ROUX_EDITION_BEACON), "edition beacon address mismatch"
        );

        return editionBeacon_;
    }

    function _deployEditionFactoryImpl(address editionBeacon_) internal returns (RouxEditionFactory) {
        // generate salt
        bytes32 salt = _generateCreate3Salt(ROUX_EDITION_FACTORY_IMPL);

        // get creation code
        bytes memory creationCode = type(RouxEditionFactory).creationCode;

        // generate init code
        bytes memory initCode = abi.encodePacked(creationCode, abi.encode(editionBeacon_));

        // deploy RouxEditionFactory implementation

        RouxEditionFactory impl = RouxEditionFactory(createX.deployCreate3(salt, initCode));
        vm.label({ account: address(impl), newLabel: "RouxEditionFactory Implementation" });

        // validate computed address
        assertEq(
            address(impl),
            _computeCreate3Address(ROUX_EDITION_FACTORY_IMPL),
            "edition factory implementation address mismatch"
        );

        return impl;
    }

    function _deployEditionFactoryProxy(address factoryImpl_) internal returns (RouxEditionFactory) {
        // generate salt
        bytes32 salt = _generateCreate3Salt(ROUX_EDITION_FACTORY_PROXY);

        // get creation code for ERC1967Proxy
        bytes memory creationCode = type(ERC1967Proxy).creationCode;

        // encode init data for RouxEditionFactory
        bytes memory initData = abi.encodeWithSelector(RouxEditionFactory.initialize.selector, address(users.deployer));

        // encode constructor arguments for ERC1967Proxy
        bytes memory constructorArgs = abi.encode(factoryImpl_, initData);

        // combine creationCode and constructorArgs
        bytes memory initCode = abi.encodePacked(creationCode, constructorArgs);

        // deploy RouxEditionFactory proxy
        address proxyAddress = createX.deployCreate3(salt, initCode);
        RouxEditionFactory proxy = RouxEditionFactory(proxyAddress);
        vm.label({ account: address(proxy), newLabel: "RouxEditionFactory Proxy" });

        // validate computed address
        assertEq(
            address(proxy), _computeCreate3Address(ROUX_EDITION_FACTORY_PROXY), "edition factory proxy address mismatch"
        );

        return proxy;
    }

    function _deploySingleEditionCollectionImpl(
        address erc6551registry_,
        address accountImpl_,
        address rouxEditionFactory_
    )
        internal
        returns (SingleEditionCollection)
    {
        // generate salt
        bytes32 salt = _generateCreate3Salt(SINGLE_EDITION_COLLECTION_IMPL);

        // get creation code
        bytes memory creationCode = type(SingleEditionCollection).creationCode;

        // encode init code
        bytes memory initCode =
            abi.encodePacked(creationCode, abi.encode(erc6551registry_, accountImpl_, rouxEditionFactory_));

        // deploy SingleEditionCollection implementation

        SingleEditionCollection impl = SingleEditionCollection(createX.deployCreate3(salt, initCode));
        vm.label({ account: address(impl), newLabel: "SingleEditionCollection Implementation" });

        // validate computed address
        assertEq(
            address(impl),
            _computeCreate3Address(SINGLE_EDITION_COLLECTION_IMPL),
            "single edition collection implementation address mismatch"
        );

        return impl;
    }

    function _deploySingleEditionCollectionBeacon(address singleEditionCollectionImpl_)
        internal
        returns (UpgradeableBeacon)
    {
        // generate salt
        bytes32 salt = _generateCreate3Salt(SINGLE_EDITION_COLLECTION_BEACON);

        // get creation code
        bytes memory creationCode = type(UpgradeableBeacon).creationCode;

        // generate init code
        bytes memory initCode = abi.encodePacked(creationCode, abi.encode(singleEditionCollectionImpl_, users.deployer));

        // deploy upgradeable beacon
        UpgradeableBeacon beacon = UpgradeableBeacon(createX.deployCreate3(salt, initCode));
        vm.label({ account: address(beacon), newLabel: "SingleEditionCollectionBeacon" });

        // validate computed address
        assertEq(
            address(beacon),
            _computeCreate3Address(SINGLE_EDITION_COLLECTION_BEACON),
            "single edition collection beacon address mismatch"
        );

        return beacon;
    }

    function _deployMultiEditionCollectionImpl(
        address erc6551registry_,
        address accountImpl_,
        address rouxEditionFactory_,
        address controller_
    )
        internal
        returns (MultiEditionCollection)
    {
        // generate salt
        bytes32 salt = _generateCreate3Salt(MULTI_EDITION_COLLECTION_IMPL);

        // get creation code
        bytes memory creationCode = type(MultiEditionCollection).creationCode;

        // encode init code
        bytes memory initCode =
            abi.encodePacked(creationCode, abi.encode(erc6551registry_, accountImpl_, rouxEditionFactory_, controller_));

        // deploy MultiEditionCollection implementation
        MultiEditionCollection impl = MultiEditionCollection(createX.deployCreate3(salt, initCode));
        vm.label({ account: address(impl), newLabel: "MultiEditionCollection Implementation" });

        // validate computed address
        assertEq(
            address(impl),
            _computeCreate3Address(MULTI_EDITION_COLLECTION_IMPL),
            "multi edition collection implementation address mismatch"
        );

        return impl;
    }

    function _deployMultiEditionCollectionBeacon(address multiEditionCollectionImpl_)
        internal
        returns (UpgradeableBeacon)
    {
        // generate salt
        bytes32 salt = _generateCreate3Salt(MULTI_EDITION_COLLECTION_BEACON);

        // get creation code
        bytes memory creationCode = type(UpgradeableBeacon).creationCode;

        // generate init code
        bytes memory initCode = abi.encodePacked(creationCode, abi.encode(multiEditionCollectionImpl_, users.deployer));

        // deploy upgradeable beacon

        UpgradeableBeacon beacon = UpgradeableBeacon(createX.deployCreate3(salt, initCode));
        vm.label({ account: address(beacon), newLabel: "MultiEditionCollectionBeacon" });

        // validate computed address
        assertEq(
            address(beacon),
            _computeCreate3Address(MULTI_EDITION_COLLECTION_BEACON),
            "multi edition collection beacon address mismatch"
        );

        return beacon;
    }

    function _deployCollectionFactoryImpl(
        address singleEditionCollectionBeacon_,
        address multiEditionCollectionBeacon_
    )
        internal
        returns (CollectionFactory)
    {
        // generate salt
        bytes32 salt = _generateCreate3Salt(COLLECTION_FACTORY_IMPL);

        // get creation code
        bytes memory creationCode = type(CollectionFactory).creationCode;

        // encode init code
        bytes memory initCode =
            abi.encodePacked(creationCode, abi.encode(singleEditionCollectionBeacon_, multiEditionCollectionBeacon_));

        // deploy CollectionFactory implementation
        CollectionFactory impl = CollectionFactory(createX.deployCreate3(salt, initCode));
        vm.label({ account: address(impl), newLabel: "CollectionFactory Implementation" });

        // validate computed address
        assertEq(
            address(impl),
            _computeCreate3Address(COLLECTION_FACTORY_IMPL),
            "collection factory implementation address mismatch"
        );

        return impl;
    }

    function _deployCollectionFactoryProxy(address collectionFactoryImpl_) internal returns (CollectionFactory) {
        // generate salt
        bytes32 salt = _generateCreate3Salt(COLLECTION_FACTORY_PROXY);

        // get creation code for ERC1967Proxy
        bytes memory creationCode = type(ERC1967Proxy).creationCode;

        // encode init data for CollectionFactory
        bytes memory initData = abi.encodeWithSelector(CollectionFactory.initialize.selector, address(users.deployer));

        // encode constructor arguments for ERC1967Proxy
        bytes memory constructorArgs = abi.encode(collectionFactoryImpl_, initData);

        // combine creationCode and constructorArgs
        bytes memory initCode = abi.encodePacked(creationCode, constructorArgs);

        // deploy CollectionFactory proxy
        address proxyAddress = createX.deployCreate3(salt, initCode);
        CollectionFactory proxy = CollectionFactory(proxyAddress);

        vm.label({ account: address(proxy), newLabel: "CollectionFactory Proxy" });

        // validate computed address
        assertEq(
            address(proxy),
            _computeCreate3Address(COLLECTION_FACTORY_PROXY),
            "collection factory proxy address mismatch"
        );

        return proxy;
    }

    function _deployEdition() internal {
        vm.startPrank(users.creator_0);

        bytes memory params = abi.encode(CONTRACT_URI);
        edition = RouxEdition(factory.create(params));

        vm.stopPrank();
    }

    function _generateCreate3Salt(string memory identifier) internal view returns (bytes32) {
        return bytes32(
            abi.encodePacked(
                address(users.deployer), hex"01", bytes11(keccak256(abi.encodePacked(block.chainid, identifier)))
            )
        );
    }

    function _generateCreate3Salt(address deployer, string memory identifier) internal view returns (bytes32) {
        return bytes32(
            abi.encodePacked(deployer, hex"01", bytes11(keccak256(abi.encodePacked(block.chainid, identifier))))
        );
    }

    function _computeCreate3Address(string memory identifier) internal view returns (address) {
        bytes32 salt = _generateCreate3Salt(identifier);
        bytes32 guardedSalt = keccak256(abi.encode(address(users.deployer), block.chainid, salt));
        address create3address = createX.computeCreate3Address(guardedSalt);

        return create3address;
    }

    function _computeCreate3Address(address deployer, string memory identifier) internal view returns (address) {
        bytes32 salt = _generateCreate3Salt(deployer, identifier);
        bytes32 guardedSalt = keccak256(abi.encode(deployer, block.chainid, salt));
        address create3address = createX.computeCreate3Address(guardedSalt);

        return create3address;
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

        // mint $100 usdc to user
        mockUSDC.mint(addr, 100 * 10 ** 6);
    }

    function _addToken(RouxEdition edition_) internal returns (address, uint256) {
        // get owner
        address owner = Ownable(edition_).owner();

        // prank
        vm.prank(owner);

        // add token with default params
        uint256 tokenId = edition_.add(defaultAddParams);

        return (owner, tokenId);
    }

    function _createEdition(address user) internal returns (RouxEdition) {
        vm.prank(user);

        // create edition instance
        bytes memory params = abi.encode(CONTRACT_URI);
        RouxEdition edition_ = RouxEdition(factory.create(params));
        vm.label({ account: address(edition), newLabel: "New Edition" });

        return edition_;
    }

    function _approveToken(address edition_, address user) internal {
        // approve edition
        vm.prank(user);
        mockUSDC.approve(address(edition_), type(uint256).max);
    }

    function _mintToken(IRouxEdition edition_, uint256 tokenId, address user) internal {
        // mint
        vm.prank(user);
        edition_.mint(users.user_0, tokenId, 1, address(0), address(0), "");
    }

    function _createFork(
        RouxEdition parentEdition,
        uint256 parentTokenId,
        address user
    )
        internal
        returns (RouxEdition, uint256)
    {
        // create edition instance
        RouxEdition forkEdition = _createEdition(user);

        // copy default add params
        EditionData.AddParams memory newDefaultAddParams = defaultAddParams;

        // modify default add params
        newDefaultAddParams.fundsRecipient = user;
        newDefaultAddParams.parentEdition = address(parentEdition);
        newDefaultAddParams.parentTokenId = parentTokenId;

        // add token
        vm.prank(user);
        uint256 tokenId = forkEdition.add(newDefaultAddParams);

        return (forkEdition, tokenId);
    }

    function _createForkExistingEdition(
        RouxEdition edition_,
        RouxEdition parentEdition,
        uint256 parentTokenId
    )
        internal
        returns (uint256)
    {
        // get owner
        address owner = Ownable(edition).owner();

        // prank
        vm.prank(owner);

        // create forked token with attribution
        uint256 tokenId = edition_.add(
            EditionData.AddParams({
                tokenUri: TOKEN_URI,
                creator: owner,
                maxSupply: MAX_SUPPLY,
                fundsRecipient: owner,
                defaultPrice: TOKEN_PRICE,
                mintStart: uint40(block.timestamp),
                mintEnd: uint40(block.timestamp + MINT_DURATION),
                profitShare: PROFIT_SHARE,
                parentEdition: address(parentEdition),
                parentTokenId: parentTokenId,
                extension: address(0),
                options: new bytes(0)
            })
        );

        return tokenId;
    }

    function _createForks(uint256 forks) internal returns (RouxEdition[] memory) {
        // allowlist any users not in the array
        for (uint256 i = 0; i < creatorArray.length; i++) {
            if (!factory.canCreate(creatorArray[i])) {
                vm.prank(users.deployer);
                address[] memory allowlist = new address[](1);
                allowlist[0] = creatorArray[i];
                factory.addAllowlist(allowlist);
            }
        }

        uint256 num = forks + 1;
        RouxEdition[] memory editions = new RouxEdition[](num);
        editions[0] = edition;

        // address array
        address[] memory utilizedUsers = new address[](num);
        utilizedUsers[0] = users.creator_0;

        for (uint256 i = 1; i < num; i++) {
            address user = creatorArray[i % creatorArray.length];
            utilizedUsers[i] = user;

            vm.startPrank(user);

            // create edition instance
            bytes memory params = abi.encode(CONTRACT_URI);
            RouxEdition instance = RouxEdition(factory.create(params));
            editions[i] = instance;

            // token params
            EditionData.AddParams memory tokenParams = EditionData.AddParams({
                tokenUri: TOKEN_URI,
                creator: user,
                maxSupply: MAX_SUPPLY,
                fundsRecipient: user,
                defaultPrice: TOKEN_PRICE,
                mintStart: uint40(block.timestamp),
                mintEnd: uint40(block.timestamp + MINT_DURATION),
                profitShare: PROFIT_SHARE,
                parentEdition: address(editions[i - 1]),
                parentTokenId: 1,
                extension: address(0),
                options: new bytes(0)
            });

            // create forked token with attribution
            instance.add(tokenParams);

            vm.stopPrank();
        }

        return editions;
    }

    function _addMultipleTokens(RouxEdition edition_, uint256 num) internal {
        for (uint256 i = 0; i < num; i++) {
            _addToken(edition_);
        }
    }

    function _computeSplit(
        RouxEdition edition_,
        uint256 tokenId,
        uint256 amount
    )
        internal
        view
        returns (uint256, uint256)
    {
        // get profit share
        uint256 profitShare = controller.profitShare(address(edition_), tokenId);

        // compute split
        uint256 parentShare = (amount * (10_000 - profitShare)) / 10_000;
        uint256 childShare = amount - parentShare;

        return (parentShare, childShare);
    }

    function _createSingleEditionCollection(
        RouxEdition edition_,
        uint256 num
    )
        internal
        returns (uint256[] memory tokenIds, uint256[] memory quantities, SingleEditionCollection collection)
    {
        // 1st already created
        _addMultipleTokens(edition_, num - 1);

        tokenIds = new uint256[](num);
        quantities = new uint256[](num);

        for (uint256 i = 0; i < num; i++) {
            tokenIds[i] = i + 1;
            quantities[i] = 1;
        }

        // deploy collection
        collection = _createCollectionWithParams(address(edition), tokenIds);

        // add collection
        vm.prank(users.creator_0);
        edition.setCollection(tokenIds, address(collection), true);
    }

    function _createCollectionWithParams(
        address itemTarget,
        uint256[] memory itemIds
    )
        internal
        returns (SingleEditionCollection)
    {
        // create params
        bytes memory params = abi.encode(
            COLLECTION_NAME,
            COLLECTION_SYMBOL,
            address(users.creator_0),
            COLLECTION_URI,
            SINGLE_EDITION_COLLECTION_PRICE,
            address(mockUSDC),
            uint40(block.timestamp),
            uint40(block.timestamp + MINT_DURATION),
            address(itemTarget),
            itemIds
        );

        vm.prank(users.creator_0);
        SingleEditionCollection collectionInstance =
            SingleEditionCollection((collectionFactory.create(CollectionData.CollectionType.SingleEdition, params)));

        return collectionInstance;
    }
}
