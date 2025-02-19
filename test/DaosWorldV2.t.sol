// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import {DaosWorldV2} from "../src/DaosWorldV2.sol";
import {DaosWorldFactoryV2} from "../src/DaosWorldFactoryV2.sol";
import {DaosWorldV1Token} from "../src/DaosWorldV1Token.sol";

contract DaosWorldV2Test is Test {
    DaosWorldFactoryV2 public factory;
    DaosWorldV2 public daosWorld;
    address[] public whitelistedUsers;

    uint256 constant NUM_USERS = 10;
    uint256 constant CONTRIBUTION_AMOUNT = 0.5 ether;
    string constant RPC_ENV_VAR = "BASE_RPC_URL";

    // test helper values
    uint256 public constant SUPPLY_TO_LP = 100_000_000 ether;
    uint256 public constant SUPPLY_TO_FUNDRAISERS = 1_000_000_000 * 1e18;
    uint256 constant SNIPE_AMOUNT = 1 ether;
    int24 initialTick = -100000;
    int24 upperTick = 887200;

    // Test configuration
    string name = "Test DAO";
    string symbol = "TDAO";
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

        factory = new DaosWorldFactoryV2();

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
                maxPublicContributionAmount
            )
        );
        vm.stopPrank();

        daosWorld = DaosWorldV2(payable(daoAddress));
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
        // Finalize fundraising
        vm.startPrank(daoManager);
        daosWorld.finalizeFundraising(initialTick, upperTick, salt, SNIPE_AMOUNT);
        vm.stopPrank();

        // Get token address
        address tokenAddr = daosWorld.daoToken();
        require(tokenAddr != address(0), "Token not deployed");
        DaosWorldV1Token token = DaosWorldV1Token(tokenAddr);

        // Check if users received correct token amounts
        uint256 totalContributors = 10;
        for (uint256 i = 0; i < whitelistedUsers.length; i++) {
            uint256 expectedTokens = SUPPLY_TO_FUNDRAISERS / totalContributors;
            uint256 actualBalance = token.balanceOf(whitelistedUsers[i]);

            assertEq(actualBalance, expectedTokens, "Token distribution incorrect");
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
        daosWorld.finalizeFundraising(initialTick, upperTick, salt, SNIPE_AMOUNT);
        vm.stopPrank();
    }
}
