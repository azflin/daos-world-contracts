// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DaosWorldWhitelistToken is ERC20, Ownable {
    // Fixed token name, symbol, and supply
    string private constant TOKEN_NAME = "Daos World Whitelist Token";
    string private constant TOKEN_SYMBOL = "DWL";
    uint256 private constant INITIAL_SUPPLY = 100_000_000 * 10 ** 18;

    constructor() ERC20(TOKEN_NAME, TOKEN_SYMBOL) Ownable(msg.sender) {
        // Mint the fixed initial supply to the deployer
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    /**
     * @notice Allows the owner to mint new tokens.
     * @param account The address to receive the minted tokens.
     * @param amount The number of tokens to mint.
     */
    function mint(address account, uint256 amount) external onlyOwner {
        _mint(account, amount);
    }
}
