// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {DN404Mirror} from "dn404/src/DN404Mirror.sol";
import {DaosWorld404} from "../src/DaosWorld404.sol";
import {DaosWorld404Token} from "../src/DaosWorld404Token.sol";

contract DaosWorldV1404Test is Test {
    DaosWorld404 public daosWorld;
    address[] public whitelistedUsers;

    uint256 constant NUM_USERS = 10;
    uint256 constant CONTRIBUTION_AMOUNT = 0.5 ether;
    string constant RPC_ENV_VAR = "BASE_RPC_URL";

    uint256 constant SNIPE_AMOUNT = 1 ether;
    int24 initialTick = -100000;
    int24 upperTick = 887200;

    // Test configuration
    string name = "Bear";
    string symbol = "Bear";
    string nftUrl = "https://api.example.com/token/";
    uint256 fundraisingGoal = 5 ether;
    uint256 fundraisingDeadline;
    uint256 fundExpiry;
    address daoManager;
    address liquidityLockerFactory = 0x21104fA3b456d9171D46996eE8Bfb377a936bf5d;
    uint256 maxWhitelistAmount = 5 ether;
    uint256 maxPublicContributionAmount = 0.1 ether;
    uint256 maxNftSupply = 10_000;

    function setUp() public {
        string memory rpcUrl = vm.envString(RPC_ENV_VAR);
        vm.createSelectFork(rpcUrl, 24844453);

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
        daosWorld = new DaosWorld404(
            fundraisingGoal,
            name,
            symbol,
            fundraisingDeadline,
            fundExpiry,
            daoManager,
            liquidityLockerFactory,
            maxWhitelistAmount,
            daoManager,
            maxPublicContributionAmount
        );
        vm.stopPrank();
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

    function test_FinalizeFundraising() public {
        test_WhitelistAndContribute();

        bytes32 salt = getSalt(address(daosWorld));

        uint256 daosWorldBalanceBefore = address(daosWorld).balance;

        // Finalize fundraising
        vm.startPrank(daoManager);
        daosWorld.finalizeFundraising(
            initialTick, upperTick, "https://api.example.com/token/", salt, SNIPE_AMOUNT, maxNftSupply
        );
        vm.stopPrank();

        // Get token address
        address tokenAddr = daosWorld.daoToken();
        require(tokenAddr != address(0), "Token not deployed");
        DaosWorld404Token token = DaosWorld404Token(payable(tokenAddr));

        // Calculate expected token amounts based on maxNftSupply
        uint256 supplyToLp = (maxNftSupply * 1e18) / 10; // 10% to LP
        uint256 supplyToFundraisers = (maxNftSupply * 1e18) - supplyToLp; // Remaining to fundraisers

        // Check if users received correct token amounts
        uint256 totalContributors = 10;
        for (uint256 i = 0; i < whitelistedUsers.length; i++) {
            uint256 expectedTokens = supplyToFundraisers / totalContributors;
            uint256 actualBalance = token.balanceOf(whitelistedUsers[i]);
            assertEq(actualBalance, expectedTokens, "Token distribution incorrect");
        }

        uint256 daosWorldBalanceAfter = address(daosWorld).balance;

        // Verify fundraising is finalized and snipe executed
        assertTrue(daosWorld.fundraisingFinalized(), "Fundraising not finalized");
        assertTrue(daosWorld.goalReached(), "Goal not marked as reached");
        assertTrue(daosWorldBalanceAfter == daosWorldBalanceBefore - SNIPE_AMOUNT, "Snipe amount not spent");

        // Check ERC404 specific functionality
        for (uint256 i = 0; i < whitelistedUsers.length; i++) {
            // Users should be ERC721 transfer exempt initially
            assertTrue(token.getSkipNFT(whitelistedUsers[i]), "User should be ERC721 transfer exempt");

            // Their ERC721 balance should be 0 due to exemption
            assertEq(
                DN404Mirror(payable(token.mirrorERC721())).balanceOf(whitelistedUsers[i]),
                0,
                "ERC721 balance should be 0 when exempt"
            );
        }
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

        bytes32 salt = bytes32(uint256(1));

        vm.startPrank(daoManager);
        vm.expectRevert("Fundraising goal not reached");
        daosWorld.finalizeFundraising(
            initialTick, upperTick, "https://api.example.com/token/", salt, SNIPE_AMOUNT, maxNftSupply
        );
        vm.stopPrank();
    }

    function test_UserCanGetERC721AfterExemptionRemoval() public {
        // First do the normal fundraising and token distribution
        test_FinalizeFundraising();

        // Get token contract
        DaosWorld404Token token = DaosWorld404Token(payable(daosWorld.daoToken()));

        // Pick the first user as our test subject
        address user = whitelistedUsers[0];
        uint256 userBalance = token.balanceOf(user);

        // Initially user should have:
        // 1. ERC20 balance but no ERC721s (due to exemption)
        // 2. Be transfer exempt
        assertTrue(token.getSkipNFT(user), "User should start transfer exempt");
        assertEq(DN404Mirror(payable(token.mirrorERC721())).balanceOf(user), 0, "Should have no NFTs initially");
        assertTrue(userBalance > 0, "Should have ERC20 balance");

        // User opts out of transfer exemption
        vm.startPrank(user);
        token.setSkipNFT(false);
        vm.stopPrank();

        // Verify exemption was removed
        assertFalse(token.getSkipNFT(user), "User should no longer be transfer exempt");

        // Calculate expected number of NFTs (whole tokens)
        uint256 expectedNFTs = userBalance / 1e18; // Divide by decimals to get whole tokens

        // Verify user now has NFTs for their whole tokens
        assertEq(
            DN404Mirror(payable(token.mirrorERC721())).balanceOf(user),
            expectedNFTs,
            "Should have NFTs for whole tokens"
        );

        // Test transferring tokens to trigger NFT minting
        vm.startPrank(user);
        // Transfer a small amount to self to trigger NFT minting if not already minted
        token.transfer(user, 0);
        vm.stopPrank();

        uint256[] memory nftIds = token.owned(user);
        assertEq(nftIds.length, expectedNFTs, "Should have NFTs for whole tokens");
        // Verify NFT ownership
        for (uint256 i = 0; i < expectedNFTs; i++) {
            assertEq(DN404Mirror(payable(token.mirrorERC721())).ownerOf(nftIds[i]), user, "User should own the NFT");
        }
    }

    function computeTokenAddress(address deployer, bytes32 salt) internal view returns (address) {
        // Get the creation code of DaosWorldV1Token
        bytes memory creationCode = type(DaosWorld404Token).creationCode;

        // Compute the address using CREATE2
        return address(
            uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, keccak256(creationCode)))))
        );
    }

    function getSalt(address deployer) internal view returns (bytes32) {
        // dummy base salt
        bytes32 base = keccak256(abi.encodePacked(name, symbol));

        uint160 wethAddr = uint160(daosWorld.WETH());

        for (uint256 i = 0; i < 50000; i++) {
            bytes32 salt = keccak256(abi.encodePacked(i, block.timestamp, name, symbol));
            address computed = computeTokenAddress(deployer, salt);

            // Check if the difference between addresses is greater than target
            if (wethAddr > uint160(computed)) {
                return salt;
            }
        }

        revert("Could not find suitable salt");
    }

    function test_GasUsage() public {
        uint256 MAX_GAS_LIMIT = 60_000_000;

        uint256 numUsers = 1600;

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

        bytes32 salt = getSalt(address(daosWorld));

        // Measure gas for finalization
        uint256 startGas = gasleft();
        vm.startPrank(daoManager);
        daosWorld.finalizeFundraising(
            initialTick, upperTick, "https://api.example.com/token/", salt, SNIPE_AMOUNT, maxNftSupply
        );
        vm.stopPrank();

        uint256 finalizationGas = startGas - gasleft();

        // Log detailed metrics
        emit log_named_uint("Number of users", numUsers);
        emit log_named_uint("Gas Used for Finalization", finalizationGas);
        emit log_named_uint("Base contribution per user", baseContribution);
        emit log_named_uint("Remainder (given to last user)", remainder);

        // Assert gas limits
        assertTrue(finalizationGas < MAX_GAS_LIMIT, "Finalization gas exceeds safe limit");

        // Verify operation succeeded
        assertTrue(daosWorld.fundraisingFinalized(), "Fundraising not finalized");
        assertTrue(daosWorld.goalReached(), "Goal not marked as reached");

        // Calculate and emit gas usage per user for analysis
        emit log_named_uint("Finalization Gas per User", finalizationGas / numUsers);
    }

    // Helper function to get minimum of two numbers
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
