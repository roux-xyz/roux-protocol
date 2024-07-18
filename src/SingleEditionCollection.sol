// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ReentrancyGuard } from "solady/utils/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IERC6551Registry } from "erc6551/interfaces/IERC6551Registry.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { ICollection } from "src/interfaces/ICollection.sol";
import { ICollectionExtension } from "src/interfaces/ICollectionExtension.sol";
import { IRouxEditionFactory } from "src/interfaces/IRouxEditionFactory.sol";
import { Collection } from "src/Collection.sol";

import { CollectionData } from "src/types/DataTypes.sol";

/**
 * @title Single Edition Collection
 * @author Roux
 */
contract SingleEditionCollection is Collection {
    using SafeERC20 for IERC20;

    /* -------------------------------------------- */
    /* constants                                    */
    /* -------------------------------------------- */

    /**
     * @notice collection storage slot
     * @dev keccak256(abi.encode(uint256(keccak256("singleEditionCollection.singleEditionCollectionStorage")) - 1)) &
     * ~bytes32(uint256(0xff));
     */
    bytes32 internal constant SINGLE_EDITION_COLLECTION_STORAGE_SLOT =
        0xa6e0118951a25969bd3c1390bebbde8eb1379a4bbd50f1af4df5dda29b004500;

    /**
     * @notice collection salt used for erc6551 implementation
     */
    bytes32 internal constant ROUX_SINGLE_EDITION_COLLECTION_SALT = keccak256("ROUX_SINGLE_EDITION_COLLECTION");

    /* -------------------------------------------- */
    /* constructor                                  */
    /* -------------------------------------------- */

    /**
     * @notice constructor
     * @param erc6551registry registry
     * @param accountImplementation initial erc6551 account implementation
     * @param rouxEditionFactory roux edition factory
     */
    constructor(
        address erc6551registry,
        address accountImplementation,
        address rouxEditionFactory
    )
        Collection(erc6551registry, accountImplementation, rouxEditionFactory)
    { }

    /* -------------------------------------------- */
    /* storage                                      */
    /* -------------------------------------------- */

    /**
     * @notice SingleEditionCollection storage
     * @return $$ SingleEditionCollection storage location
     */
    function _singleEditionCollectionStorage()
        internal
        pure
        returns (CollectionData.SingleEditionCollectionStorage storage $$)
    {
        assembly {
            $$.slot := SINGLE_EDITION_COLLECTION_STORAGE_SLOT
        }
    }

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    /**
     * @inheritdoc ICollection
     */
    function price() external view override returns (uint256) {
        return _singleEditionCollectionStorage().mintParams.price;
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /**
     * @inheritdoc ICollection
     */
    function mint(
        address to,
        address extension,
        bytes calldata data
    )
        public
        payable
        override
        nonReentrant
        returns (uint256)
    {
        CollectionStorage storage $ = _collectionStorage();
        CollectionData.SingleEditionCollectionStorage storage $$ = _singleEditionCollectionStorage();

        uint128 cost;
        if (extension != address(0)) {
            if (!$.extensions[extension]) revert InvalidExtension();
            cost = ICollectionExtension(extension).approveMint({ operator: msg.sender, account: to, data: data });
        } else {
            // check gate ~ if gate is enabled, must be minted via minter
            if ($.gate) revert GatedMint();

            // set cost
            cost = $$.mintParams.price;
        }

        return _mint_(to, cost);
    }

    /* -------------------------------------------- */
    /* admin                                        */
    /* -------------------------------------------- */

    /**
     * @inheritdoc ICollection
     */
    function updateMintParams(bytes calldata mintParams) external override onlyOwner {
        CollectionData.SingleEditionCollectionStorage storage $$ = _singleEditionCollectionStorage();

        // decode mint params
        (CollectionData.SingleEditionMintParams memory p) =
            abi.decode(mintParams, (CollectionData.SingleEditionMintParams));

        // set mint params
        $$.mintParams = p;
    }

    /* -------------------------------------------- */
    /* internal                                     */
    /* -------------------------------------------- */

    /**
     * @notice intialize SingleEditionCollection
     * @param params encoded parameters
     */
    function _createCollection(bytes calldata params) internal override {
        CollectionStorage storage $ = _collectionStorage();
        CollectionData.SingleEditionCollectionStorage storage $$ = _singleEditionCollectionStorage();

        // decode params
        (
            string memory name,
            string memory symbol,
            address curator,
            string memory uri,
            uint128 price_,
            address currency,
            uint40 mintStart,
            uint40 mintEnd,
            address itemTarget,
            uint256[] memory itemIds
        ) = abi.decode(params, (string, string, address, string, uint128, address, uint40, uint40, address, uint256[]));

        // validate item target is roux edition
        if (!_rouxEditionFactory.isEdition(itemTarget)) revert InvalidItems();

        // validate items exist + same currency
        for (uint256 i = 0; i < itemIds.length; i++) {
            if (itemIds[i] == 0 || !IRouxEdition(itemTarget).exists(itemIds[i])) revert InvalidItems();

            if (IRouxEdition(itemTarget).currency() != currency) revert InvalidItems();
        }

        // set mintParams
        $$.mintParams =
            CollectionData.SingleEditionMintParams({ price: price_, mintStart: mintStart, mintEnd: mintEnd });

        // store item target
        $.itemTargets = new address[](1);
        $.itemTargets[0] = itemTarget;

        // set state vars
        $.name = name;
        $.symbol = symbol;
        $.curator = curator;
        $.uri = uri;
        $.currency = currency;
        $.itemIds = itemIds;
        $.gate = false;
    }

    /**
     * @notice internal function mint collection nft
     * @param to address to mint to
     */
    function _mint_(address to, uint256 cost) internal returns (uint256) {
        CollectionStorage storage $ = _collectionStorage();

        // increment token id
        uint256 collectionTokenId = ++$.tokenIds;

        // mint collection nft
        _mint(to, collectionTokenId);

        // erc 6551
        address account = _erc6551Registry.createAccount(
            _accountImplementation, ROUX_SINGLE_EDITION_COLLECTION_SALT, block.chainid, address(this), collectionTokenId
        );

        // transfer payment
        IERC20($.currency).safeTransferFrom(msg.sender, address(this), cost);

        // approve edition to spend funds
        IERC20($.currency).approve(address($.itemTargets[0]), cost);

        // mint to collection nft token bound account
        IRouxEdition($.itemTargets[0]).collectionSingleMint(account, $.itemIds, cost, "");

        return collectionTokenId;
    }
}
