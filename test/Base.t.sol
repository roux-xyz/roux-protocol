// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.27;

import "forge-std/Test.sol";

import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { ERC1967Proxy } from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Ownable } from "solady/auth/Ownable.sol";

import { Controller } from "src/core/Controller.sol";
import { IController } from "src/core/interfaces/IController.sol";
import { IRegistry } from "src/core/interfaces/IRegistry.sol";
import { Registry } from "src/core/Registry.sol";
import { IRouxEdition } from "src/core/interfaces/IRouxEdition.sol";
import { RouxEdition } from "src/core/RouxEdition.sol";
import { RouxCommunityEdition } from "src/core/RouxCommunityEdition.sol";
import { RouxEditionFactory } from "src/core/RouxEditionFactory.sol";
import { NoOp } from "src/periphery/NoOp.sol";

import { ERC6551Account } from "src/core/ERC6551Account.sol";
import { ERC6551Registry } from "erc6551/ERC6551Registry.sol";

import { CollectionFactory } from "src/core/CollectionFactory.sol";
import { SingleEditionCollection } from "src/core/SingleEditionCollection.sol";
import { MultiEditionCollection } from "src/core/MultiEditionCollection.sol";
import { ICollection } from "src/core/interfaces/ICollection.sol";

import { RouxMintPortal } from "src/periphery/RouxMintPortal.sol";

import { Events } from "test/utils/Events.sol";
import { Defaults } from "test/utils/Defaults.sol";

import { EditionData, CollectionData } from "src/types/DataTypes.sol";

import { MockUSDC } from "test/mocks/MockUSDC.sol";
import { MockExtension } from "test/mocks/MockExtension.sol";

