// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;

import { IRouxEditionFactory } from "src/core/interfaces/IRouxEditionFactory.sol";
import { LibBitmap } from "solady/utils/LibBitmap.sol";

/* -------------------------------------------- */
/* Edition                                      */
/* -------------------------------------------- */

library EditionData {
    using LibBitmap for LibBitmap.Bitmap;

    enum EditionType {
        None,
        Standard,
        Community
    }

    /**
     * @notice mint params
     * @param defaultPrice default price
     * @param gate whether to gate minting
     */
    struct MintParams {
        uint128 defaultPrice;
        bool gate;
    }

    /**
     * @notice token data
     * @param creator creator
     * @param hasParent whether the token has a parent
     * @param maxSupply max supply
     * @param totalSupply total supply
     * @param mintParams mint params
     * @param extensions enabled extensions
     * @param uris token uris
     */
    struct TokenData {
        address creator;
        bool hasParent;
        uint128 totalSupply;
        uint128 maxSupply;
        MintParams mintParams;
        LibBitmap.Bitmap extensions;
        bytes32[] uris;
    }

    /**
     * @notice add params
     * @param ipfsHash ipfsHash
     * @param maxSupply max supply
     * @param fundsRecipient funds recipient
     * @param defaultPrice base price - typically overriden by extension
     * @param profitShare profit share
     * @param parentEdition parent edition - address(0) if root
     * @param parentTokenId parent token id - 0 if root
     * @param extension extension - must be previously set to add token
     * @param gate whether to gate minting - must be set on `add`
     * @param options additional options
     */
    struct AddParams {
        bytes32 ipfsHash;
        uint256 maxSupply;
        address fundsRecipient;
        uint256 defaultPrice;
        uint256 profitShare;
        address parentEdition;
        uint256 parentTokenId;
        address extension;
        bool gate;
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
     * @notice single edition create params
     * @param name collection name
     * @param symbol collection symbol
     * @param uri collection URI
     * @param price price
     * @param mintStart mint start
     * @param mintEnd mint end
     * @param itemTarget item target
     * @param itemIds item ids
     */
    struct SingleEditionCreateParams {
        string name;
        string symbol;
        string uri;
        uint128 price;
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
     * @notice multi edition create params
     * @param name collection name
     * @param symbol collection symbol
     *
     * @param collectionFeeRecipient rewards recipient address
     * @param uri collection URI
     * @param mintStart mint start
     * @param mintEnd mint end
     * @param itemTargets item targets
     * @param itemIds item ids
     */
    struct MultiEditionCreateParams {
        string name;
        string symbol;
        address collectionFeeRecipient;
        string uri;
        uint40 mintStart;
        uint40 mintEnd;
        address[] itemTargets;
        uint256[] itemIds;
    }
}
