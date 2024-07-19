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

import { MockUSDC } from "./mocks/MockUSDC.sol";
import { MockExtension } from "./mocks/MockExtension.sol";

/**
 * @title Base test
 * @author Roux
 */
abstract contract BaseTest is Test, Events, Defaults {
    /* -------------------------------------------- */
    /* structures                                   */
    /* -------------------------------------------- */

    /// @dev user accounts
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
        address payable split;
    }

    /* -------------------------------------------- */
    /* state                                        */
    /* -------------------------------------------- */

    // mocks
    MockUSDC internal mockUSDC;
    MockExtension internal mockExtension;

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

    // default single edition collection add params
    CollectionData.SingleEditionCreateParams internal defaultSingleEditionCollectionCreateParams;

    /* -------------------------------------------- */
    /* setup                                        */
    /* -------------------------------------------- */

    function setUp() public virtual {
        // deploy mock USDC
        mockUSDC = _deployMockUSDC();

        // deploy mock extension
        mockExtension = _deployMockExtension();

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
            admin: _createUser("admin"),
            split: _createUser("split")
        });

        // set creator array
        creatorArray[0] = users.creator_0;
        creatorArray[1] = users.creator_1;
        creatorArray[2] = users.creator_2;

        // start prank
        vm.startPrank(users.deployer);

        // set default add params
        _setDefaultAddParams();

        // deploy registry
        registry = _deployRegistry();

        // deploy controller
        controller = _deployController(address(registry), address(mockUSDC));

        // deploy token bound contracts
        (erc6551Registry, accountImpl) = _deployTokenBoundContracts();

        // deploy roux edition impl
        editionImpl = _deployEditionImpl({ controller_: address(controller), registry_: address(registry) });

        // deploy roux edition beacon
        editionBeacon = _deployEditionBeacon({ rouxEditionImpl_: address(editionImpl) });

        // deploy roux edition factory impl
        factoryImpl = _deployEditionFactoryImpl({ editionBeacon_: address(editionBeacon) });

        // deploy roux edition factory proxy
        factory = _deployEditionFactoryProxy({ factoryImpl_: address(factoryImpl) });

        // deploy single edition collection impl
        singleEditionCollectionImpl = _deploySingleEditionCollectionImpl({
            erc6551registry_: address(erc6551Registry),
            accountImpl_: address(accountImpl),
            rouxEditionFactory_: address(factory)
        });

        // deploy single edition collection beacon
        singleEditionCollectionBeacon =
            _deploySingleEditionCollectionBeacon({ singleEditionCollectionImpl_: address(singleEditionCollectionImpl) });

        // deploy multi edition collection impl
        multiEditionCollectionImpl = _deployMultiEditionCollectionImpl({
            erc6551registry_: address(erc6551Registry),
            accountImpl_: address(accountImpl),
            rouxEditionFactory_: address(factory),
            controller_: address(controller)
        });

        // deploy multi edition collection beacon
        multiEditionCollectionBeacon =
            _deployMultiEditionCollectionBeacon({ multiEditionCollectionImpl_: address(multiEditionCollectionImpl) });

        // deploy collection factory impl
        collectionFactoryImpl = _deployCollectionFactoryImpl({
            singleEditionCollectionBeacon_: address(singleEditionCollectionBeacon),
            multiEditionCollectionBeacon_: address(multiEditionCollectionBeacon)
        });

        // deploy collection factory proxy
        collectionFactory = _deployCollectionFactoryProxy({ collectionFactoryImpl_: address(collectionFactoryImpl) });

        // set collection factory address on  roux edition factory
        factory.setCollectionFactory(address(collectionFactory));

        vm.stopPrank();

        // allowlist users
        _allowlistUsers();

        // deploy test edition
        edition = _deployEdition();

        // add default token
        _addToken(edition);
    }

    /* -------------------------------------------- */
    /* deployment helpers                          */
    /* -------------------------------------------- */

    /// @dev deploy mock USDC
    function _deployMockUSDC() internal returns (MockUSDC mockUSDC_) {
        mockUSDC_ = new MockUSDC();
        vm.label({ account: address(mockUSDC), newLabel: "MockUSDC" });
    }

    /// @dev deploy mock extension
    function _deployMockExtension() internal returns (MockExtension extension_) {
        extension_ = new MockExtension();
        vm.label({ account: address(extension_), newLabel: "MockExtension" });
    }

    /// @dev deploy registry
    function _deployRegistry() internal returns (Registry registry_) {
        registryImpl = new Registry();
        vm.label({ account: address(registryImpl), newLabel: "RegistryImpl" });

        // encode init data
        bytes memory initData = abi.encodeWithSelector(registryImpl.initialize.selector);

        // deploy proxy
        registry_ = Registry(address(new ERC1967Proxy(address(registryImpl), initData)));
        vm.label({ account: address(registry_), newLabel: "RegistryProxy" });
    }

    /// @dev deploy controller
    function _deployController(address registry_, address currency_) internal returns (Controller controller_) {
        controllerImpl = new Controller(registry_, currency_);
        vm.label({ account: address(controllerImpl), newLabel: "ControllerImpl" });

        // encode init data
        bytes memory initData = abi.encodeWithSelector(controllerImpl.initialize.selector);

        // deploy proxy
        controller_ = Controller(address(new ERC1967Proxy(address(controllerImpl), initData)));
        vm.label({ account: address(controller_), newLabel: "ControllerProxy" });
    }

    /// @dev deploy token bound contracts
    function _deployTokenBoundContracts() internal returns (ERC6551Registry registry_, ERC6551Account accountImpl_) {
        registry_ = new ERC6551Registry();
        accountImpl_ = new ERC6551Account(address(registry_));

        vm.label({ account: address(registry_), newLabel: "ERC6551Registry" });
        vm.label({ account: address(accountImpl_), newLabel: "ERC6551Account" });
    }

    /// @dev deploy edition implementation
    function _deployEditionImpl(
        address controller_,
        address registry_
    )
        internal
        returns (RouxEdition rouxEditionImpl_)
    {
        rouxEditionImpl_ = RouxEdition(new RouxEdition(controller_, registry_));
        vm.label({ account: address(rouxEditionImpl_), newLabel: "RouxEditionImpl" });
    }

    /// @dev deploy edition beacon
    function _deployEditionBeacon(address rouxEditionImpl_) internal returns (UpgradeableBeacon editionBeacon_) {
        //TODO: check if can use msg.msg.sender
        editionBeacon_ = new UpgradeableBeacon(address(rouxEditionImpl_), users.deployer);
        vm.label({ account: address(editionBeacon_), newLabel: "EditionBeacon" });
    }

    /// @dev deploy edition factory implementation
    function _deployEditionFactoryImpl(address editionBeacon_) internal returns (RouxEditionFactory factoryImpl_) {
        factoryImpl_ = new RouxEditionFactory(editionBeacon_);
        vm.label({ account: address(factoryImpl_), newLabel: "RouxEditionFactoryImpl" });
    }

    /// @dev deploy edition factory proxy
    function _deployEditionFactoryProxy(address factoryImpl_) internal returns (RouxEditionFactory factory_) {
        // encode init data
        bytes memory initData = abi.encodeWithSelector(RouxEditionFactory.initialize.selector);

        // deploy RouxEditionFactory proxy
        factory_ = RouxEditionFactory(address(new ERC1967Proxy(address(factoryImpl_), initData)));
        vm.label({ account: address(factory_), newLabel: "RouxEditionFactoryProxy" });
    }

    /// @dev deploy single edition collection implementation
    function _deploySingleEditionCollectionImpl(
        address erc6551registry_,
        address accountImpl_,
        address rouxEditionFactory_
    )
        internal
        returns (SingleEditionCollection singleEditionCollectionImpl_)
    {
        singleEditionCollectionImpl_ = new SingleEditionCollection(erc6551registry_, accountImpl_, rouxEditionFactory_);
        vm.label({ account: address(singleEditionCollectionImpl_), newLabel: "SingleEditionCollectionImpl" });
    }

    /// @dev deploy single edition collection beacon
    function _deploySingleEditionCollectionBeacon(address singleEditionCollectionImpl_)
        internal
        returns (UpgradeableBeacon singleEditionCollectionBeacon_)
    {
        singleEditionCollectionBeacon_ = new UpgradeableBeacon(address(singleEditionCollectionImpl_), users.deployer);
        vm.label({ account: address(singleEditionCollectionBeacon_), newLabel: "SingleEditionCollectionBeacon" });
    }

    /// @dev deploy multi edition collection implementation
    function _deployMultiEditionCollectionImpl(
        address erc6551registry_,
        address accountImpl_,
        address rouxEditionFactory_,
        address controller_
    )
        internal
        returns (MultiEditionCollection multiEditionCollectionImpl_)
    {
        multiEditionCollectionImpl_ =
            new MultiEditionCollection(erc6551registry_, accountImpl_, rouxEditionFactory_, controller_);
        vm.label({ account: address(multiEditionCollectionImpl_), newLabel: "MultiEditionCollectionImpl" });
    }

    /// @dev deploy multi edition collection beacon
    function _deployMultiEditionCollectionBeacon(address multiEditionCollectionImpl_)
        internal
        returns (UpgradeableBeacon multiEditionCollectionBeacon_)
    {
        multiEditionCollectionBeacon_ = new UpgradeableBeacon(address(multiEditionCollectionImpl_), users.deployer);
        vm.label({ account: address(multiEditionCollectionBeacon_), newLabel: "MultiEditionCollectionBeacon" });
    }

    /// @dev deploy collection factory implementation
    function _deployCollectionFactoryImpl(
        address singleEditionCollectionBeacon_,
        address multiEditionCollectionBeacon_
    )
        internal
        returns (CollectionFactory collectionFactoryImpl_)
    {
        collectionFactoryImpl_ = new CollectionFactory(singleEditionCollectionBeacon_, multiEditionCollectionBeacon_);
        vm.label({ account: address(collectionFactoryImpl_), newLabel: "CollectionFactoryImpl" });
    }

    /// @dev deploy collection factory proxy
    function _deployCollectionFactoryProxy(address collectionFactoryImpl_)
        internal
        returns (CollectionFactory collectionFactory_)
    {
        // encode init data for CollectionFactory
        bytes memory initData = abi.encodeWithSelector(CollectionFactory.initialize.selector);

        // deploy CollectionFactory proxy
        collectionFactory_ = CollectionFactory(address(new ERC1967Proxy(address(collectionFactoryImpl_), initData)));
        vm.label({ account: address(collectionFactory_), newLabel: "CollectionFactoryProxy" });
    }

    /// @dev deploy edition
    function _deployEdition() internal returns (RouxEdition edition_) {
        vm.startPrank(users.creator_0);

        bytes memory params = abi.encode(CONTRACT_URI);
        edition_ = RouxEdition(factory.create(params));

        vm.stopPrank();
    }

    /* -------------------------------------------- */
    /* utility functions                            */
    /* -------------------------------------------- */

    /// @dev set default add params
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

    /// @dev allowlist users
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

    /// @dev encode mint params
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

    /// @dev create user
    function _createUser(string memory name) internal returns (address payable addr) {
        addr = payable(makeAddr(name));
        vm.label({ account: addr, newLabel: name });
        vm.deal({ account: addr, newBalance: 100 ether });

        // mint $100 usdc to user
        mockUSDC.mint(addr, 100 * 10 ** 6);
    }

    /// @dev add token
    function _addToken(RouxEdition edition_) internal returns (address, uint256) {
        // get owner
        address owner = Ownable(edition_).owner();

        // prank
        vm.prank(owner);

        // add token with default params
        uint256 tokenId = edition_.add(defaultAddParams);

        return (owner, tokenId);
    }

    /// @dev create edition
    function _createEdition(address user) internal returns (RouxEdition) {
        vm.prank(user);

        // create edition instance
        bytes memory params = abi.encode(CONTRACT_URI);
        RouxEdition edition_ = RouxEdition(factory.create(params));
        vm.label({ account: address(edition), newLabel: "New Edition" });

        return edition_;
    }

    /// @dev approve token
    function _approveToken(address edition_, address user) internal {
        // approve edition
        vm.prank(user);
        mockUSDC.approve(address(edition_), type(uint256).max);
    }

    /// @dev mint token
    function _mintToken(IRouxEdition edition_, uint256 tokenId, address user) internal {
        // mint
        vm.prank(user);
        edition_.mint({
            to: users.user_0,
            id: tokenId,
            quantity: 1,
            extension: address(0),
            referrer: address(0),
            data: ""
        });
    }

    /// @dev create fork with new edition
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

    /// @dev create fork using existing edition
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

    /// @dev create multiple forks
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

    /// @dev add multiple tokens
    function _addMultipleTokens(RouxEdition edition_, uint256 num) internal {
        for (uint256 i = 0; i < num; i++) {
            _addToken(edition_);
        }
    }

    /// @dev compute split
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

    /// @dev create single edition collection
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
    }

    /// @dev create collection with params
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
