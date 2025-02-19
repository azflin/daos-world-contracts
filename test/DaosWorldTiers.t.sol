// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import {DaosWorldTiers} from "../src/DaosWorldTiers.sol";
import {DaosWorldTiersFactory} from "../src/DaosWorldTiersFactory.sol";
import {DaosWorldV1Token} from "../src/DaosWorldV1Token.sol";
import {console} from "forge-std/console.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DaosWorldTiersTest is Test {
    DaosWorldTiersFactory public factory;
    DaosWorldTiers public daosWorld;
    address[] public users;
    address[] public maxUsers;

    uint256 constant NUM_USERS = 10;
    uint256 constant CONTRIBUTION_AMOUNT = 0.5 ether;
    string constant RPC_ENV_VAR = "BASE_RPC_URL";

    // test helper values
    uint256 public constant SUPPLY_TO_LP = 100_000_000 ether;
    uint256 public constant SUPPLY_TO_FUNDRAISERS = 1_000_000_000 * 1e18;
    uint256 constant SNIPE_AMOUNT = 1 ether / 100;
    int24 initialTick = -100000;
    int24 upperTick = 887200;

    // Test configuration
    string name = "Test DAO";
    string symbol = "TDAO";
    uint256 fundraisingGoal = 3 ether;
    uint256 fundraisingDeadline;
    uint256 fundExpiry;
    address daoManager;
    address protocolAdmin;
    address liquidityLockerFactory = 0x21104fA3b456d9171D46996eE8Bfb377a936bf5d;
    uint256 maxWhitelistAmount = 1 ether;
    uint256 maxPublicContributionAmount = 0.1 ether;
    uint256 minContributionAmount = 0.1 ether;

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
            users.push(user);
            vm.deal(user, 10 ether);
        }

        vm.startPrank(daoManager);
        factory = new DaosWorldTiersFactory();

        DaosWorldTiers.DaoConfig memory config = DaosWorldTiers.DaoConfig({
            name: name,
            symbol: symbol,
            daoManager: daoManager,
            protocolAdmin: daoManager,
            fundraisingGoal: fundraisingGoal,
            fundraisingDeadline: fundraisingDeadline,
            fundExpiry: fundExpiry,
            maxWhitelistAmount: maxWhitelistAmount,
            maxPublicContributionAmount: maxPublicContributionAmount,
            minContributionAmount: minContributionAmount,
            liquidityLockerFactory: liquidityLockerFactory
        });
        address daoAddress = factory.deployDao(config);
        vm.stopPrank();
        daosWorld = DaosWorldTiers(payable(daoAddress));
    }

    function test_notWhitelisted() public {
        address bob = users[0];
        vm.prank(bob);
        vm.expectRevert("You are not whitelisted");
        daosWorld.contribute{value: 1 ether}();
    }

    function test_singleContributor() public {
        address bob = users[0];
        address frank = users[1];
        address alice = users[2];
        address[] memory addresses = new address[](3);
        addresses[0] = bob;
        addresses[1] = frank;
        addresses[2] = alice;
        vm.prank(daoManager);
        daosWorld.addToWhitelist(addresses);

        vm.prank(bob);
        daosWorld.contribute{value: 1 ether}();
        vm.prank(frank);
        daosWorld.contribute{value: 1 ether}();
        vm.prank(alice);
        daosWorld.contribute{value: 1 ether}();
        bytes32 salt = getSalt(address(daosWorld));

        vm.prank(bob);
        vm.expectRevert("fundraising not finalized");
        daosWorld.claim();

        vm.prank(daoManager);
        daosWorld.finalizeFundraising(initialTick, upperTick, salt, SNIPE_AMOUNT, 100_000_000 ether);
        address dwc = daosWorld.daosWorldClaim();
        address daoToken = daosWorld.daoToken();
        assertEq(ERC20(daoToken).balanceOf(dwc), 900_000_000 ether);

        vm.prank(bob);
        daosWorld.claim();
        vm.prank(frank);
        daosWorld.claim();
        vm.prank(alice);
        daosWorld.claim();
        uint256 bobBalance = ERC20(daoToken).balanceOf(bob);
        uint256 frankBalance = ERC20(daoToken).balanceOf(frank);
        uint256 aliceBalance = ERC20(daoToken).balanceOf(alice);
        uint256 claimBalance = ERC20(daoToken).balanceOf(dwc);
        assertEq(bobBalance, 300000000000000000000000000);
        assertEq(frankBalance, 300000000000000000000000000);
        assertEq(bobBalance, 300000000000000000000000000);
        assertEq(claimBalance, 0);

        vm.prank(bob);
        vm.expectRevert("Already claimed");
        daosWorld.claim();

        vm.prank(users[4]);
        vm.expectRevert("You did not contribute");
        daosWorld.claim();
    }

    function test_tiers() public {
        address bob = users[0];
        address frank = users[1];
        address alice = users[2];
        address sam = users[3];
        address[] memory addresses = new address[](4);
        addresses[0] = bob;
        addresses[1] = frank;
        addresses[2] = alice;
        addresses[3] = sam;
        vm.prank(daoManager);
        daosWorld.addToWhitelist(addresses);

        vm.prank(bob);
        daosWorld.contribute{value: 1 ether}();
        vm.prank(daoManager);
        daosWorld.setTier(2);
        vm.prank(frank);
        daosWorld.contribute{value: 1 ether}();
        vm.prank(alice);
        daosWorld.contribute{value: 0.5 ether}();
        vm.prank(daoManager);
        daosWorld.setTier(3);
        vm.prank(sam);
        daosWorld.contribute{value: 0.5 ether}();

        bytes32 salt = getSalt(address(daosWorld));
        vm.prank(daoManager);
        daosWorld.finalizeFundraising(initialTick, upperTick, salt, SNIPE_AMOUNT, 100_000_000 ether);
        address dwc = daosWorld.daosWorldClaim();
        address daoToken = daosWorld.daoToken();
        assertEq(ERC20(daoToken).balanceOf(dwc), 900_000_000 ether);

        vm.prank(bob);
        daosWorld.claim();
        vm.prank(frank);
        daosWorld.claim();
        vm.prank(alice);
        daosWorld.claim();
        vm.prank(sam);
        daosWorld.claim();

        uint256 bobBalance = ERC20(daoToken).balanceOf(bob);
        uint256 frankBalance = ERC20(daoToken).balanceOf(frank);
        uint256 aliceBalance = ERC20(daoToken).balanceOf(alice);
        uint256 samBalance = ERC20(daoToken).balanceOf(sam);
        uint256 claimBalance = ERC20(daoToken).balanceOf(dwc);

        assertEq(bobBalance, 469565217391304347989413988);
        assertEq(frankBalance, 234782608695652173994706994);
        assertEq(aliceBalance, 117391304347826086997353497);
        assertEq(samBalance, 78260869565217391018525521);
        assertEq(claimBalance, 0);
    }

    function test_tiers2() public {
        address bob = users[0];
        address frank = users[1];
        address[] memory addresses = new address[](2);
        addresses[0] = bob;
        addresses[1] = frank;
        vm.prank(daoManager);
        daosWorld.addToWhitelist(addresses);
        vm.prank(daoManager);
        daosWorld.setMaxWhitelistAmount(2 ether);

        vm.prank(bob);
        daosWorld.contribute{value: 3 ether / 2}();
        vm.prank(daoManager);
        daosWorld.setTier(2);
        vm.prank(frank);
        daosWorld.contribute{value: 3 ether / 2}();

        bytes32 salt = getSalt(address(daosWorld));
        vm.prank(daoManager);
        daosWorld.finalizeFundraising(initialTick, upperTick, salt, SNIPE_AMOUNT, 100_000_000 ether);
        address dwc = daosWorld.daosWorldClaim();
        address daoToken = daosWorld.daoToken();
        assertEq(ERC20(daoToken).balanceOf(dwc), 900_000_000 ether);

        vm.prank(bob);
        daosWorld.claim();
        vm.prank(frank);
        daosWorld.claim();

        uint256 bobBalance = ERC20(daoToken).balanceOf(bob);
        uint256 frankBalance = ERC20(daoToken).balanceOf(frank);
        uint256 claimBalance = ERC20(daoToken).balanceOf(dwc);

        assertEq(bobBalance, 600000000000000000000000000);
        assertEq(frankBalance, 300000000000000000000000000);
        assertEq(claimBalance, 0);
    }

    function test_contributingInAnotherTierAndPublic() public {
        address bob = users[0];
        address frank = users[1];
        address[] memory addresses = new address[](1);
        addresses[0] = bob;
        vm.prank(daoManager);
        daosWorld.addToWhitelist(addresses);
        vm.prank(daoManager);
        daosWorld.setMaxWhitelistAmount(2 ether);

        vm.prank(bob);
        daosWorld.contribute{value: 1 ether}();

        vm.prank(frank);
        vm.expectRevert("You are not whitelisted");
        daosWorld.contribute{value: 1 ether}();

        vm.prank(daoManager);
        daosWorld.setTier(2);
        vm.prank(daoManager);
        daosWorld.setMaxWhitelistAmount(0);
        vm.prank(daoManager);
        daosWorld.setMaxPublicContributionAmount(10 ether);
        vm.prank(bob);
        vm.expectRevert("You already contributed in another tier");
        daosWorld.contribute{value: 2 ether}();

        vm.prank(frank);
        daosWorld.contribute{value: 2 ether}();

        bytes32 salt = getSalt(address(daosWorld));
        vm.prank(daoManager);
        daosWorld.finalizeFundraising(initialTick, upperTick, salt, SNIPE_AMOUNT, 100_000_000 ether);
        address dwc = daosWorld.daosWorldClaim();
        address daoToken = daosWorld.daoToken();
        assertEq(ERC20(daoToken).balanceOf(dwc), 900_000_000 ether);

        vm.prank(bob);
        daosWorld.claim();
        vm.prank(frank);
        daosWorld.claim();

        uint256 bobBalance = ERC20(daoToken).balanceOf(bob);
        uint256 frankBalance = ERC20(daoToken).balanceOf(frank);
        uint256 claimBalance = ERC20(daoToken).balanceOf(dwc);

        assertEq(bobBalance, 450000000000000000000000000);
        assertEq(frankBalance, 450000000000000000000000000);
        assertEq(claimBalance, 0);
    }

    function test_samePersonContributeTwice() public {
        address bob = users[0];
        address frank = users[1];
        address alice = users[2];
        address[] memory addresses = new address[](3);
        addresses[0] = bob;
        addresses[1] = frank;
        addresses[2] = alice;
        vm.prank(daoManager);
        daosWorld.addToWhitelist(addresses);

        vm.prank(bob);
        daosWorld.contribute{value: 0.5 ether}();
        vm.prank(bob);
        daosWorld.contribute{value: 0.5 ether}();
        vm.prank(frank);
        daosWorld.contribute{value: 1 ether}();
        vm.prank(alice);
        daosWorld.contribute{value: 1 ether}();

        bytes32 salt = getSalt(address(daosWorld));
        vm.prank(daoManager);
        daosWorld.finalizeFundraising(initialTick, upperTick, salt, SNIPE_AMOUNT, 100_000_000 ether);
        address dwc = daosWorld.daosWorldClaim();
        address daoToken = daosWorld.daoToken();
        assertEq(ERC20(daoToken).balanceOf(dwc), 900_000_000 ether);

        vm.prank(bob);
        daosWorld.claim();
        vm.prank(frank);
        daosWorld.claim();
        vm.prank(alice);
        daosWorld.claim();

        uint256 bobBalance = ERC20(daoToken).balanceOf(bob);
        uint256 frankBalance = ERC20(daoToken).balanceOf(frank);
        uint256 aliceBalance = ERC20(daoToken).balanceOf(alice);
        uint256 claimBalance = ERC20(daoToken).balanceOf(dwc);

        assertEq(bobBalance, 300000000000000000000000000);
        assertEq(frankBalance, 300000000000000000000000000);
        assertEq(aliceBalance, 300000000000000000000000000);
        assertEq(claimBalance, 0);
    }

    function test_setGoalReached() public {
        address bob = users[0];
        address frank = users[1];
        address[] memory addresses = new address[](2);
        addresses[0] = bob;
        addresses[1] = frank;
        vm.prank(daoManager);
        daosWorld.addToWhitelist(addresses);
        vm.prank(daoManager);
        daosWorld.setMaxWhitelistAmount(2 ether);

        vm.prank(bob);
        daosWorld.contribute{value: 1 ether}();
        vm.prank(daoManager);
        daosWorld.setGoalReached();

        bytes32 salt = getSalt(address(daosWorld));
        vm.prank(daoManager);
        daosWorld.finalizeFundraising(initialTick, upperTick, salt, SNIPE_AMOUNT, 100_000_000 ether);
        address dwc = daosWorld.daosWorldClaim();
        address daoToken = daosWorld.daoToken();
        assertEq(ERC20(daoToken).balanceOf(dwc), 900_000_000 ether);

        vm.prank(bob);
        daosWorld.claim();

        uint256 bobBalance = ERC20(daoToken).balanceOf(bob);
        uint256 frankBalance = ERC20(daoToken).balanceOf(frank);
        uint256 claimBalance = ERC20(daoToken).balanceOf(dwc);

        assertEq(bobBalance, 900000000000000000000000000);
        assertEq(frankBalance, 0);
        assertEq(claimBalance, 0);
        assertEq(address(daosWorld).balance, 990000000000000000);
    }

    function testMaxContributorsTiers() public {
        console2.log("GasTest.testMaxContributorsTiers");
        vm.prank(daoManager);
        daosWorld.setMinContributionAmount(1);
        vm.prank(daoManager);
        daosWorld.setMaxPublicContributionAmount(100 ether);
        vm.prank(daoManager);
        daosWorld.setMaxWhitelistAmount(0);
        // Have each user contribute an exact amount to reach the goal. +1 for rounding
        uint256 maxNumUsers = 55;
        // Create test users with ETH and contribute exact amounts
        for (uint256 i = 0; i < maxNumUsers; i++) {
            address user = makeAddr(string(abi.encodePacked("user", vm.toString(i))));
            vm.deal(user, 5 ether); // Give each user enough ETH to contribute
            maxUsers.push(user);
        }
        uint256 contributionPerUser = daosWorld.fundraisingGoal() / maxNumUsers + 1;
        uint256 successfulContributions = 0;
        for (uint256 i = 0; i < maxUsers.length; i++) {
            vm.prank(maxUsers[i]);
            daosWorld.contribute{value: contributionPerUser}();
            console.log(i, "contributed!");
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

        uint256 gasStart = gasleft();
        vm.startPrank(daoManager);
        daosWorld.finalizeFundraising(initialTick, upperTick, salt, SNIPE_AMOUNT, 100_000_000 ether);
        uint256 gasUsed = gasStart - gasleft();
        console.log("Gas used for finalizeFundraising:", gasUsed);
        console.log("Fundraising finalized successfully with", successfulContributions, "contributors");
        vm.stopPrank();

        for (uint256 i = 0; i < maxUsers.length; i++) {
            vm.prank(maxUsers[i]);
            daosWorld.claim();
        }
        console.log("everyone claimed");
        //        address daoToken = daosWorld.daoToken();
        console.log(ERC20(daosWorld.daoToken()).balanceOf(maxUsers[0]));
        console.log(ERC20(daosWorld.daoToken()).balanceOf(maxUsers[maxNumUsers - 1]));
    }

    function computeTokenAddress(address deployer, bytes32 salt, string memory _name, string memory _symbol)
        internal
        view
        returns (address)
    {
        bytes memory creationCode = type(DaosWorldV1Token).creationCode;
        bytes memory constructorArgs = abi.encode(_name, _symbol);
        bytes memory bytecode = abi.encodePacked(creationCode, constructorArgs);
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, keccak256(bytecode))))));
    }

    function getSalt(address deployer) internal view returns (bytes32) {
        bytes32 base = keccak256(abi.encodePacked(name, symbol));
        uint160 wethAddr = uint160(daosWorld.WETH());

        for (uint256 i = 0; i < 1000; i++) {
            bytes32 salt = keccak256(abi.encodePacked(base, i));
            address computed = computeTokenAddress(deployer, salt, name, symbol);
            if (wethAddr > uint160(computed)) {
                return salt;
            }
        }
        revert("Could not find suitable salt");
    }
}
