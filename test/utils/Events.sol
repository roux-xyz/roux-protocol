// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.25;

abstract contract Events {
    /* -------------------------------------------- */
    /* Controller                                   */
    /* -------------------------------------------- */

    event Deposited(address indexed recipient, uint256 amount);
    event PendingUpdated(
        address edition, uint256 indexed tokenId, address parent, uint256 indexed parentTokenId, uint256 amount
    );
    event Withdrawn(address indexed edition, uint256 indexed tokenId, address indexed to, uint256 amount);
    event WithdrawnBatch(address indexed edition, uint256[] indexed tokenIds, address indexed to, uint256 amount);
    event PlatformFeeUpdated(bool enabled);

    /* -------------------------------------------- */
    /* Registry                                     */
    /* -------------------------------------------- */
    event RegistryUpdated(
        address indexed edition, uint256 indexed tokenId, address indexed parentEdition, uint256 parentTokenId
    );

    /* -------------------------------------------- */
    /* Edition                                      */
    /* -------------------------------------------- */
    event TokenAdded(uint256 indexed id);
    event ExtensionSet(address indexed extension, uint256 indexed id, bool enable);
    event CollectionSet(address indexed collection, uint256 collectionId, bool enable);
    event ContractURIUpdated(string newContractUri);
    event DefaultPriceUpdated(uint256 indexed id, uint256 newDefaultPrice);
    event MintGated(uint256 indexed id, bool gate);

    /* -------------------------------------------- */
    /* EditionFactory                               */
    /* -------------------------------------------- */
    event NewEdition(address indexed instance);

    /* -------------------------------------------- */
    /* IExtension                                */
    /* -------------------------------------------- */

    event MintParamsUpdated(address indexed edition, uint256 indexed id, bytes mintParams);

    /* -------------------------------------------- */
    /* ERC-1155                                     */
    /* -------------------------------------------- */

    event TransferSingle(
        address indexed operator, address indexed from, address indexed to, uint256 id, uint256 amount
    );
    event TransferBatch(
        address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] amounts
    );
    event ApprovalForAll(address indexed owner, address indexed operator, bool isApproved);
    event URI(string value, uint256 indexed id);
}
