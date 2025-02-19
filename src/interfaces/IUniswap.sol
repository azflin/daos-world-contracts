// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IUniswapV3Factory {
    function createPool(address tokenA, address tokenB, uint24 fee) external returns (address pool);
    function enableFeeAmount(uint24 fee, int24 tickSpacing) external;
    function feeAmountTickSpacing(uint24) external view returns (int24);
    function getPool(address, address, uint24) external view returns (address);
    function owner() external view returns (address);
    function parameters()
        external
        view
        returns (address factory, address token0, address token1, uint24 fee, int24 tickSpacing);
    function setOwner(address _owner) external;
    function initialize(uint160 sqrtPriceX96) external;
}

interface INonfungiblePositionManager {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    struct IncreaseLiquidityParams {
        uint256 tokenId;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external view returns (bytes32);
    function WETH9() external view returns (address);
    function approve(address to, uint256 tokenId) external;
    function balanceOf(address owner) external view returns (uint256);
    function baseURI() external pure returns (string memory);
    function burn(uint256 tokenId) external;
    function collect(CollectParams memory params) external returns (uint256 amount0, uint256 amount1);
    function createAndInitializePoolIfNecessary(address token0, address token1, uint24 fee, uint160 sqrtPriceX96)
        external
        returns (address pool);
    function decreaseLiquidity(DecreaseLiquidityParams memory params)
        external
        returns (uint256 amount0, uint256 amount1);
    function factory() external view returns (address);
    function getApproved(uint256 tokenId) external view returns (address);
    function increaseLiquidity(IncreaseLiquidityParams memory params)
        external
        returns (uint128 liquidity, uint256 amount0, uint256 amount1);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function mint(MintParams memory params)
        external
        payable
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
    function multicall(bytes[] memory data) external returns (bytes[] memory results);
    function name() external view returns (string memory);
    function ownerOf(uint256 tokenId) external view returns (address);
    function permit(address spender, uint256 tokenId, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );
    function refundETH() external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) external;
    function selfPermit(address token, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
    function selfPermitAllowed(address token, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external;
    function selfPermitAllowedIfNecessary(address token, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s)
        external;
    function selfPermitIfNecessary(address token, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;
    function setApprovalForAll(address operator, bool approved) external;
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
    function sweepToken(address token, uint256 amountMinimum, address recipient) external;
    function symbol() external view returns (string memory);
    function tokenByIndex(uint256 index) external view returns (uint256);
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
    function tokenURI(uint256 tokenId) external view returns (string memory);
    function totalSupply() external view returns (uint256);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function uniswapV3MintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes memory data) external;
    function unwrapWETH9(uint256 amountMinimum, address recipient) external;
}

interface IUniswapV3Pool {
    function burn(int24 tickLower, int24 tickUpper, uint128 amount)
        external
        returns (uint256 amount0, uint256 amount1);
    function collect(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1);
    function collectProtocol(address recipient, uint128 amount0Requested, uint128 amount1Requested)
        external
        returns (uint128 amount0, uint128 amount1);
    function factory() external view returns (address);
    function fee() external view returns (uint24);
    function feeGrowthGlobal0X128() external view returns (uint256);
    function feeGrowthGlobal1X128() external view returns (uint256);
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes memory data) external;
    function increaseObservationCardinalityNext(uint16 observationCardinalityNext) external;
    function initialize(uint160 sqrtPriceX96) external;
    function liquidity() external view returns (uint128);
    function maxLiquidityPerTick() external view returns (uint128);
    function mint(address recipient, int24 tickLower, int24 tickUpper, uint128 amount, bytes memory data)
        external
        returns (uint256 amount0, uint256 amount1);
    function observations(uint256)
        external
        view
        returns (
            uint32 blockTimestamp,
            int56 tickCumulative,
            uint160 secondsPerLiquidityCumulativeX128,
            bool initialized
        );
    function observe(uint32[] memory secondsAgos)
        external
        view
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s);
    function positions(bytes32)
        external
        view
        returns (
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );
    function protocolFees() external view returns (uint128 token0, uint128 token1);
    function setFeeProtocol(uint8 feeProtocol0, uint8 feeProtocol1) external;
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );
    function snapshotCumulativesInside(int24 tickLower, int24 tickUpper)
        external
        view
        returns (int56 tickCumulativeInside, uint160 secondsPerLiquidityInsideX128, uint32 secondsInside);
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes memory data
    ) external returns (int256 amount0, int256 amount1);
    function tickBitmap(int16) external view returns (uint256);
    function tickSpacing() external view returns (int24);
    function ticks(int24)
        external
        view
        returns (
            uint128 liquidityGross,
            int128 liquidityNet,
            uint256 feeGrowthOutside0X128,
            uint256 feeGrowthOutside1X128,
            int56 tickCumulativeOutside,
            uint160 secondsPerLiquidityOutsideX128,
            uint32 secondsOutside,
            bool initialized
        );
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface ISwapRouter02 {
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }
}
