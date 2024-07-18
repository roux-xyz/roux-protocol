// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ERC721 } from "solady/tokens/ERC721.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ReentrancyGuard } from "solady/utils/ReentrancyGuard.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Collection } from "src/Collection.sol";

import { ICollection } from "src/interfaces/ICollection.sol";
import { IERC6551Registry } from "erc6551/interfaces/IERC6551Registry.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { IRouxEditionFactory } from "src/interfaces/IRouxEditionFactory.sol";
import { IController } from "src/interfaces/IController.sol";
import { ICollectionExtension } from "src/interfaces/ICollectionExtension.sol";

import { CollectionData } from "src/types/DataTypes.sol";

/**
 * @title Single Edition Collection
 * @author Roux
 */
contract MultiEditionCollection is Collection {
    using SafeERC20 for IERC20;

    /* -------------------------------------------- */
    /* constants                                    */
    /* -------------------------------------------- */

    /**
     * @notice multi edition collection storage slot
     * @dev keccak256(abi.encode(uint256(keccak256("multiEditionCollection.multiEditionCollectionStorage")) - 1)) &
     * ~bytes32(uint256(0xff));
     */
    bytes32 internal constant MULTI_EDITION_COLLECTION_STORAGE_SLOT =
        0x80f0f9485e96d2fa1d83203f8bbee993202c4d0ad979d7d0de8ea7e7c4dcbd00;

    /**
     * @notice controller
     */
    IController internal immutable _controller;

    /**
     * @notice collection salt used for erc6551 implementation
     */
    bytes32 internal constant ROUX_MULTI_EDITION_COLLECTION_SALT = keccak256("ROUX_MULTI_EDITION_COLLECTION");

    /* -------------------------------------------- */
    /* constructor                                  */
    /* -------------------------------------------- */

    /**
     * @notice constructor
     * @param erc6551registry registry
     * @param accountImplementation initial erc6551 account implementation
     * @param rouxEditionFactory roux edition factory
     * @param controller controller
     */
    constructor(
        address erc6551registry,
        address accountImplementation,
        address rouxEditionFactory,
        address controller
    )
        Collection(erc6551registry, accountImplementation, rouxEditionFactory)
    {
        _controller = IController(controller);
    }

    /* -------------------------------------------- */
    /* storage                                      */
    /* -------------------------------------------- */

    /**
     * @notice MultiEditionCollection storage
     * @return $$ MultiEditionCollection storage location
     */
    function _multiEditionCollectionStorage()
        internal
        pure
        returns (CollectionData.MultiEditionCollectionStorage storage $$)
    {
        assembly {
            $$.slot := MULTI_EDITION_COLLECTION_STORAGE_SLOT
        }
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    function price() external view override returns (uint256) {
        return _price();
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

        if (extension != address(0)) {
            if (!$.extensions[extension]) revert InvalidExtension();
            ICollectionExtension(extension).approveMint({ operator: msg.sender, account: to, data: data });
        } else {
            // check gate ~ if gate is enabled, must be minted via minter
            if ($.gate) revert GatedMint();
        }

        return _mint(to);
    }

    /* -------------------------------------------- */
    /* admin                                        */
    /* -------------------------------------------- */

    /**
     * @inheritdoc ICollection
     */
    function updateMintParams(bytes calldata mintParams) external override onlyOwner {
        CollectionData.MultiEditionCollectionStorage storage $$ = _multiEditionCollectionStorage();

        // decode mint params
        (CollectionData.MultiEditionMintParams memory p) =
            abi.decode(mintParams, (CollectionData.MultiEditionMintParams));

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
        CollectionData.MultiEditionCollectionStorage storage $$ = _multiEditionCollectionStorage();

        // decode params
        (CollectionData.MultiEditionCreateParams memory p) =
            abi.decode(params, (CollectionData.MultiEditionCreateParams));

        // validate length
        if (p.itemTargets.length != p.itemIds.length) revert InvalidItems();

        // validate items, targets, minters
        for (uint256 i = 0; i < p.itemIds.length; i++) {
            if (!_rouxEditionFactory.isEdition(p.itemTargets[i])) revert InvalidItems();
            if (p.itemIds[i] == 0 || !IRouxEdition(p.itemTargets[i]).exists(p.itemIds[i])) revert InvalidItems();
            if (IRouxEdition(p.itemTargets[i]).currency() != p.currency) revert InvalidItems();
        }

        // set mintParams
        $$.mintParams = CollectionData.MultiEditionMintParams({ mintStart: p.mintStart, mintEnd: p.mintEnd });

        //$set rewards recipient
        $$.rewardsRecipient = p.rewardsRecipient;

        // set state vars
        $.name = p.name;
        $.symbol = p.symbol;
        $.curator = p.curator;
        $.uri = p.uri;
        $.currency = p.currency;
        $.itemTargets = p.itemTargets;
        $.itemIds = p.itemIds;
        $.gate = false;
    }

    /**
     * @notice get price for collection
     * @return price
     */
    function _price() internal view returns (uint256) {
        CollectionStorage storage $ = _collectionStorage();

        uint256 total;
        for (uint256 i = 0; i < $.itemTargets.length; i++) {
            total += IRouxEdition($.itemTargets[i]).defaultPrice($.itemIds[i]);
        }

        return total;
    }

    /**
     * @notice internal function mint collection nft
     * @param to address to mint to
     */
    function _mint(address to) internal returns (uint256) {
        CollectionStorage storage $ = _collectionStorage();
        CollectionData.MultiEditionCollectionStorage storage $$ = _multiEditionCollectionStorage();

        // increment token id
        uint256 collectionTokenId = ++$.tokenIds;

        // mint collection nft
        _mint(to, collectionTokenId);

        // erc 6551
        address account = _erc6551Registry.createAccount(
            _accountImplementation, ROUX_MULTI_EDITION_COLLECTION_SALT, block.chainid, address(this), collectionTokenId
        );

        // total price
        uint256 totalPrice = _price();

        // transfer payment
        IERC20($.currency).safeTransferFrom(msg.sender, address(this), totalPrice);

        // initialize referral rewards variable
        uint256 totalReferralRewards;

        // mint
        for (uint256 i = 0; i < $.itemTargets.length; i++) {
            // get token price
            uint256 cost = IRouxEdition($.itemTargets[i]).defaultPrice($.itemIds[i]);

            // compute referral reward
            uint256 referralReward = cost * _controller.COLLECTION_FEE() / 10_000;

            // increment total referral rewards
            totalReferralRewards += referralReward;

            // mint addition to token bound account
            IRouxEdition($.itemTargets[i]).collectionMultiMint(account, $.itemIds[i], cost - referralReward, "");
        }

        // record referral rewards for collection
        _controller.recordFunds($$.rewardsRecipient, totalReferralRewards);

        return collectionTokenId;
    }
}
