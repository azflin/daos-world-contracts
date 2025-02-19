// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ISniperManager} from "./interfaces/ISniperManager.sol";

contract DaosWorldV2Token is ERC20, Ownable {
    ISniperManager public immutable sniperManager;

    constructor(string memory _name, string memory _symbol, address _sniperManager)
        ERC20(_name, _symbol)
        Ownable(msg.sender)
    {
        sniperManager = ISniperManager(_sniperManager);
    }

    function mint(address _to, uint256 _amount) external onlyOwner {
        _mint(_to, _amount);
    }

    function _update(address from, address to, uint256 value) internal override {
        if (sniperManager.isSniper(from)) {
            revert("You got honey trapped. No sniping allowed");
        }
        super._update(from, to, value);
    }
}
