//SPDX-License-Identifier: None
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract SniperManager is Ownable {
    mapping(address => bool) public isSniper;

    constructor() Ownable(msg.sender) {}

    function toggleSniper(address sniper, bool status) external onlyOwner {
        isSniper[sniper] = status;
    }
}
