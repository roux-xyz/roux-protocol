// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { ERC721 } from "solady/tokens/ERC721.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { IERC6551Registry } from "erc6551/interfaces/IERC6551Registry.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { ICollection } from "src/interfaces/ICollection.sol";
import { IRouxEditionFactory } from "src/interfaces/IRouxEditionFactory.sol";

/**
 * @title Collection
 * @author Roux
 */
contract Collection is ICollection, ERC721, OwnableRoles {
    /* -------------------------------------------- */
    /* constants                                    */
    /* -------------------------------------------- */

    /**
     * @notice collection storage slot
     * @dev keccak256(abi.encode(uint256(keccak256("collection.collectioStorage")) - 1)) & ~bytes32(uint256(0xff));
     */
    bytes32 internal constant COLLECTION_STORAGE_SLOT =
        0x1959ff118a65166ce2c660a11d77796bbd2faa19745e8d647947d7e574017700;

    bytes32 internal constant ROUX_COLLECTION_SALT = keccak256("ROUX_COLLECTION");

    /**
     * @notice implementation version
     */
    string public constant IMPLEMENTATION_VERSION = "1.0";

    /* -------------------------------------------- */
    /* immutable state                              */
    /* -------------------------------------------- */

    /**
     * @notice erc6551 registry
     */
    IERC6551Registry immutable erc6551Registry;

    /**
     * @notice initial account implementation
     */
    address immutable initialAccountImplementation;

    /**
     * @notice RouxEdition factory
     */
    IRouxEditionFactory immutable RouxEditionFactory;

    /* -------------------------------------------- */
    /* structures                                   */
    /* -------------------------------------------- */

    struct CollectionStorage {
        bool _initialized;
        address _curator;
        string _name;
        string _symbol;
        address[] _itemTargets;
        uint256[] _itemIds;
        uint256 _tokenIds;
        string _uri;
    }

    /* -------------------------------------------- */
    /* constructor                                  */
    /* -------------------------------------------- */

    constructor(address registry_, address initialAccountImplementation_, address RouxEditionFactory_) {
        CollectionStorage storage $ = _storage();

        /* disable initialization of implementation contract */
        $._initialized = true;

        erc6551Registry = IERC6551Registry(registry_);
        initialAccountImplementation = initialAccountImplementation_;

        RouxEditionFactory = IRouxEditionFactory(RouxEditionFactory_);
    }

    /* -------------------------------------------- */
    /* initializer                                  */
    /* -------------------------------------------- */

    function initialize(bytes calldata params) external {
        CollectionStorage storage $ = _storage();

        require(!$._initialized, "Already initialized");
        $._initialized = true;

        (
            string memory name_,
            string memory symbol_,
            string memory baseURI_,
            address[] memory initialItemTargets_,
            uint256[] memory initialItemIds_
        ) = abi.decode(params, (string, string, string, address[], uint256[]));

        _validateItems(initialItemTargets_, initialItemIds_);

        /* factory will transfer ownership to its caller */
        _initializeOwner(msg.sender);

        $._name = name_;
        $._symbol = symbol_;
        $._uri = baseURI_;
        $._itemTargets = initialItemTargets_;
        $._itemIds = initialItemIds_;
    }

    /* -------------------------------------------- */
    /* storage                                      */
    /* -------------------------------------------- */

    /**
     * @notice Get Collection storage location
     * @return $ Collection storage location
     */
    function _storage() internal pure returns (CollectionStorage storage $) {
        assembly {
            $.slot := COLLECTION_STORAGE_SLOT
        }
    }

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    function implementationVersion() external pure returns (string memory) {
        return IMPLEMENTATION_VERSION;
    }

    function name() public view override returns (string memory) {
        return _storage()._name;
    }

    function symbol() public view override returns (string memory) {
        return _storage()._symbol;
    }

    function tokenURI(uint256) public view override returns (string memory) {
        return _storage()._uri;
    }

    function collection() external view returns (address[] memory, uint256[] memory) {
        CollectionStorage storage $ = _storage();

        return ($._itemTargets, $._itemIds);
    }

    function collectionPrice() external view returns (uint256) {
        CollectionStorage storage $ = _storage();

        uint256 price = 0;
        // for (uint256 i = 0; i < $._itemTargets.length; i++) {
        //     price += IRouxEdition($._itemTargets[i]).price($._itemIds[i]);
        // }
        return price;
    }

    function curator() external view returns (address) {
        return _storage()._curator;
    }

    function totalSupply() external view returns (uint256) {
        return _storage()._tokenIds;
    }

    function exists(uint256 tokenId_) external view returns (bool) {
        return _exists(tokenId_);
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    function mint() public payable returns (uint256) {
        CollectionStorage storage $ = _storage();

        /* increment token id */
        uint256 collectionTokenId = ++$._tokenIds;

        /* mint collection nft */
        _mint(msg.sender, collectionTokenId);

        /* erc 6551 */
        address account = erc6551Registry.createAccount(
            initialAccountImplementation, ROUX_COLLECTION_SALT, block.chainid, address(this), collectionTokenId
        );

        /* mint to collection nft token bound account */
        for (uint256 i = 0; i < $._itemTargets.length; i++) {
            uint256 price = 0;
            // IRouxEdition($._itemTargets[i]).mint{ value: price }(account, $._itemIds[i], 1, "");
        }

        return collectionTokenId;
    }

    /* -------------------------------------------- */
    /* admin                                        */
    /* -------------------------------------------- */

    function addItems(address[] memory itemTargets, uint256[] memory itemIds) external onlyOwner {
        CollectionStorage storage $ = _storage();

        _validateItems(itemTargets, itemIds);

        for (uint256 i = 0; i < itemTargets.length; i++) {
            $._itemTargets.push(itemTargets[i]);
            $._itemIds.push(itemIds[i]);

            emit ItemAdded(itemTargets[i], itemIds[i]);
        }
    }

    function initializeCurator(address curator_) external onlyOwner {
        CollectionStorage storage $ = _storage();

        if ($._curator != address(0)) revert CuratorAlreadyInitialized();
        $._curator = curator_;
    }

    /* -------------------------------------------- */
    /* internal functions                           */
    /* -------------------------------------------- */

    function _validateItems(address[] memory itemTargets_, uint256[] memory itemIds_) internal view {
        if (itemTargets_.length != itemIds_.length) revert InvalidItems();

        for (uint256 i = 0; i < itemTargets_.length; i++) {
            if (!RouxEditionFactory.isEdition(itemTargets_[i])) revert InvalidItems();
            if (itemIds_[i] == 0 || !IRouxEdition(itemTargets_[i]).exists(itemIds_[i])) revert InvalidItems();
        }
    }
}
