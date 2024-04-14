// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IRouxEditionFactory {
    /* -------------------------------------------- */
    /* errors                                       */
    /* -------------------------------------------- */

    error OnlyAllowlist();

    /* -------------------------------------------- */
    /* events                                       */
    /* -------------------------------------------- */

    event NewCreator(address indexed instance);

    /* -------------------------------------------- */
    /* view functions                               */
    /* -------------------------------------------- */

    function isEdition(address token) external view returns (bool);

    function getEditions() external view returns (address[] memory);
}
