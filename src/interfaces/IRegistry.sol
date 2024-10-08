// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

interface IRegistry {
    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    /**
     * @notice get attribution data
     * @param edition edition
     * @param tokenId token id
     * @return parent edition
     * @return parent token id
     * @return index
     */
    function attribution(address edition, uint256 tokenId) external view returns (address, uint256, uint256);

    /**
     * @notice get root edition for a given edition
     * @param edition edition
     * @param tokenId token id
     * @return root edition
     * @return root tokenId
     * @return depth of edition
     */
    function root(address edition, uint256 tokenId) external view returns (address, uint256, uint256);

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /**
     * @notice set attribution for an edition and tokenId
     * @param tokenId token id
     * @param parentEdition parent contract
     * @param parentTokenId parent token id
     * @param index index
     *
     * @dev this should be called by the edition contract, as the attribution mapping
     *       is keyed by the edition contract address and token id
     */
    function setRegistryData(uint256 tokenId, address parentEdition, uint256 parentTokenId, uint256 index) external;
}
