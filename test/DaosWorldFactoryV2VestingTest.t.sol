// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/DaosWorldV2Vesting.sol";
import "../src/DaosWorldV1Token.sol";
import "../src/DaosWorldFactoryV2Vesting.sol";
import "../src/vesting/DaosWorldPayFactory.sol";

contract DaosWorldFactoryV2VestingTest is Test {
    DaosWorldV2Vesting public daosWorld;
    address[] public users;
    uint256 constant NUM_USERS = 2;
    string constant RPC_ENV_VAR = "BASE_RPC_URL";
    string name;
    string symbol;
    address public daoManager;
    uint256 constant INITIAL_VEST_PERCENT = 20; // 20% initial unlock
    uint256 constant VESTING_DURATION = 100 days; // Using time-based vesting duration
    uint256 constant SUPPLY_TO_FUNDRAISERS = 1_000_000_000 * 1e18;

    function setUp() public {
        // Fork Base mainnet
        string memory rpcUrl = vm.envString(RPC_ENV_VAR);
        vm.createSelectFork(rpcUrl);

        // Deploy the contract
        name = "DR3AM Fund";
        symbol = "FDREAM";
        uint256 fundraisingGoal = 10 ether; // 100000000000000000000
        uint256 fundraisingDeadline = 17369785450;
        uint256 fundExpiry = 17510581450;
        daoManager = 0xE2D064D2f2217a180aF55Ff1bA40ca57032D1128;
        address liquidityLockerFactory = 0x21104fA3b456d9171D46996eE8Bfb377a936bf5d;
        uint256 maxWhitelistAmount = 6 ether; // 1000000000000000000
        uint256 maxPublicContributionAmount = 0.1 ether; // 100000000000000000

        // Deploy mock DaosWorldPayFactory
        DaosWorldPayFactory payFactory = new DaosWorldPayFactory();

        DaosWorldFactoryV2Vesting dwf = new DaosWorldFactoryV2Vesting();

        daosWorld = dwf.deployDao(
            name,
            symbol,
            fundraisingGoal,
            fundraisingDeadline,
            fundExpiry,
            daoManager,
            liquidityLockerFactory,
            maxWhitelistAmount,
            maxPublicContributionAmount,
            address(payFactory) // Add DaosWorldPayFactory address
        );

        // Create test users with ETH and contribute exact amounts
        for (uint256 i = 0; i < NUM_USERS; i++) {
            address user = makeAddr(string(abi.encodePacked("user", vm.toString(i))));
            vm.deal(user, 6 ether); // Give each user enough ETH to contribute
            users.push(user);
        }
        // add whitelist
        daosWorld.addToWhitelist(users);
    }

    function testMaxContributors() public {
        console2.log("DaosWorldFactoryV2VestingTest.testMaxContributors");
        // Have each user contribute an exact amount to reach the goal. +1 for rounding
        uint256 contributionPerUser = daosWorld.fundraisingGoal() / NUM_USERS + 1;
        uint256 successfulContributions = 0;
        for (uint256 i = 0; i < users.length; i++) {
            vm.prank(users[i]);
            daosWorld.contribute{value: contributionPerUser}();
            successfulContributions++;
        }

        console.log("Successful contributions:", successfulContributions);

        // Try to finalize fundraising and measure gas
        // Set ticks for a reasonable price range around 1 token = 0.0001 ETH
        int24 initialTick = -171400;
        int24 upperTick = 887200;

        // Find a salt that will create a token address less than WETH
        bytes32 salt;
        address tokenAddress;
        address weth = daosWorld.WETH();
        uint256 nonce = 0;
        do {
            salt = bytes32(nonce);
            // Compute the token address that would be created with this salt
            bytes memory constructorArgs = abi.encode(name, symbol);
            bytes32 initCodeHash = keccak256(abi.encodePacked(type(DaosWorldV1Token).creationCode, constructorArgs));
            tokenAddress = address(
                uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(daosWorld), salt, initCodeHash))))
            );
            nonce++;
        } while (tokenAddress >= weth);

        console2.log("Found valid salt:", uint256(salt));
        console2.log("Token address would be:", tokenAddress);
        console2.log("WETH address is:", weth);

        vm.warp(block.timestamp + 1 days); // Move time forward

        // Log the total raised and goal
        console2.log("Total raised:", daosWorld.totalRaised());
        console2.log("Goal:", daosWorld.fundraisingGoal());
        console2.log("Goal reached:", daosWorld.goalReached());

        // Also provide some ETH for initial liquidity
        vm.deal(address(daosWorld), 1 ether);

        uint256 gasStart = gasleft();
        vm.startPrank(daoManager);
        try daosWorld.finalizeFundraising(
            initialTick, upperTick, salt, 10000000, INITIAL_VEST_PERCENT, VESTING_DURATION
        ) {
            uint256 gasUsed = gasStart - gasleft();
            console.log("Gas used for finalizeFundraising:", gasUsed);
            console.log("Fundraising finalized successfully with", successfulContributions, "contributors");
        } catch Error(string memory reason) {
            console2.log("Failed to finalize fundraising with reason:", reason);
        } catch Panic(uint256 code) {
            console2.log("Failed to finalize fundraising with panic code:", code);
        } catch (bytes memory) {
            console2.log("Failed to finalize fundraising with low-level error");
            // Try to get the revert reason
            vm.expectRevert();
            daosWorld.finalizeFundraising(initialTick, upperTick, salt, 0, INITIAL_VEST_PERCENT, VESTING_DURATION);
        }
    }

    function testSnipe() public {
        uint256 contributionPerUser = daosWorld.fundraisingGoal() / NUM_USERS + 1;
        for (uint256 i = 0; i < users.length; i++) {
            vm.prank(users[i]);
            daosWorld.contribute{value: contributionPerUser}();
        }
        int24 initialTick = -171400;
        int24 upperTick = 887200;

        // Find a salt that will create a token address less than WETH
        bytes32 salt;
        address tokenAddress;
        address weth = daosWorld.WETH();
        uint256 nonce = 0;
        do {
            salt = bytes32(nonce);
            // Compute the token address that would be created with this salt
            bytes memory constructorArgs = abi.encode(name, symbol);
            bytes32 initCodeHash = keccak256(abi.encodePacked(type(DaosWorldV1Token).creationCode, constructorArgs));
            tokenAddress = address(
                uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(daosWorld), salt, initCodeHash))))
            );
            nonce++;
        } while (tokenAddress >= weth);
        vm.warp(block.timestamp + 1 days); // Move time forward
        vm.startPrank(daoManager);
        daosWorld.finalizeFundraising(initialTick, upperTick, salt, 1 ether, INITIAL_VEST_PERCENT, VESTING_DURATION);
    }

    function testVesting() public {
        // Setup: Have users contribute
        uint256 contributionPerUser = daosWorld.fundraisingGoal() / NUM_USERS + 1;
        for (uint256 i = 0; i < users.length; i++) {
            vm.prank(users[i]);
            daosWorld.contribute{value: contributionPerUser}();
        }

        // Finalize fundraising
        int24 initialTick = -171400;
        int24 upperTick = 887200;
        bytes32 salt = _findValidSalt();

        // Calculate vesting duration in seconds
        // uint256 vestingDuration = 100 days;

        vm.startPrank(daoManager);
        daosWorld.finalizeFundraising(initialTick, upperTick, salt, 1 ether, INITIAL_VEST_PERCENT, VESTING_DURATION);
        vm.stopPrank();

        // Test vesting for first user
        address user = users[0];

        // Calculate expected total tokens for user
        uint256 userContribution = contributionPerUser;
        uint256 expectedTotal = (userContribution * SUPPLY_TO_FUNDRAISERS) / daosWorld.totalRaised();
        uint256 expectedInitial = (expectedTotal * INITIAL_VEST_PERCENT) / 100;
        uint256 vestingAmount = expectedTotal - expectedInitial;

        // Verify initial tokens were received
        assertEq(ERC20(daosWorld.daoToken()).balanceOf(user), expectedInitial, "Initial vesting amount incorrect");

        // Move forward a bit after stream creation to allow some tokens to vest
        vm.warp(block.timestamp + 1 days);

        // Get DaosWorldPay contract
        DaosWorldPay payContract = DaosWorldPay(daosWorld.daosWorldPay());

        // Calculate amountPerSec exactly as done in DaosWorldV2Vesting
        uint216 amountPerSec = uint216((vestingAmount * payContract.DECIMALS_DIVISOR()) / VESTING_DURATION);

        // Log values for debugging
        console.log("Vesting Amount:", vestingAmount);
        console.log("Amount Per Sec:", uint256(amountPerSec));

        // Move forward halfway through vesting period
        vm.warp(block.timestamp + VESTING_DURATION / 2);

        // Check withdrawable amount
        (uint256 withdrawableAmount, uint256 lastUpdate, uint256 owed) =
            payContract.withdrawable(address(daosWorld), user, amountPerSec);

        // Log withdrawable details
        console.log("Withdrawable Amount:", withdrawableAmount);
        console.log("Last Update:", lastUpdate);
        console.log("Owed:", owed);

        assertGt(withdrawableAmount, 0, "Should have withdrawable tokens");

        // Withdraw tokens
        vm.prank(user);
        payContract.withdraw(address(daosWorld), user, amountPerSec);

        // Verify balance has increased
        uint256 midwayBalance = ERC20(daosWorld.daoToken()).balanceOf(user);
        assertGt(midwayBalance, expectedInitial, "Balance should increase after withdraw");

        // Move to end of vesting
        vm.warp(block.timestamp + VESTING_DURATION * 2);

        // Final withdraw
        uint256 beforeBalance = ERC20(daosWorld.daoToken()).balanceOf(user);
        vm.prank(user);
        payContract.withdraw(address(daosWorld), user, amountPerSec);

        // Verify final balance
        uint256 finalBalance = ERC20(daosWorld.daoToken()).balanceOf(user);
        assertGt(finalBalance, beforeBalance, "Should have more balance");
    }

    // Helper function to find valid salt
    function _findValidSalt() private view returns (bytes32) {
        bytes32 salt;
        address tokenAddress;
        address weth = daosWorld.WETH();
        uint256 nonce = 0;
        do {
            salt = bytes32(nonce);
            bytes memory constructorArgs = abi.encode(name, symbol);
            bytes32 initCodeHash = keccak256(abi.encodePacked(type(DaosWorldV1Token).creationCode, constructorArgs));
            tokenAddress = address(
                uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(daosWorld), salt, initCodeHash))))
            );
            nonce++;
        } while (tokenAddress >= weth);
        return salt;
    }
}
