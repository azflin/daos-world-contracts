// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DaosWorld404Token} from "../DaosWorld404Token.sol";
import {DaosWorld404TokenMirror} from "../DaosWorld404TokenMirror.sol";

library TokenDistributionLib {
    function deployToken(
        string memory name,
        string memory symbol,
        string memory nftUrl,
        uint256 maxNftSupply,
        address owner,
        address daoOwner,
        bytes32 salt
    ) external returns (DaosWorld404Token token) {
        DaosWorld404TokenMirror mirror = new DaosWorld404TokenMirror{salt: salt}();
        token = new DaosWorld404Token{salt: salt}();
        token.initialize(name, symbol, nftUrl, address(mirror), maxNftSupply, owner, owner, daoOwner);
    }
}
