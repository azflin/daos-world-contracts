// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {DaosWorldShitcoinFactory} from "../src/lp-factory/DaosWorldShitcoinFactory.sol";
import {DaosWorldShitcoin} from "../src/lp-factory/DaosWorldShitcoin.sol";
import {INonfungiblePositionManager} from "../src/interfaces/IUniswap.sol";
import {Treasury} from "./mocks/Treasury.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {FullMath} from "@uniswap/v3-core/contracts/libraries/FullMath.sol";

contract DaosWorldShitcoinFactoryTest is Test {
    error OwnableUnauthorizedAccount(address account);

    uint256 constant STARTING_MCAP = 30e18;
    uint256 constant DIVISOR = 10000;
    uint256 constant POOL_PERCENT = 1000;
    // Base Mainnet addresses
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant UNISWAP_V3_FACTORY = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;
    address constant POSITION_MANAGER = 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1;

    DaosWorldShitcoinFactory public factory;

    address public owner;
    address public user1;
    address public user2;
    Treasury public treasury;

    function setUp() public {
        // Fork mainnet
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));

        // Set up accounts
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        treasury = new Treasury();
        // Deploy contract as owner
        vm.startPrank(owner);
        factory = new DaosWorldShitcoinFactory(WETH, POSITION_MANAGER, UNISWAP_V3_FACTORY);
        vm.stopPrank();

        vm.deal(user1, 1000e18);
        vm.deal(user2, 1000e18);
        vm.deal(owner, 1000e18);
        vm.deal(address(treasury), 1000e18);
    }

    function test_InitialState() public {
        assertEq(factory.owner(), owner);
        assertEq(factory.WETH(), WETH);
        assertEq(factory.NON_FUNGIBLE_POSITION_MANAGER(), POSITION_MANAGER);
        assertEq(factory.UNISWAP_V3_FACTORY(), UNISWAP_V3_FACTORY);
    }

    function test_AddToWhitelist() public {
        vm.startPrank(owner);
        factory.addToWhitelist(user1);
        vm.stopPrank();

        assertTrue(factory.whitelisted(user1));
        assertFalse(factory.whitelisted(user2));
    }

    function test_AddToWhitelist_OnlyOwner() public {
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user1));
        factory.addToWhitelist(user2);
        vm.stopPrank();
    }

    function test_SetPoolPercent() public {
        uint256 newPercent = 2000; // 20%

        vm.startPrank(owner);
        factory.setPoolPercent(newPercent);
        vm.stopPrank();
    }

    function test_SetPoolPercent_OnlyOwner() public {
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user1));
        factory.setPoolPercent(2000);
        vm.stopPrank();
    }

    function test_SetPoolPercent_RevertIfInvalid() public {
        uint256 invalidPercent = 10001; // Greater than DIVISOR (10000)

        vm.startPrank(owner);
        vm.expectRevert(DaosWorldShitcoinFactory.InvalidPoolPercent.selector);
        factory.setPoolPercent(invalidPercent);
        vm.stopPrank();
    }

    function test_TransferOwnership() public {
        vm.startPrank(owner);
        factory.transferOwnership(user1);
        vm.stopPrank();

        // Ownership not transferred yet (2-step process)
        assertEq(factory.owner(), owner);
        assertEq(factory.pendingOwner(), user1);

        // Accept ownership
        vm.prank(user1);
        factory.acceptOwnership();

        assertEq(factory.owner(), user1);
    }

    function test_CreateTokenAndAddLiquidity() public {
        // Setup
        string memory name = "Test Token";
        string memory symbol = "TEST";
        uint256 supply = 1_000_000e18;

        // Calculate expected amounts based on contract constants
        uint256 tokenAmountForLiquidity = (supply * POOL_PERCENT) / DIVISOR;
        uint256 wethAmountForLiquidity = (STARTING_MCAP * POOL_PERCENT) / DIVISOR;

        // Whitelist user1
        vm.prank(owner);
        factory.addToWhitelist(address(treasury));

        // Create token and add liquidity
        vm.startPrank(address(treasury));
        (address tokenAddress, uint256 positionId) =
            factory.createTokenAndAddLiquidity{value: wethAmountForLiquidity}(name, symbol, supply);
        vm.stopPrank();

        // Verify token creation
        DaosWorldShitcoin token = DaosWorldShitcoin(tokenAddress);
        assertEq(token.name(), name);
        assertEq(token.symbol(), symbol);
        assertEq(token.totalSupply(), supply);

        // Verify token balances (using greater than to account for dust tokens left over from liquidity addition)
        assertGt(token.balanceOf(address(treasury)), supply - tokenAmountForLiquidity);

        // Verify Uniswap position
        (,,,,,,, uint128 liquidity,,,,) = INonfungiblePositionManager(POSITION_MANAGER).positions(positionId);
        assertGt(liquidity, 0); // Verify liquidity was added

        // check factory eth and token balance to be zero
        assertEq(address(factory).balance, 0, "Factory balance should be zero");
        console2.log(token.balanceOf(address(factory)));
        assertEq(token.balanceOf(address(factory)), 0, "Token balance of factory should be zero");
    }

    function test_RevertCreateTokenAndAddLiquidity_IfNotWhitelisted() public {
        vm.startPrank(user1);
        vm.expectRevert(DaosWorldShitcoinFactory.NotWhitelisted.selector);
        factory.createTokenAndAddLiquidity{value: 3e18}("Test", "TEST", 1_000_000e18);
        vm.stopPrank();
    }

    function test_RevertCreateTokenAndAddLiquidity_IfInvalidWethAmount() public {
        // Whitelist user1
        vm.prank(owner);
        factory.addToWhitelist(user1);

        // Try with incorrect ETH amount
        vm.startPrank(user1);
        vm.deal(user1, 5e18);

        vm.expectRevert(DaosWorldShitcoinFactory.InvalidWethAmount.selector);
        factory.createTokenAndAddLiquidity{value: 5e18}("Test", "TEST", 1_000_000e18);
        vm.stopPrank();
    }

    function test_SetStartingMcap() public {
        uint256 newMcap = 50e18;

        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user1));
        factory.setStartingMcap(newMcap);
        vm.stopPrank();

        vm.startPrank(owner);
        factory.setStartingMcap(newMcap);
        vm.stopPrank();

        // Create token and add liquidity with new mcap
        string memory name = "Test Token";
        string memory symbol = "TEST";
        uint256 supply = 1_000_000e18;
        uint256 wethAmountForLiquidity = (newMcap * POOL_PERCENT) / DIVISOR;

        // Whitelist treasury
        vm.prank(owner);
        factory.addToWhitelist(address(treasury));

        // Create token and add liquidity
        vm.startPrank(address(treasury));
        factory.createTokenAndAddLiquidity{value: wethAmountForLiquidity}(name, symbol, supply);
        vm.stopPrank();
    }

    function test_CreateTokenAndAddLiquidity_WithExistingBalance() public {
        string memory name = "Test Token";
        string memory symbol = "TEST";
        uint256 supply = 1_000_000e18;
        uint256 wethAmountForLiquidity = (STARTING_MCAP * POOL_PERCENT) / DIVISOR;

        // Send some initial ETH to factory
        vm.deal(address(factory), 1e18);
        uint256 initialFactoryBalance = address(factory).balance;

        // Whitelist treasury
        vm.prank(owner);
        factory.addToWhitelist(address(treasury));

        // Record treasury's initial balance
        uint256 initialTreasuryBalance = address(treasury).balance;

        // Create token and add liquidity
        vm.startPrank(address(treasury));
        factory.createTokenAndAddLiquidity{value: wethAmountForLiquidity}(name, symbol, supply);
        vm.stopPrank();

        // Verify balances
        assertEq(address(factory).balance, initialFactoryBalance, "Factory balance should remain unchanged");

        assertEq(
            address(treasury).balance,
            initialTreasuryBalance - wethAmountForLiquidity,
            "Treasury should only spend exact weth amount"
        );
    }

    // fork from https://github.com/Uniswap/v3-periphery/blob/main/contracts/libraries/OracleLibrary.sol
    function calculatePrice(address poolAddress, address baseToken, address quoteToken, uint128 baseAmount)
        internal
        view
        returns (uint256 quoteAmount)
    {
        // Get current sqrt price
        (uint160 sqrtPriceX96,,,,,,) = IUniswapV3Pool(poolAddress).slot0();

        // Calculate quoteAmount with better precision if it doesn't overflow
        if (sqrtPriceX96 <= type(uint128).max) {
            uint256 ratioX192 = uint256(sqrtPriceX96) * sqrtPriceX96;
            quoteAmount = baseToken < quoteToken
                ? FullMath.mulDiv(ratioX192, baseAmount, 1 << 192)
                : FullMath.mulDiv(1 << 192, baseAmount, ratioX192);
        } else {
            uint256 ratioX128 = FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, 1 << 64);
            quoteAmount = baseToken < quoteToken
                ? FullMath.mulDiv(ratioX128, baseAmount, 1 << 128)
                : FullMath.mulDiv(1 << 128, baseAmount, ratioX128);
        }
    }

    function test_VerifyInitialMarketCap() public {
        string memory name = "Test Token";
        string memory symbol = "TEST";
        uint256 supply = 1_000_000_000e18;

        uint256 wethAmountForLiquidity = (STARTING_MCAP * POOL_PERCENT) / DIVISOR;

        vm.prank(owner);
        factory.addToWhitelist(address(treasury));

        vm.startPrank(address(treasury));
        (address tokenAddress, uint256 positionId) =
            factory.createTokenAndAddLiquidity{value: wethAmountForLiquidity}(name, symbol, supply);
        vm.stopPrank();

        address poolAddress = IUniswapV3Factory(UNISWAP_V3_FACTORY).getPool(
            tokenAddress,
            WETH,
            10000 // 1% fee
        );

        uint256 priceInWeth = calculatePrice(
            poolAddress,
            tokenAddress,
            WETH,
            uint128(1e18) // 1 token
        );

        uint256 currentMarketCap = (supply * priceInWeth) / 1e18;

        console2.log("Price (in WETH):", priceInWeth);

        console2.log("Market Cap (in WETH):", currentMarketCap / 1e18);
        console2.log("Expected Market Cap (in WETH):", STARTING_MCAP / 1e18);

        assertApproxEqRel(
            currentMarketCap,
            STARTING_MCAP,
            0.05e18 // 5% tolerance
        );
    }
}
