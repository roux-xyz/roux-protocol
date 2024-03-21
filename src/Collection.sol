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

        (address owner_, address[] memory initialItemTargets, uint256[] memory initialItemIds) =
            abi.decode(params, (address, address[], uint256[]));

        _owner = owner_;

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

        for (uint256 i = 0; i < itemTargets.length; i++) {
            _itemTargets.push(itemTargets[i]);
            _itemIds.push(itemIds[i]);

            emit ItemAdded(itemTargets[i], itemIds[i]);
        }
    }

    function removeItem(uint256 index) external {
        if (msg.sender != _owner) revert OnlyOwner();

        /* cache item */
        address target = _itemTargets[index];
        uint256 id = _itemIds[index];

        /* replace item at index with last item */
        _itemTargets[index] = _itemTargets[_itemTargets.length - 1];
        _itemIds[index] = _itemIds[_itemIds.length - 1];

        /* pop last item */
        _itemTargets.pop();
        _itemIds.pop();

        emit ItemRemoved(target, id);
    }
}