/**
 * @title Base test
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
        address payable creator_3;
        address payable curator_0;
        address payable admin;
        address payable split;
        address payable usdcDepositor;
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

    // no-op
    NoOp internal noOpImpl;

    // edition
    RouxEdition internal editionImpl;
    UpgradeableBeacon internal editionBeacon;
    RouxEdition internal edition;

    // community edition
    RouxEdition internal communityEditionImpl;
    UpgradeableBeacon internal communityBeacon;
    RouxEdition internal communityEdition;

    // edition factory
    RouxEditionFactory internal factoryImpl;
    RouxEditionFactory internal factory;

    // erc6551
    ERC6551Registry internal erc6551Registry;
    ERC6551Account internal accountImpl;

    // collection
    CollectionFactory internal collectionFactoryImpl;
    CollectionFactory internal collectionFactory;
    SingleEditionCollection internal singleEditionCollectionImpl;
    UpgradeableBeacon internal singleEditionCollectionBeacon;
    MultiEditionCollection internal multiEditionCollectionImpl;
    UpgradeableBeacon internal multiEditionCollectionBeacon;

    // mint portal
    RouxMintPortal internal mintPortalImpl;
    RouxMintPortal internal mintPortal;

    // users
    Users internal users;
    address[] creatorArray = new address[](3);

    // default add params
    EditionData.AddParams internal defaultAddParams;

    // default users
    address internal user;
    address internal creator;

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
            creator_3: _createUser("creator_3"),
            curator_0: _createUser("curator_0"),
            admin: _createUser("admin"),
            split: _createUser("split"),
            usdcDepositor: _createUser("usdcDepositor")
        });

        // set default users
        user = users.user_0;
        creator = users.creator_0;

        // set creator array
        creatorArray[0] = creator;
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

        // deploy no-op implementation
        noOpImpl = _deployNoOpImpl();

        // deploy token bound contracts
        (erc6551Registry, accountImpl) = _deployTokenBoundContracts();

        // deploy roux edition beacon with no-op implementation
        editionBeacon = _deployEditionBeacon({ rouxEditionImpl_: address(noOpImpl) });

        // deploy community edition beacon with no-op implementation
        communityBeacon = _deployCommunityEditionBeacon({ communityEditionImpl_: address(noOpImpl) });

        // deploy roux edition factory impl
        factoryImpl = _deployEditionFactoryImpl({
            editionBeacon_: address(editionBeacon),
            communityBeacon_: address(communityBeacon)
        });

        // deploy roux edition factory proxy
        factory = _deployEditionFactoryProxy({ factoryImpl_: address(factoryImpl) });

        // deploy single edition collection impl
        singleEditionCollectionImpl = _deploySingleEditionCollectionImpl({
            erc6551registry_: address(erc6551Registry),
            accountImpl_: address(accountImpl),
            rouxEditionFactory_: address(factory),
            controller_: address(controller)
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

        // deploy roux edition impl
        editionImpl = _deployEditionImpl({
            editionFactory_: address(factory),
            collectionFactory_: address(collectionFactory),
            controller_: address(controller),
            registry_: address(registry)
        });

        // deploy community edition impl
        communityEditionImpl = RouxEdition(
            address(
                _deployCommunityEditionImpl({
                    editionFactory_: address(factory),
                    collectionFactory_: address(collectionFactory),
                    controller_: address(controller),
                    registry_: address(registry)
                })
            )
        );

        // upgrade edition beacon
        editionBeacon.upgradeTo(address(editionImpl));

        // upgrade community edition beacon
        communityBeacon.upgradeTo(address(communityEditionImpl));

        // deploy mint portal
        mintPortal = _deployMintPortal(address(mockUSDC), address(factory), address(collectionFactory));

        vm.stopPrank();

        // deploy test edition
        edition = _deployEdition();

        // deploy test community edition
        communityEdition = _createCommunityEdition(creator);

        // add default token
        _addToken(edition);

        // add default token to community edition
        _addToken(communityEdition);

        // approve users
        vm.prank(user);
        mockUSDC.approve(address(edition), type(uint256).max);
        vm.prank(users.user_1);
        mockUSDC.approve(address(edition), type(uint256).max);

        vm.prank(user);
        mockUSDC.approve(address(communityEdition), type(uint256).max);
        vm.prank(users.user_1);
        mockUSDC.approve(address(communityEdition), type(uint256).max);

        vm.prank(user);
        mockUSDC.approve(address(mintPortal), type(uint256).max);
        vm.prank(users.user_1);
        mockUSDC.approve(address(mintPortal), type(uint256).max);
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

    /// @dev deploy no-op implementation
    function _deployNoOpImpl() internal returns (NoOp noOpImpl_) {
        noOpImpl_ = new NoOp();
        vm.label({ account: address(noOpImpl_), newLabel: "NoOpImpl" });
    }

    /// @dev deploy token bound contracts
    function _deployTokenBoundContracts() internal returns (ERC6551Registry registry_, ERC6551Account accountImpl_) {
        registry_ = new ERC6551Registry();
        accountImpl_ = new ERC6551Account();

        vm.label({ account: address(registry_), newLabel: "ERC6551Registry" });
        vm.label({ account: address(accountImpl_), newLabel: "ERC6551Account" });
    }

    /// @dev deploy edition implementation
    function _deployEditionImpl(
        address editionFactory_,
        address collectionFactory_,
        address controller_,
        address registry_
    )
        internal
        returns (RouxEdition rouxEditionImpl_)
    {
        rouxEditionImpl_ = RouxEdition(new RouxEdition(editionFactory_, collectionFactory_, controller_, registry_));
        vm.label({ account: address(rouxEditionImpl_), newLabel: "RouxEditionImpl" });
    }

    /// @dev deploy edition beacon
    function _deployEditionBeacon(address rouxEditionImpl_) internal returns (UpgradeableBeacon editionBeacon_) {
        editionBeacon_ = new UpgradeableBeacon(address(rouxEditionImpl_), users.deployer);
        vm.label({ account: address(editionBeacon_), newLabel: "EditionBeacon" });
    }

    /// @dev deploy community edition implementation
    function _deployCommunityEditionImpl(
        address editionFactory_,
        address collectionFactory_,
        address controller_,
        address registry_
    )
        internal
        returns (RouxCommunityEdition communityEditionImpl_)
    {
        communityEditionImpl_ =
            RouxCommunityEdition(new RouxCommunityEdition(editionFactory_, collectionFactory_, controller_, registry_));
        vm.label({ account: address(communityEditionImpl_), newLabel: "RouxCommunityEditionImpl" });
    }

    /// @dev deploy community edition beacon
    function _deployCommunityEditionBeacon(address communityEditionImpl_)
        internal
        returns (UpgradeableBeacon communityBeacon_)
    {
        communityBeacon_ = new UpgradeableBeacon(address(communityEditionImpl_), users.deployer);
        vm.label({ account: address(communityBeacon_), newLabel: "CommunityEditionBeacon" });
    }

    /// @dev deploy edition factory implementation
    function _deployEditionFactoryImpl(
        address editionBeacon_,
        address communityBeacon_
    )
        internal
        returns (RouxEditionFactory factoryImpl_)
    {
        factoryImpl_ = new RouxEditionFactory(editionBeacon_, communityBeacon_);
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
        address rouxEditionFactory_,
        address controller_
    )
        internal
        returns (SingleEditionCollection singleEditionCollectionImpl_)
    {
        singleEditionCollectionImpl_ =
            new SingleEditionCollection(erc6551registry_, accountImpl_, rouxEditionFactory_, controller_);
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
        return _createEdition(creator);
    }

    /// @dev deploy mint portal
    function _deployMintPortal(
        address underlying,
        address editionFactory,
        address collectionFactory_
    )
        internal
        returns (RouxMintPortal mintPortal_)
    {
        mintPortalImpl = new RouxMintPortal(underlying, editionFactory, collectionFactory_);
        vm.label({ account: address(mintPortalImpl), newLabel: "MintPortalImpl" });

        // encode init data
        bytes memory initData = abi.encodeWithSelector(mintPortalImpl.initialize.selector);

        // deploy RouxMintPortal proxy
        mintPortal_ = RouxMintPortal(address(new ERC1967Proxy(address(mintPortalImpl), initData)));
        vm.label({ account: address(mintPortal_), newLabel: "MintPortalProxy" });
    }

    /* -------------------------------------------- */
    /* utility functions                            */
    /* -------------------------------------------- */

    /// @dev set default add params
    function _setDefaultAddParams() internal {
        defaultAddParams = EditionData.AddParams({
            ipfsHash: IPFS_HASH_DIGEST,
            maxSupply: MAX_SUPPLY,
            fundsRecipient: creator,
            defaultPrice: TOKEN_PRICE,
            profitShare: PROFIT_SHARE,
            parentEdition: address(0),
            parentTokenId: 0,
            extension: address(0),
            gate: false,
            options: new bytes(0)
        });
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

    /// @dev create edition
    function _createEdition(address user_) internal returns (RouxEdition) {
        vm.startPrank(user_);

        bytes memory params = abi.encode(CONTRACT_URI);

        // create edition instance
        RouxEdition edition_ = RouxEdition(factory.create(params));
        vm.label({ account: address(edition), newLabel: "New Edition" });

        vm.stopPrank();

        return edition_;
    }

    /// @dev create community edition
    function _createCommunityEdition(address user_) internal returns (RouxEdition) {
        vm.startPrank(user_);

        bytes memory params = abi.encode(CONTRACT_URI);

        // create edition instance
        RouxEdition communityEdition_ = RouxEdition(factory.createCommunity(params));
        vm.label({ account: address(communityEdition_), newLabel: "New Edition" });

        vm.stopPrank();

        return communityEdition_;
    }

    /// @dev add token
    function _addToken(RouxEdition edition_) internal returns (address, uint256) {
        // get owner
        address owner = Ownable(edition_).owner();

        // set creator + funds recipient to owner
        defaultAddParams.fundsRecipient = owner;

        // prank
        vm.prank(owner);

        // add token with default params
        uint256 tokenId = edition_.add(defaultAddParams);

        return (owner, tokenId);
    }

    /// @dev approve token
    function _approveToken(address spender, address user_) internal {
        // approve edition
        vm.prank(user_);
        mockUSDC.approve(address(spender), type(uint256).max);
    }

    /// @dev mint token
    function _mintToken(IRouxEdition edition_, uint256 tokenId, address user_) internal {
        // mint
        vm.prank(user_);
        edition_.mint({ to: user, id: tokenId, quantity: 1, extension: address(0), referrer: address(0), data: "" });
    }

    /// @dev create fork with new edition
    function _createFork(
        RouxEdition parentEdition,
        uint256 parentTokenId,
        address user_
    )
        internal
        returns (RouxEdition, uint256)
    {
        // create edition instance
        RouxEdition forkEdition = _createEdition(user_);

        // copy default add params
        EditionData.AddParams memory newDefaultAddParams = defaultAddParams;

        // modify default add params
        newDefaultAddParams.fundsRecipient = user_;
        newDefaultAddParams.parentEdition = address(parentEdition);
        newDefaultAddParams.parentTokenId = parentTokenId;

        // add token
        vm.prank(user_);
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
                ipfsHash: IPFS_HASH_DIGEST,
                maxSupply: MAX_SUPPLY,
                fundsRecipient: owner,
                defaultPrice: TOKEN_PRICE,
                profitShare: PROFIT_SHARE,
                parentEdition: address(parentEdition),
                parentTokenId: parentTokenId,
                extension: address(0),
                gate: false,
                options: new bytes(0)
            })
        );

        return tokenId;
    }

    /// @dev create multiple forks
    function _createForks(uint256 forks) internal returns (RouxEdition[] memory) {
        uint256 num = forks + 1;
        RouxEdition[] memory editions = new RouxEdition[](num);
        editions[0] = edition;

        // address array
        address[] memory utilizedUsers = new address[](num);
        utilizedUsers[0] = creator;

        for (uint256 i = 1; i < num; i++) {
            address user_ = creatorArray[i % creatorArray.length];
            utilizedUsers[i] = user_;

            vm.startPrank(user_);

            // create edition instance
            bytes memory params = abi.encode(CONTRACT_URI);
            RouxEdition instance = RouxEdition(factory.create(params));
            editions[i] = instance;

            // token params
            EditionData.AddParams memory tokenParams = EditionData.AddParams({
                ipfsHash: IPFS_HASH_DIGEST,
                maxSupply: MAX_SUPPLY,
                fundsRecipient: user_,
                defaultPrice: TOKEN_PRICE,
                profitShare: PROFIT_SHARE,
                parentEdition: address(editions[i - 1]),
                parentTokenId: 1,
                extension: address(0),
                gate: false,
                options: new bytes(0)
            });

            // create forked token with attribution
            instance.add(tokenParams);

            vm.stopPrank();
        }

        assertEq(editions.length, forks + 1);

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

    // @dev get user balance in controller
    function _getUserControllerBalance(address user_) internal view returns (uint256) {
        return controller.balance(user_);
    }

    /* -------------------------------------------- */
    /* modifiers                                    */
    /* -------------------------------------------- */

    modifier useEditionAdmin(address edition_) {
        address admin = Ownable(address(edition_)).owner();

        vm.startPrank(admin);
        _;
        vm.stopPrank();
    }
}
