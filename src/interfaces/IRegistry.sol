// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IRegistry {
    /* -------------------------------------------- */
    /* errors                                       */
    /* -------------------------------------------- */
    /**
     * @notice max depth exceeded
     */
    error MaxDepthExceeded();

    /**
     * @notice invalid attribution edition
     */
    error InvalidAttribution();

    /* -------------------------------------------- */
    /* events                                       */
    /* -------------------------------------------- */

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

    /* -------------------------------------------- */
    /* structures                                   */
    /* -------------------------------------------- */

    /**
     * @notice attribution data
     */
    struct RegistryData {
        address parentEdition;
        uint256 parentTokenId;
    }

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
