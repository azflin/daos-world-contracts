//SPDX-License-Identifier: None
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ISniperManager} from "../interfaces/ISniperManager.sol";

contract AntiSniperERC20 is ERC20 {
    ISniperManager public immutable sniperManager;

    constructor(string memory name, string memory symbol, uint256 supply, address _sniperManager) ERC20(name, symbol) {
        sniperManager = ISniperManager(_sniperManager);
        _mint(msg.sender, supply);
    }

    function _update(address from, address to, uint256 value) internal override {
        if (sniperManager.isSniper(from)) {
            revert("You got honey trapped. No sniping allowed");
        }
        super._update(from, to, value);
    }
}
