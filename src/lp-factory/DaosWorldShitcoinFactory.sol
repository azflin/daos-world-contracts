// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// External imports
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Interfaces
import {IUniswapV3Factory, IUniswapV3Pool, INonfungiblePositionManager} from "../interfaces/IUniswap.sol";

// Libraries
import {PriceHelper} from "../lib/PriceHelper.sol";

// Contracts
import {DaosWorldShitcoin} from "./DaosWorldShitcoin.sol";

/**
 * @title DaosWorldShitcoinFactory
 * @notice Factory contract for creating ERC20 tokens with automatic Uniswap V3 liquidity provision
 * @dev Creates tokens and adds initial WETH/Token liquidity pairs with:
 * - 1% fee tier
 * - Full range liquidity (-887200 to 887200 ticks)
 * - Initial market cap of 30 ETH
 * - Configurable pool percentage (default 10%)
 */
contract DaosWorldShitcoinFactory is Ownable2Step {
    /// @notice Error thrown when the ETH amount sent does not match the required amount for liquidity
    error InvalidWethAmount();

    /// @notice Error thrown when a non-whitelisted address attempts to create a token
    error NotWhitelisted();

    /// @notice Error thrown when the pool percentage is greater than 100%
    error InvalidPoolPercent();

    /// @notice Error thrown when ETH transfer fails
    error EthTransferFailed();

    /// @notice Emitted when a new token is created and liquidity is added
    /// @param token Address of the newly created token
    /// @param treasury Address of the treasury receiving the remaining tokens
    /// @param supply Total supply of the created token
    /// @param positionId ID of the Uniswap V3 NFT position
    event TokenCreated(address indexed token, address indexed treasury, uint256 supply, uint256 positionId);

    /// @notice Divisor for calculating percentages
    uint256 internal constant DIVISOR = 10000;
    /// @notice Pool fee of 1% (10000 = 1%)
    uint24 internal constant FEE = 10000;

    /// @notice Address of the WETH token contract
    address public immutable WETH;
    /// @notice Address of Uniswap V3's NonFungiblePositionManager
    address public immutable NON_FUNGIBLE_POSITION_MANAGER;
    /// @notice Address of the Uniswap V3 Factory contract
    address public immutable UNISWAP_V3_FACTORY;

    /// @notice Whitelist of addresses that can create tokens
    mapping(address => bool) public whitelisted;

    /// @notice Percentage of tokens used for liquidity (in basis points)
    uint256 internal poolPercent;

    /// @notice Starting market cap of the token
    uint256 internal startingMcap;

    /**
     * @notice Initializes the factory with required addresses
     * @param weth Address of the WETH contract
     * @param nonFungiblePositionManager Address of Uniswap V3's NFT position manager
     * @param uniswapV3Factory Address of Uniswap V3 factory
     */
    constructor(address weth, address nonFungiblePositionManager, address uniswapV3Factory) Ownable(msg.sender) {
        WETH = weth;
        NON_FUNGIBLE_POSITION_MANAGER = nonFungiblePositionManager;
        UNISWAP_V3_FACTORY = uniswapV3Factory;
        poolPercent = 1000;
        startingMcap = 30e18;
    }

    /// @notice Modifier to check if the caller is whitelisted
    modifier onlyWhitelisted() {
        if (!whitelisted[msg.sender]) revert NotWhitelisted();
        _;
    }

    /**
     * @notice Creates a new ERC20 token and adds initial liquidity to Uniswap V3
     * @dev The function:
     * 1. Creates new ERC20 token
     * 2. Creates Uniswap V3 pool with 1% fee
     * 3. Adds liquidity across full range and mints position NFT to treasury
     * 4. Transfers remaining tokens to treasury (msg.sender)
     * @param name Name of the new token
     * @param symbol Symbol of the new token
     * @param supply Total supply of the new token
     * @return token Address of the created token
     * @return positionId ID of the Uniswap V3 NFT position
     */
    function createTokenAndAddLiquidity(string memory name, string memory symbol, uint256 supply)
        external
        payable
        onlyWhitelisted
        returns (address token, uint256 positionId)
    {
        uint256 tokenAmountForLiquidity = (supply * poolPercent) / DIVISOR;
        uint256 wethAmountForLiquidity = (startingMcap * poolPercent) / DIVISOR;
        if (msg.value != wethAmountForLiquidity) revert InvalidWethAmount();
        address treasury = msg.sender;

        uint256 initialBalance = address(this).balance - msg.value;

        token = _createToken(name, symbol, supply);

        // calculate sqrtPriceX96 based on token supply and market cap
        uint160 sqrtPriceX96 = PriceHelper.calculateSqrtPriceX96(supply, startingMcap, WETH < token);

        positionId = _addLiquidity(token, wethAmountForLiquidity, tokenAmountForLiquidity, treasury, sqrtPriceX96);

        // using token balance to transfer to treasury as there's a possibility tokens
        // are left over from the liquidity portion

        uint256 remainingTokens = IERC20(token).balanceOf(address(this));

        IERC20(token).transfer(treasury, remainingTokens);

        emit TokenCreated(token, treasury, supply, positionId);

        // Return any unused ETH back to treasury
        uint256 finalBalance = address(this).balance;
        uint256 unusedEth = finalBalance - initialBalance;
        if (unusedEth > 0) {
            (bool success,) = treasury.call{value: unusedEth}("");
            if (!success) revert EthTransferFailed();
        }
    }

    /**
     * @notice Internal function to create a new DaosWorldShitcoin contract
     * @param name Name of the token
     * @param symbol Symbol of the token
     * @param supply Total supply to mint
     * @return Address of the newly created token
     */
    function _createToken(string memory name, string memory symbol, uint256 supply) internal returns (address) {
        DaosWorldShitcoin token = new DaosWorldShitcoin(name, symbol, supply);
        return address(token);
    }

    /**
     * @notice Internal function to add liquidity to Uniswap V3 for a token/WETH pair
     * @dev Creates a full range position (-887200 to 887200 ticks) with 1% fee tier
     * The function:
     * 1. Creates new Uniswap V3 pool
     * 2. Initializes pool with calculated sqrt price
     * 3. Adds liquidity and mints position NFT to treasury
     * @param token Address of the token to pair with WETH
     * @param wethAmount Amount of WETH to add as liquidity
     * @param tokenAmount Amount of tokens to add as liquidity
     * @param treasury Address that will receive the liquidity position NFT
     * @param sqrtPriceX96 Initial sqrt price for the pool (calculated based on desired market cap)
     * @return positionId The ID of the minted Uniswap V3 NFT position
     */
    function _addLiquidity(
        address token,
        uint256 wethAmount,
        uint256 tokenAmount,
        address treasury,
        uint160 sqrtPriceX96
    ) internal returns (uint256 positionId) {
        address pool = IUniswapV3Factory(UNISWAP_V3_FACTORY).createPool(token, WETH, FEE);

        // Full range position ticks for 1% fee pool
        int24 tickLower = -887200;
        int24 tickUpper = 887200;

        IUniswapV3Pool(pool).initialize(sqrtPriceX96);

        uint256 amount0;
        uint256 amount1;
        address token0;
        address token1;
        if (token < WETH) {
            amount0 = tokenAmount;
            amount1 = wethAmount;
            token0 = token;
            token1 = WETH;
        } else {
            amount0 = wethAmount;
            amount1 = tokenAmount;
            token0 = WETH;
            token1 = token;
        }

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams(
            token0, token1, FEE, tickLower, tickUpper, amount0, amount1, 0, 0, treasury, block.timestamp + 10
        );

        IERC20(token).approve(address(NON_FUNGIBLE_POSITION_MANAGER), tokenAmount);
        (positionId,,,) = INonfungiblePositionManager(NON_FUNGIBLE_POSITION_MANAGER).mint{value: wethAmount}(params);
    }

    /**
     * @notice Adds an address to the whitelist
     * @dev Only callable by the contract owner
     * @param addr The address to add to the whitelist
     */
    function addToWhitelist(address addr) external onlyOwner {
        whitelisted[addr] = true;
    }

    /**
     * @notice Sets the percentage of tokens to be used for liquidity
     * @dev Percentage is in basis points (e.g., 1000 = 10%)
     * @param percent New pool percentage in basis points
     */
    function setPoolPercent(uint256 percent) external onlyOwner {
        if (percent > DIVISOR) revert InvalidPoolPercent();
        poolPercent = percent;
    }

    /**
     * @notice Updates the starting market cap used for token liquidity calculations
     * @param mcap New starting market cap value in wei
     */
    function setStartingMcap(uint256 mcap) external onlyOwner {
        startingMcap = mcap;
    }

    /**
     * @notice Calculates the required WETH amount for liquidity based on starting market cap and pool percentage
     * @dev Uses startingMcap and poolPercent to determine WETH contribution to the liquidity pool
     * @return uint256 Amount of WETH required for liquidity provision
     */
    function getWethAmountForLiquidity() internal view returns (uint256) {
        return (startingMcap * poolPercent) / DIVISOR;
    }
}
