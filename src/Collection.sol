// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { IERC6551Registry } from "erc6551/interfaces/IERC6551Registry.sol";
import { IRouxCreator } from "src/interfaces/IRouxCreator.sol";
import { ICollection } from "src/interfaces/ICollection.sol";

contract Collection is ICollection, ERC721, OwnableRoles {
    /* -------------------------------------------- */
    /* constants                                    */
    /* -------------------------------------------- */

    /**
     * @notice Collection storage slot
     * @dev keccak256(abi.encode(uint256(keccak256("erc7201:collection")) - 1)) & ~bytes32(uint256(0xff));
     */
    bytes32 internal constant COLLECTION_STORAGE_SLOT =
        0x993ddef881c729427ec09d4ff4f3cf4f71f12e1245e1afac8dcb6d99ddecf100;

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
    /* structures                                   */
    /* -------------------------------------------- */

    struct CollectionStorage {
        bool _initialized;
        address _curator;
        address[] _itemTargets;
        uint256[] _itemIds;
        uint256 _tokenIds;
        string _uri;
    }

    /* -------------------------------------------- */
    /* constructor                                  */
    /* -------------------------------------------- */

    constructor(address registry, address initialAccountImplementation_) ERC721("", "") {
        CollectionStorage storage $ = _storage();

        /* disable initialization of implementation contract */
        $._initialized = true;

        erc6551Registry = IERC6551Registry(registry);
        initialAccountImplementation = initialAccountImplementation_;
    }

    /* -------------------------------------------- */
    /* initializer                                  */
    /* -------------------------------------------- */

    function initialize(bytes calldata params) external {
        CollectionStorage storage $ = _storage();

        require(!$._initialized, "Already initialized");
        $._initialized = true;

        (string memory baseURI, address[] memory initialItemTargets, uint256[] memory initialItemIds) =
            abi.decode(params, (string, address[], uint256[]));

        _initializeOwner(msg.sender);

        $._uri = baseURI;

        _validateItems(initialItemTargets, initialItemIds);

        $._itemTargets = initialItemTargets;
        $._itemIds = initialItemIds;
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

    function collection() external view returns (address[] memory, uint256[] memory) {
        CollectionStorage storage $ = _storage();

        return ($._itemTargets, $._itemIds);
    }

    function collectionPrice() external view returns (uint256) {
        CollectionStorage storage $ = _storage();

        uint256 price;
        for (uint256 i = 0; i < $._itemTargets.length; i++) {
            price += IRouxCreator($._itemTargets[i]).price($._itemIds[i]);
        }
        return price;
    }

    function curator() external view override returns (address) {
        CollectionStorage storage $ = _storage();

        return $._curator;
    }

    function tokenURI(uint256) public view override returns (string memory) {
        CollectionStorage storage $ = _storage();

        return $._uri;
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
            initialAccountImplementation, 0, block.chainid, address(this), collectionTokenId
        );

        /* mint to collection nft token bound account */
        for (uint256 i = 0; i < $._itemTargets.length; i++) {
            uint256 price = IRouxCreator($._itemTargets[i]).price($._itemIds[i]);
            IRouxCreator($._itemTargets[i]).mint{ value: price }(account, $._itemIds[i], 1);
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

    function _validateItems(address[] memory itemTargets, uint256[] memory itemIds) internal view {
        if (itemTargets.length != itemIds.length) revert InvalidItems();

        for (uint256 i = 0; i < itemTargets.length; i++) {
            if (itemTargets[i] == address(0)) revert InvalidItems();
            if (itemIds[i] == 0 || itemIds[i] > IRouxCreator(itemTargets[i]).tokenCount()) revert InvalidItems();
        }
    }
}
