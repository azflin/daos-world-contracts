// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import {DaosWorldV2Vesting} from "../src/DaosWorldV2Vesting.sol";
import {DaosWorldFactoryV2Vesting} from "../src/DaosWorldFactoryV2Vesting.sol";
import {DaosWorldV1Token} from "../src/DaosWorldV1Token.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {DaosWorldPay} from "../src/vesting/DaosWorldPay.sol";
import {DaosWorldPayFactory} from "../src/vesting/DaosWorldPayFactory.sol";

contract DaosWorldV2VestingTest is Test {
    DaosWorldFactoryV2Vesting public factory;
    DaosWorldV2Vesting public daosWorld;
    DaosWorldPayFactory public payFactory;
    address[] public whitelistedUsers;

    uint256 constant NUM_USERS = 10;
    uint256 constant CONTRIBUTION_AMOUNT = 0.5 ether;
    string constant RPC_ENV_VAR = "BASE_RPC_URL";
    uint256 constant INITIAL_VEST_PERCENT = 20; // 20% initial unlock
    uint256 constant VESTING_DURATION = 100 days; // Using time-based vesting duration instead of blocks

    // test helper values
    uint256 public constant SUPPLY_TO_LP = 100_000_000 ether;
    uint256 public constant SUPPLY_TO_FUNDRAISERS = 1_000_000_000 * 1e18;
    uint256 constant SNIPE_AMOUNT = 1 ether;
    int24 initialTick = -100000;
    int24 upperTick = 887200;

    // Test configuration
    string name = "Bear";
    string symbol = "Bear";
    uint256 fundraisingGoal = 5 ether;
    uint256 fundraisingDeadline;
    uint256 fundExpiry;
    address daoManager;
    address liquidityLockerFactory = 0x21104fA3b456d9171D46996eE8Bfb377a936bf5d;
    uint256 maxWhitelistAmount = 1 ether;
    uint256 maxPublicContributionAmount = 0.1 ether;

    // Set up finalization parameters
    function setUp() public {
        string memory rpcUrl = vm.envString(RPC_ENV_VAR);
        vm.createSelectFork(rpcUrl);

        fundraisingDeadline = block.timestamp + 7 days;
        fundExpiry = block.timestamp + 30 days;

        daoManager = makeAddr("daoManager");
        vm.deal(daoManager, 100 ether);

        // Create whitelisted users
        for (uint256 i = 0; i < NUM_USERS; i++) {
            address user = makeAddr(string.concat("user", vm.toString(i)));
            whitelistedUsers.push(user);
            vm.deal(user, 10 ether);
        }

        vm.startPrank(daoManager);

        factory = new DaosWorldFactoryV2Vesting();
        address payFactoryAddress = address(new DaosWorldPayFactory());
        address daoAddress = address(
            factory.deployDao(
                name,
                symbol,
                fundraisingGoal,
                fundraisingDeadline,
                fundExpiry,
                daoManager,
                liquidityLockerFactory,
                maxWhitelistAmount,
                maxPublicContributionAmount,
                payFactoryAddress
            )
        );
        vm.stopPrank();

        daosWorld = DaosWorldV2Vesting(payable(daoAddress));
    }

    function test_WhitelistAndContribute() public {
        vm.startPrank(daoManager);
        for (uint256 i = 0; i < whitelistedUsers.length; i++) {
            address[] memory addresses = new address[](1);
            addresses[0] = whitelistedUsers[i];
            daosWorld.addToWhitelist(addresses);
        }
        vm.stopPrank();

        uint256 totalContributed = 0;
        for (uint256 i = 0; i < whitelistedUsers.length; i++) {
            vm.startPrank(whitelistedUsers[i]);
            daosWorld.contribute{value: CONTRIBUTION_AMOUNT}();
            totalContributed += CONTRIBUTION_AMOUNT;
            vm.stopPrank();
        }

        assertEq(address(daosWorld).balance, totalContributed, "Total contribution mismatch");
    }

    function computeTokenAddress(address deployer, bytes32 salt, string memory _name, string memory _symbol)
        internal
        view
        returns (address)
    {
        // Get the creation code of DaosWorldV1Token
        bytes memory creationCode = type(DaosWorldV1Token).creationCode;

        // Encode constructor parameters
        bytes memory constructorArgs = abi.encode(_name, _symbol);

        // Combine creation code and constructor args
        bytes memory bytecode = abi.encodePacked(creationCode, constructorArgs);

        // Compute the address using CREATE2
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, keccak256(bytecode))))));
    }

    function getSalt(address deployer) internal view returns (bytes32) {
        // dummy base salt
        bytes32 base = keccak256(abi.encodePacked(name, symbol));

        uint160 wethAddr = uint160(daosWorld.WETH());

        for (uint256 i = 0; i < 1000; i++) {
            bytes32 salt = keccak256(abi.encodePacked(base, i));
            address computed = computeTokenAddress(deployer, salt, name, symbol);

            // Check if the difference between addresses is greater than target
            if (wethAddr > uint160(computed)) {
                return salt;
            }
        }

        revert("Could not find suitable salt");
    }

    function test_FinalizeFundraising() public {
        test_WhitelistAndContribute();

        bytes32 salt = getSalt(address(daosWorld));

        uint256 daosWorldBalanceBefore = address(daosWorld).balance;
        // Finalize fundraising with vesting parameters
        vm.startPrank(daoManager);
        daosWorld.finalizeFundraising(
            initialTick, upperTick, salt, SNIPE_AMOUNT, INITIAL_VEST_PERCENT, VESTING_DURATION
        );
        vm.stopPrank();

        // Get token address
        address tokenAddr = daosWorld.daoToken();
        require(tokenAddr != address(0), "Token not deployed");
        DaosWorldV1Token token = DaosWorldV1Token(tokenAddr);

        // Get DaosWorldPay contract for DECIMALS_DIVISOR
        DaosWorldPay payContract = DaosWorldPay(daosWorld.daosWorldPay());

        // Check if users received correct initial token amounts (20%)
        uint256 totalContributors = 10;
        for (uint256 i = 0; i < whitelistedUsers.length; i++) {
            uint256 totalExpectedTokens = SUPPLY_TO_FUNDRAISERS / totalContributors;
            uint256 expectedInitialTokens = (totalExpectedTokens * INITIAL_VEST_PERCENT) / 100;
            uint256 actualBalance = token.balanceOf(whitelistedUsers[i]);

            assertEq(actualBalance, expectedInitialTokens, "Initial token distribution incorrect");

            // Verify total vesting amount in DaosWorldPay (should be in 20 decimals)
            uint256 vestingAmount = totalExpectedTokens - expectedInitialTokens;
            uint216 expectedAmountPerSec = uint216((vestingAmount * payContract.DECIMALS_DIVISOR()) / VESTING_DURATION);

            // Get stream ID
            bytes32 streamId = payContract.getStreamId(address(daosWorld), whitelistedUsers[i], expectedAmountPerSec);
            assertTrue(payContract.streamToStart(streamId) > 0, "Stream not created");
        }

        uint256 daosWorldBalanceAfter = address(daosWorld).balance;

        // Verify fundraising is finalized and snipe executed
        assertTrue(daosWorld.fundraisingFinalized(), "Fundraising not finalized");
        assertTrue(daosWorld.goalReached(), "Goal not marked as reached");
        assertTrue(daosWorldBalanceAfter == daosWorldBalanceBefore - SNIPE_AMOUNT, "Snipe amount not spent");

        // daos world token balance
        uint256 snipeAmount = token.balanceOf(address(daosWorld));
        uint256 minSnipeAmount = 20000e18;

        assertGt(snipeAmount, minSnipeAmount, "Snipe amount is too low");
    }

    function test_VestingSchedule() public {
        test_WhitelistAndContribute();

        bytes32 salt = getSalt(address(daosWorld));

        vm.startPrank(daoManager);
        daosWorld.finalizeFundraising(
            initialTick, upperTick, salt, SNIPE_AMOUNT, INITIAL_VEST_PERCENT, VESTING_DURATION
        );
        vm.stopPrank();

        address user = whitelistedUsers[0];
        uint256 totalTokens = SUPPLY_TO_FUNDRAISERS / NUM_USERS;
        uint256 initialTokens = (totalTokens * INITIAL_VEST_PERCENT) / 100;
        uint256 vestingTokens = totalTokens - initialTokens;

        // Get DaosWorldPay contract
        DaosWorldPay payContract = DaosWorldPay(daosWorld.daosWorldPay());

        // Calculate amountPerSec with 20 decimals precision
        uint216 amountPerSec = uint216((vestingTokens * payContract.DECIMALS_DIVISOR()) / VESTING_DURATION);

        // Check initial vest
        uint256 initialBalance = ERC20(daosWorld.daoToken()).balanceOf(user);
        assertEq(initialBalance, initialTokens, "Initial vest amount incorrect");

        // Check mid-vesting (50% through vesting period)
        vm.warp(block.timestamp + VESTING_DURATION / 2);

        // Get withdrawable amount
        (uint256 withdrawableAmount,,) = payContract.withdrawable(address(daosWorld), user, amountPerSec);
        assertGt(withdrawableAmount, 0, "Should have tokens to claim at halfway point");

        uint256 preClaimBalance = ERC20(daosWorld.daoToken()).balanceOf(user);
        vm.prank(user);
        payContract.withdraw(address(daosWorld), user, amountPerSec);
        uint256 postClaimBalance = ERC20(daosWorld.daoToken()).balanceOf(user);

        // Calculate expected vested amount at halfway point
        uint256 expectedVestedAtHalf = initialTokens + (vestingTokens / 2);

        assertGt(postClaimBalance, preClaimBalance, "Balance should increase after claim");
        assertApproxEqRel(postClaimBalance, expectedVestedAtHalf, 0.01e18, "Mid-vest amount incorrect");

        // Check full vesting
        vm.warp(block.timestamp + VESTING_DURATION);
        vm.prank(user);
        payContract.withdraw(address(daosWorld), user, amountPerSec);

        assertApproxEqRel(
            ERC20(daosWorld.daoToken()).balanceOf(user),
            totalTokens,
            0.01e18,
            "Final vested amount should equal total tokens"
        );
    }

    function test_RevertOnExcessiveContribution() public {
        // Whitelist first user
        vm.startPrank(daoManager);
        address[] memory addresses = new address[](1);
        addresses[0] = whitelistedUsers[0];
        daosWorld.addToWhitelist(addresses);
        vm.stopPrank();

        // Try to contribute more than max allowed
        vm.startPrank(whitelistedUsers[0]);
        vm.expectRevert();
        daosWorld.contribute{value: maxWhitelistAmount + 1}();
        vm.stopPrank();
    }

    function test_RevertOnNonWhitelisted() public {
        address nonWhitelisted = makeAddr("nonWhitelisted");
        vm.deal(nonWhitelisted, 1 ether);

        vm.startPrank(nonWhitelisted);
        vm.expectRevert();
        daosWorld.contribute{value: 0.1 ether}();
        vm.stopPrank();
    }

    function test_RevertOnFinalizingBeforeGoal() public {
        vm.startPrank(daoManager);
        address[] memory addresses = new address[](1);
        addresses[0] = whitelistedUsers[0];
        daosWorld.addToWhitelist(addresses);
        vm.stopPrank();

        uint256 contribution = maxWhitelistAmount > fundraisingGoal - 1 ? fundraisingGoal - 1 : maxWhitelistAmount;

        vm.prank(whitelistedUsers[0]);
        daosWorld.contribute{value: contribution}();

        bytes32 salt = getSalt(address(daosWorld));

        vm.startPrank(daoManager);
        vm.expectRevert("Fundraising goal not reached");
        daosWorld.finalizeFundraising(
            initialTick, upperTick, salt, SNIPE_AMOUNT, INITIAL_VEST_PERCENT, VESTING_DURATION
        );
        vm.stopPrank();
    }

    function test_FinalizeFundraisingGasUsage() public {
        uint256 MAX_GAS_LIMIT = 60_000_000;
        uint256 numUsers = 850;

        // Calculate base contribution per user
        uint256 baseContribution = fundraisingGoal / numUsers;
        uint256 remainder = fundraisingGoal % numUsers;

        address[] memory users = new address[](numUsers);
        for (uint256 i = 0; i < numUsers; i++) {
            users[i] = makeAddr(string.concat("fuzzUser", vm.toString(i)));
            // Fund users with enough ETH for their contribution
            // Last user gets the remainder
            uint256 userContribution = i == numUsers - 1 ? baseContribution + remainder : baseContribution;
            vm.deal(users[i], userContribution + 1 ether); // Extra 1 ETH for gas
        }

        // Whitelist users in batches of 50
        vm.startPrank(daoManager);
        for (uint256 i = 0; i < users.length; i += 50) {
            uint256 batchSize = min(50, users.length - i);
            address[] memory batch = new address[](batchSize);
            for (uint256 j = 0; j < batchSize; j++) {
                batch[j] = users[i + j];
            }
            daosWorld.addToWhitelist(batch);
        }
        vm.stopPrank();

        // Have users contribute their share
        uint256 totalContributed = 0;
        for (uint256 i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);
            // Last user contributes base amount plus remainder
            uint256 contribution = i == numUsers - 1 ? baseContribution + remainder : baseContribution;
            daosWorld.contribute{value: contribution}();
            totalContributed += contribution;
            vm.stopPrank();
        }

        // Verify total contributions meet the goal exactly
        assertEq(totalContributed, fundraisingGoal, "Total contributions should equal fundraising goal");

        // Find valid salt for token deployment
        bytes32 salt = getSalt(address(daosWorld));

        // Measure gas for finalization
        uint256 startGas = gasleft();
        vm.startPrank(daoManager);
        daosWorld.finalizeFundraising(
            initialTick, upperTick, salt, SNIPE_AMOUNT, INITIAL_VEST_PERCENT, VESTING_DURATION
        );
        vm.stopPrank();

        uint256 finalizationGas = startGas - gasleft();

        // Log detailed metrics
        console.log("Number of users:", numUsers);
        console.log("Gas Used for Finalization:", finalizationGas);
        console.log("Base contribution per user:", baseContribution);
        console.log("Remainder (given to last user):", remainder);
        console.log("Finalization Gas per User:", finalizationGas / numUsers);

        // Assert gas limits
        assertTrue(finalizationGas < MAX_GAS_LIMIT, "Finalization gas exceeds safe limit");
    }

    // Helper function to get minimum of two numbers
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
