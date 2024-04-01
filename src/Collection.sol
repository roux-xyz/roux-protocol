// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC6551Registry } from "erc6551/interfaces/IERC6551Registry.sol";
import { IRouxCreator } from "src/interfaces/IRouxCreator.sol";
import { ICollection } from "src/interfaces/ICollection.sol";

contract Collection is ICollection, ERC721 {
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

    /* -------------------------------------------- */
    /* state                                        */
    /* -------------------------------------------- */

    bool internal _initialized;

    /**
     * @notice owner
     */
    address internal _owner;

    /**
     * @notice curator
     */
    address internal _curator;

    /**
     * @notice array of item target addresses
     */
    address[] internal _itemTargets;

    /**
     * @notice array of item ids
     */
    uint256[] internal _itemIds;

    /**
     * @notice token ids
     */
    uint256 internal _tokenIds;

    /**
     * @notice base uri
     */
    string internal _uri;

    /* -------------------------------------------- */
    /* constructor                                  */
    /* -------------------------------------------- */

    constructor(address registry, address initialAccountImplementation_) ERC721("", "") {
        /* disable initialization of implementation contract */
        _initialized = true;

        erc6551Registry = IERC6551Registry(registry);
        initialAccountImplementation = initialAccountImplementation_;
    }

    /* -------------------------------------------- */
    /* initializer                                  */
    /* -------------------------------------------- */

    function initialize(bytes calldata params) external {
        require(!_initialized, "Already initialized");
        _initialized = true;

        (address owner_, string memory baseURI, address[] memory initialItemTargets, uint256[] memory initialItemIds) =
            abi.decode(params, (address, string, address[], uint256[]));

        _owner = owner_;
        _curator = owner_;

        _uri = baseURI;

        _validateItems(initialItemTargets, initialItemIds);

        _itemTargets = initialItemTargets;
        _itemIds = initialItemIds;
    }

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    function collection() external view returns (address[] memory, uint256[] memory) {
        return (_itemTargets, _itemIds);
    }

    function collectionPrice() external view returns (uint256) {
        uint256 price;
        for (uint256 i = 0; i < _itemTargets.length; i++) {
            price += IRouxCreator(_itemTargets[i]).price(_itemIds[i]);
        }
        return price;
    }

    function owner() external view override returns (address) {
        return _owner;
    }

    function curator() external view override returns (address) {
        return _curator;
    }

    function tokenURI(uint256) public view override returns (string memory) {
        return _uri;
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    function mint() public payable returns (uint256) {
        /* increment token id */
        uint256 collectionTokenId = ++_tokenIds;

        /* mint collection nft */
        _mint(msg.sender, collectionTokenId);

        /* erc 6551 */
        address account = erc6551Registry.createAccount(
            initialAccountImplementation, 0, block.chainid, address(this), collectionTokenId
        );

        /* mint to collection nft token bound account */
        for (uint256 i = 0; i < _itemTargets.length; i++) {
            uint256 price = IRouxCreator(_itemTargets[i]).price(_itemIds[i]);
            IRouxCreator(_itemTargets[i]).mint{ value: price }(account, _itemIds[i], 1);
        }

        return collectionTokenId;
    }

    /* -------------------------------------------- */
    /* admin                                        */
    /* -------------------------------------------- */

    function addItems(address[] memory itemTargets, uint256[] memory itemIds) external {
        if (msg.sender != _owner) revert OnlyOwner();
        _validateItems(itemTargets, itemIds);

        for (uint256 i = 0; i < itemTargets.length; i++) {
            _itemTargets.push(itemTargets[i]);
            _itemIds.push(itemIds[i]);

            emit ItemAdded(itemTargets[i], itemIds[i]);
        }
    }

    /* -------------------------------------------- */
    /* internal functions                           */
    /* -------------------------------------------- */

    function _validateItems(address[] memory itemTargets, uint256[] memory itemIds) internal view {
        if (itemTargets.length != itemIds.length) revert InvalidItems();

        for (uint256 i = 0; i < itemTargets.length; i++) {
            if (itemTargets[i] == address(0)) revert InvalidItems();
            if (itemIds[i] == 0 || itemIds[i] > IRouxCreator(itemTargets[i]).tokenCount()) revert InvalidItems();
        }
    }
}
