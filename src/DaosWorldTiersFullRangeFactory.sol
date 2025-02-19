// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {DaosWorldTiersFullRange} from "./DaosWorldTiersFullRange.sol";

contract DaosWorldTiersFullRangeFactory is Ownable {
    address public constant WETH = 0x4200000000000000000000000000000000000006;

    bool public gatedDeployments = true;

    event DaosWorldCreated(address indexed dao);

    constructor() Ownable(msg.sender) {}

    function deployDao(DaosWorldTiersFullRange.DaoConfig calldata config) external returns (address) {
        if (gatedDeployments) {
            require(msg.sender == owner(), "Not authorized");
        }

        DaosWorldTiersFullRange dao = new DaosWorldTiersFullRange(config);

        emit DaosWorldCreated(address(dao));
        return address(dao);
    }

    function setGatedDeployments(bool _gatedDeployments) external onlyOwner {
        gatedDeployments = _gatedDeployments;
    }
}
