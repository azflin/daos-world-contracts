// SPDX-License-Identifier: MIT
pragma solidity >=0.8.00;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

library PriceHelper {
    /// @notice Calculates the sqrtPriceX96 for Uniswap V3 pool initialization
    /// @param tokenSupply The total supply of the token
    /// @param marketCapInWeth The desired market cap in WETH
    /// @param wethIsToken0 Whether WETH is token0 in the pool
    /// @return sqrtPriceX96 The square root price as Q64.96
    function calculateSqrtPriceX96(uint256 tokenSupply, uint256 marketCapInWeth, bool wethIsToken0)
        public
        pure
        returns (uint160)
    {
        // Calculate price = marketCapInWeth / tokenSupply
        // If WETH is token0, we need the inverse of the price
        uint256 price;
        if (wethIsToken0) {
            // price = tokenSupply / marketCapInWeth (tokens per WETH)
            price = (tokenSupply * 1e18) / marketCapInWeth;
        } else {
            // price = marketCapInWeth / tokenSupply (WETH per token)
            price = (marketCapInWeth * 1e18) / tokenSupply;
        }

        // Convert price to sqrtPrice
        uint256 sqrtPrice = Math.sqrt(price * 1e18);

        // Convert sqrtPrice to sqrtPriceX96
        uint160 sqrtPriceX96 = uint160((sqrtPrice * (1 << 96)) / 1e18);

        return sqrtPriceX96;
    }
}
