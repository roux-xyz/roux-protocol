// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.25;

abstract contract Events {
    /* -------------------------------------------- */
    /* Controller                                   */
    /* -------------------------------------------- */

    event Disbursement(address indexed edition, uint256 indexed tokenId, uint256 amount);
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
    event MinterAdded(address indexed minter, uint256 indexed id);
    event MinterRemoved(address indexed minter, uint256 indexed id);

    /* -------------------------------------------- */
    /* EditionFactory                               */
    /* -------------------------------------------- */
    event NewEdition(address indexed instance);

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
