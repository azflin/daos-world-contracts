// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/DaosWorldV2.sol";
import "../src/DaosWorldV1Token.sol";
import "../src/DaosWorldFactoryV2.sol";

contract DaosWorldFactoryV2Test is Test {
    DaosWorldV2 public daosWorld;
    address[] public users;
    uint256 constant NUM_USERS = 2;
    string constant RPC_ENV_VAR = "BASE_RPC_URL";
    string name;
    string symbol;
    address public daoManager;

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
        DaosWorldFactoryV2 dwf = new DaosWorldFactoryV2();

        daosWorld = dwf.deployDao(
            name,
            symbol,
            fundraisingGoal,
            fundraisingDeadline,
            fundExpiry,
            daoManager,
            liquidityLockerFactory,
            maxWhitelistAmount,
            maxPublicContributionAmount
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
        console2.log("DaosWorldFactoryV2Test.testMaxContributors");
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
        try daosWorld.finalizeFundraising(initialTick, upperTick, salt, 10000000) {
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
            daosWorld.finalizeFundraising(initialTick, upperTick, salt, 0);
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
        daosWorld.finalizeFundraising(initialTick, upperTick, salt, 1 ether);
    }
}
