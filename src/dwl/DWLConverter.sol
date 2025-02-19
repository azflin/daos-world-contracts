// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DWLConverter {
    address public oldDwl;
    address public newDwl;

    constructor(address _oldDwl, address _newDwl) {
        oldDwl = _oldDwl;
        newDwl = _newDwl;
    }

    function swapOldForNew(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");

        // Transfer old tokens from user to this contract
        require(IERC20(oldDwl).transferFrom(msg.sender, address(this), amount), "Old token transfer failed");

        // Transfer new tokens to user
        require(IERC20(newDwl).transfer(msg.sender, amount * 1000000), "New token transfer failed");
    }
}
