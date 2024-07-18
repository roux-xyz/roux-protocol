// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;

import { IRouxEditionFactory } from "src/interfaces/IRouxEditionFactory.sol";

/* -------------------------------------------- */
/* Edition                                      */
/* -------------------------------------------- */

library EditionData {
    /**
     * @notice mint params
     * @param defaultPrice default price
     * @param mintStart mint start
     * @param mintEnd mint end
     * @param gate whether to gate minting
     */
    struct MintParams {
        uint128 defaultPrice;
        uint40 mintStart;
        uint40 mintEnd;
        bool gate;
    }

    /**
     * @notice token data
     * @param creator creator
     * @param maxSupply max supply
     * @param totalSupply total supply
     * @param mintParams mint params
     * @param extensions mapping of extension addresses to their enabled status
     * @param uri token uri
     */
    struct TokenData {
        address creator;
        uint128 totalSupply;
        uint128 maxSupply;
        MintParams mintParams;
        mapping(address extension => bool enable) extensions;
        string uri;
    }

    /**
     * @notice add params
     * @param tokenUri token uri
     * @param creator creator
     * @param maxSupply max supply
     * @param fundsRecipient funds recipient
     * @param defaultPrice base price - typically overriden by extension
     * @param mintStart mint start
     * @param mintEnd mint end
     * @param profitShare profit share
     * @param parentEdition parent edition - address(0) if root
     * @param parentTokenId parent token id - 0 if root
     * @param extension extension - must be previously set to add token
     * @param options additional options
     */
    struct AddParams {
        string tokenUri;
        address creator;
        uint256 maxSupply;
        address fundsRecipient;
        uint256 defaultPrice;
        uint40 mintStart;
        uint40 mintEnd;
        uint256 profitShare;
        address parentEdition;
        uint256 parentTokenId;
        address extension;
        bytes options;
    }
}

/* -------------------------------------------- */
/* Collections                                  */
/* -------------------------------------------- */

library CollectionData {
    enum CollectionType {
        None,
        SingleEdition,
        MultiEdition
    }

    /**
     * @notice mint params
     * @param price price
     * @param mintStart mint start
     * @param mintEnd mint end
     */
    struct SingleEditionMintParams {
        uint128 price;
        uint40 mintStart;
        uint40 mintEnd;
    }

    /**
     * @notice Collection storage
     * @custom:storage-location erc7201:singleEditionCollection.singleEditionCollectionStorage
     * @param fundsRecipient funds recipient address
     * @param mintParams mint parameters
     */
    struct SingleEditionCollectionStorage {
        SingleEditionMintParams mintParams;
    }

    /**
     * @notice single edition create params
     * @param name collection name
     * @param symbol collection symbol
     * @param curator curator address
     * @param uri collection URI
     * @param price price
     * @param currency currency
     * @param mintStart mint start
     * @param mintEnd mint end
     * @param itemTarget item target
     * @param itemIds item ids
     */
    struct SingleEditionCreateParams {
        string name;
        string symbol;
        address curator;
        string uri;
        uint128 price;
        address currency;
        uint40 mintStart;
        uint40 mintEnd;
        address itemTarget;
        uint256[] itemIds;
    }

    /**
     * @notice mint params
     * @param mintStart mint start
     * @param mintEnd mint end
     */
    struct MultiEditionMintParams {
        uint40 mintStart;
        uint40 mintEnd;
    }

    /**
     * @notice Collection storage
     * @custom:storage-location erc7201:multiEditionCollection.multiEditionCollectionStorage
     * @param fundsRecipient funds recipient address
     * @param mintParams mint parameters
     */
    struct MultiEditionCollectionStorage {
        MultiEditionMintParams mintParams;
        address rewardsRecipient;
    }

    /**
     * @notice multi edition create params
     * @param name collection name
     * @param symbol collection symbol
     * @param curator curator address
     * @param rewardsRecipient rewards recipient address
     * @param uri collection URI
     * @param currency currency
     * @param mintStart mint start
     * @param mintEnd mint end
     * @param itemTargets item targets
     * @param itemIds item ids
     */
    struct MultiEditionCreateParams {
        string name;
        string symbol;
        address curator;
        address rewardsRecipient;
        string uri;
        address currency;
        uint40 mintStart;
        uint40 mintEnd;
        address[] itemTargets;
        uint256[] itemIds;
    }
}
