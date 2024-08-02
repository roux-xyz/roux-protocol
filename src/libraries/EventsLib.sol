// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.26;

import { CollectionData } from "src/types/DataTypes.sol";

library EventsLib {
    /* ------------------------------------------------- */
    /* RouxEdition                                       */
    /* ------------------------------------------------- */

    /**
     * @notice emitted when a token is added
     * @param id token id
     */
    event TokenAdded(uint256 indexed id);

    /**
     * @notice emitted when an extension is added
     * @param extension extension address
     * @param id token id
     * @param enable extension enabled or disabled
     */
    event ExtensionSet(address indexed extension, uint256 indexed id, bool enable);

    /**
     * @notice emitted when a collection is set
     * @param collection collection address
     * @param enable enable or disable collection
     */
    event CollectionSet(address indexed collection, bool enable);

    /**
     * @notice emitted when a contract uri is updated
     * @param newContractUri new contract uri
     */
    event ContractURIUpdated(string newContractUri);

    /**
     * @notice emitted when the default price is updated
     * @param id token id
     * @param newDefaultPrice new default price
     */
    event DefaultPriceUpdated(uint256 indexed id, uint256 newDefaultPrice);

    /**
     * @notice emitted when the mint gate is updated
     * @param id token id
     */
    event GateDisabled(uint256 indexed id);

    /* ------------------------------------------------- */
    /* Controller                                        */
    /* ------------------------------------------------- */

    /**
     * @notice emitted when funds are deposited
     * @param edition edition address
     * @param tokenId token id
     * @param recipient recipient of the funds
     * @param amount amount deposited
     */
    event Deposited(address indexed edition, uint256 indexed tokenId, address indexed recipient, uint256 amount);

    /**
     * @notice emitted when pending balance is updated
     * @param parent parent edition address
     * @param parentTokenId parent token id
     * @param amount amount pending balance is updated with
     */
    event PendingUpdated(address parent, uint256 indexed parentTokenId, uint256 amount);

    /**
     * @notice emitted when pending balance is distributed
     * @param edition edition address
     * @param tokenId token id
     * @param amount amount pending balance is updated with
     */
    event PendingDistributed(address indexed edition, uint256 indexed tokenId, uint256 amount);

    /**
     * @notice emitted when funds are recorded
     * @param operator operator address
     * @param recipient recipient address
     * @param amount amount
     */
    event FundsRecorded(address indexed operator, address indexed recipient, uint256 amount);

    /**
     * @notice emitted when funds are withdrawn
     * @param recipient recipient of the withdrawal
     * @param amount amount withdrawn
     */
    event Withdrawn(address indexed recipient, uint256 amount);

    /**
     * @notice emitted when funds recipient is updated
     * @param edition edition address
     * @param tokenId token id
     * @param fundsRecipient funds recipient address
     */
    event FundsRecipientUpdated(address indexed edition, uint256 indexed tokenId, address indexed fundsRecipient);

    /**
     * @notice emitted when profit share is updated
     * @param edition edition address
     * @param tokenId token id
     * @param profitShare profit share
     */
    event ProfitShareUpdated(address indexed edition, uint256 indexed tokenId, uint16 profitShare);

    /**
     * @notice emitted when platform fee status is updated
     * @param enabled whether the platform fee is enabled
     */
    event PlatformFeeUpdated(bool enabled);

    /**
     * @notice emitted when the contract is paused
     * @param pause_ whether the contract is paused
     */
    event Paused(bool pause_);

    /* ------------------------------------------------- */
    /* Collection                                        */
    /* ------------------------------------------------- */

    /**
     * @notice emitted when a collection is minted
     * @param tokenId token id
     * @param to recipient
     * @param account account
     */
    event CollectionMinted(uint256 indexed tokenId, address indexed to, address indexed account);

    /**
     * @notice emitted when an extension is added to a collection
     * @param extension extension address
     * @param enable whether the extension is enabled or disabled
     */
    event ExtensionSet(address indexed extension, bool enable);

    /**
     * @notice emitted when a collection extension mint params are updated
     * @param extension extension
     * @param mintParams mint params
     */
    event ExtensionMintParamsUpdated(address indexed extension, bytes mintParams);

    /**
     * @notice emitted when a collection price is updated
     * @param collection collection address
     * @param newPrice new collection price
     */
    event CollectionPriceUpdated(address indexed collection, uint256 newPrice);

    /**
     * @notice emitted when a collection uri is updated
     * @param newUri new uri
     */
    event UriUpdated(string newUri);

    /* ------------------------------------------------- */
    /* Registry                                          */
    /* ------------------------------------------------- */

    /**
     * @notice disbursement
     * @param edition edition
     * @param tokenId token id
     * @param parentEdition parent edition
     * @param parentTokenId parent token id
     */
    event RegistryUpdated(
        address indexed edition, uint256 indexed tokenId, address indexed parentEdition, uint256 parentTokenId
    );

    /* ------------------------------------------------- */
    /* RouxEditionFactory                                */
    /* ------------------------------------------------- */

    /**
     * @notice new edition
     * @param instance edition instance
     */
    event NewEdition(address indexed instance);

    /* ------------------------------------------------- */
    /* CollectionFactory                                 */
    /* ------------------------------------------------- */

    /**
     * @notice new single edition collection
     * @param instance collection instance
     */
    event NewSingleEditionCollection(address indexed instance);

    /**
     * @notice new multi edition collection
     * @param instance collection instance
     */
    event NewMultiEditionCollection(address indexed instance);
}
