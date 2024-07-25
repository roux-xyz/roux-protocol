// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IRegistry {
    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    /**
     * @notice get attribution data
     * @param edition edition
     * @param tokenId token id
     */
    function attribution(address edition, uint256 tokenId) external view returns (address, uint256);

    /**
     * @notice get root edition for a given edition
     * @param edition edition
     * @param tokenId token id
     * @return root edition
     * @return root tokenId
     * @return depth of edition
     */
    function root(address edition, uint256 tokenId) external view returns (address, uint256, uint256);

    /**
     * @notice check if edition has a child
     * @param edition edition
     * @param tokenId token id
     */
    function hasChild(address edition, uint256 tokenId) external view returns (bool);

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /**
     * @notice set attribution for an edition and tokenId
     * @param tokenId token id
     * @param parentEdition parent contract
     * @param parentTokenId parent token id
     *
     * @dev this should be called by the edition contract, as the attribution mapping
     *       is keyed by the edition contract address and token id
     */
    function setRegistryData(uint256 tokenId, address parentEdition, uint256 parentTokenId) external;
}
