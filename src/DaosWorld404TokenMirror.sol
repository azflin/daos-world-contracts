//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DN404Mirror} from "dn404/src/DN404Mirror.sol";

/// @notice This is the ERC721 contract for the token.
contract DaosWorld404TokenMirror is DN404Mirror {
    /// @dev This constructor sets the `deployer` as the factory
    /// (TokenDistributionLib.sol) in our case.
    constructor() DN404Mirror(msg.sender) {}

    /// @dev Instead of `owner()`, pull owner from `tokenBaseURISetter()`.
    function _baseOwnerFunctionSelector() internal view virtual override returns (bytes4) {
        return bytes4(keccak256("tokenBaseURISetter()"));
    }
}
