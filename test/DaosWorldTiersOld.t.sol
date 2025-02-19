//// SPDX-License-Identifier: MIT
//pragma solidity 0.8.26;
//
//import "forge-std/Test.sol";
//import {DaosWorldTiers} from "../src/DaosWorldTiers.sol";
//import {DaosWorldTiersFactory} from "../src/DaosWorldTiersFactory.sol";
//import {DaosWorldV1Token} from "../src/DaosWorldV1Token.sol";
//import {console} from "forge-std/console.sol";
//
//contract DaosWorldTiersTest is Test {
//    DaosWorldTiersFactory public factory;
//    DaosWorldTiers public daosWorld;
//    address[] public whitelistedUsers;
//
//    uint256 constant NUM_USERS = 10;
//    uint256 constant CONTRIBUTION_AMOUNT = 0.5 ether;
//    string constant RPC_ENV_VAR = "BASE_RPC_URL";
//
//    // test helper values
//    uint256 public constant SUPPLY_TO_LP = 100_000_000 ether;
//    uint256 public constant SUPPLY_TO_FUNDRAISERS = 1_000_000_000 * 1e18;
//    uint256 constant SNIPE_AMOUNT = 1 ether;
//    int24 initialTick = -100000;
//    int24 upperTick = 887200;
//
//    // Test configuration
//    string name = "Test DAO";
//    string symbol = "TDAO";
//    uint256 fundraisingGoal = 3 ether;
//    uint256 fundraisingDeadline;
//    uint256 fundExpiry;
//    address daoManager;
//    address protocolAdmin;
//    address liquidityLockerFactory = 0x21104fA3b456d9171D46996eE8Bfb377a936bf5d;
//    uint256 maxWhitelistAmount = 1 ether;
//    uint256 maxPublicContributionAmount = 0.1 ether;
//    uint256 minContributionAmount = 0.1 ether;
//    uint256 maxContributors = 10;
//
//    function setUp() public {
//        string memory rpcUrl = vm.envString(RPC_ENV_VAR);
//        vm.createSelectFork(rpcUrl);
//
//        fundraisingDeadline = block.timestamp + 7 days;
//        fundExpiry = block.timestamp + 30 days;
//        daoManager = makeAddr("daoManager");
//        vm.deal(daoManager, 100 ether);
//
//        // Create whitelisted users
//        for (uint256 i = 0; i < NUM_USERS; i++) {
//            address user = makeAddr(string.concat("user", vm.toString(i)));
//            whitelistedUsers.push(user);
//            vm.deal(user, 10 ether);
//        }
//
//        vm.startPrank(daoManager);
//        factory = new DaosWorldTiersFactory();
//
//        DaosWorldTiers.DaoConfig memory config = DaosWorldTiers.DaoConfig({
//            name: name,
//            symbol: symbol,
//            daoManager: daoManager,
//            protocolAdmin: daoManager,
//            fundraisingGoal: fundraisingGoal,
//            fundraisingDeadline: fundraisingDeadline,
//            fundExpiry: fundExpiry,
//            maxWhitelistAmount: maxWhitelistAmount,
//            maxPublicContributionAmount: maxPublicContributionAmount,
//            minContributionAmount: minContributionAmount,
//            maxContributors: maxContributors,
//            liquidityLockerFactory: liquidityLockerFactory
//        });
//
//        address daoAddress = factory.deployDao(config);
//        vm.stopPrank();
//
//        daosWorld = DaosWorldTiers(payable(daoAddress));
//    }
//
//    function test_TierSystem2() public {
//        address bob = whitelistedUsers[0];
//        address alice = whitelistedUsers[1];
//        address frank = whitelistedUsers[2];
//        vm.startPrank(daoManager);
//        address[] memory addresses = new address[](3);
//        addresses[0] = bob;
//        addresses[1] = alice;
//        addresses[2] = frank;
//        daosWorld.addToWhitelist(addresses);
//        vm.stopPrank();
//        vm.prank(bob);
//        daosWorld.contribute{value: 1 ether}();
//        vm.prank(daoManager);
//        daosWorld.setTier(3);
//        vm.prank(alice);
//        daosWorld.contribute{value: 1 ether}();
//        vm.prank(frank);
//        daosWorld.contribute{value: 1 ether}();
//        bytes32 salt = getSalt(address(daosWorld));
//        vm.prank(daoManager);
//        daosWorld.finalizeFundraising(-254200, 887200, salt, 1000000);
//        DaosWorldV1Token token = DaosWorldV1Token(daosWorld.daoToken());
//        console.log("bob balance", token.balanceOf(bob));
//        console.log("alice balance", token.balanceOf(alice));
//        console.log("frank balance", token.balanceOf(frank));
//        uint256 totalMinted = token.balanceOf(bob) + token.balanceOf(alice) + token.balanceOf(frank);
//        console.log("totalMinted", totalMinted);
//    }
//
//    function computeTokenAddress(address deployer, bytes32 salt, string memory _name, string memory _symbol)
//        internal
//        view
//        returns (address)
//    {
//        bytes memory creationCode = type(DaosWorldV1Token).creationCode;
//        bytes memory constructorArgs = abi.encode(_name, _symbol);
//        bytes memory bytecode = abi.encodePacked(creationCode, constructorArgs);
//        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, keccak256(bytecode))))));
//    }
//
//    function getSalt(address deployer) internal view returns (bytes32) {
//        bytes32 base = keccak256(abi.encodePacked(name, symbol));
//        uint160 wethAddr = uint160(daosWorld.WETH());
//
//        for (uint256 i = 0; i < 1000; i++) {
//            bytes32 salt = keccak256(abi.encodePacked(base, i));
//            address computed = computeTokenAddress(deployer, salt, name, symbol);
//            if (wethAddr > uint160(computed)) {
//                return salt;
//            }
//        }
//        revert("Could not find suitable salt");
//    }
//
//    function test_RevertOnExcessiveContribution() public {
//        vm.startPrank(daoManager);
//        address[] memory addresses = new address[](1);
//        addresses[0] = whitelistedUsers[0];
//        daosWorld.addToWhitelist(addresses);
//        vm.stopPrank();
//
//        vm.startPrank(whitelistedUsers[0]);
//        vm.expectRevert();
//        daosWorld.contribute{value: maxWhitelistAmount + 1}();
//        vm.stopPrank();
//    }
//
//    function test_RevertOnNonWhitelisted() public {
//        address nonWhitelisted = makeAddr("nonWhitelisted");
//        vm.deal(nonWhitelisted, 1 ether);
//
//        vm.startPrank(nonWhitelisted);
//        vm.expectRevert();
//        daosWorld.contribute{value: 0.1 ether}();
//        vm.stopPrank();
//    }
//
//    function test_RevertOnFinalizingBeforeGoal() public {
//        vm.startPrank(daoManager);
//        address[] memory addresses = new address[](1);
//        addresses[0] = whitelistedUsers[0];
//        daosWorld.addToWhitelist(addresses);
//        vm.stopPrank();
//
//        uint256 contribution = maxWhitelistAmount > fundraisingGoal - 1 ? fundraisingGoal - 1 : maxWhitelistAmount;
//
//        vm.prank(whitelistedUsers[0]);
//        daosWorld.contribute{value: contribution}();
//
//        bytes32 salt = getSalt(address(daosWorld));
//
//        vm.startPrank(daoManager);
//        vm.expectRevert("Fundraising goal not reached");
//        daosWorld.finalizeFundraising(initialTick, upperTick, salt, SNIPE_AMOUNT);
//        vm.stopPrank();
//    }
//
//    function _deployNewDao() internal returns (DaosWorldTiers) {
//        vm.startPrank(daoManager);
//
//        DaosWorldTiers.DaoConfig memory config = DaosWorldTiers.DaoConfig({
//            name: "Test DAO 2",
//            symbol: "TDAO2",
//            daoManager: daoManager,
//            protocolAdmin: daoManager,
//            fundraisingGoal: 3 ether,
//            fundraisingDeadline: fundraisingDeadline,
//            fundExpiry: fundExpiry,
//            maxWhitelistAmount: maxWhitelistAmount,
//            maxPublicContributionAmount: 0.5 ether,
//            minContributionAmount: minContributionAmount,
//            maxContributors: maxContributors,
//            liquidityLockerFactory: liquidityLockerFactory
//        });
//
//        address daoAddress = factory.deployDao(config);
//        vm.stopPrank();
//        return DaosWorldTiers(payable(daoAddress));
//    }
//
//    function test_CompleteDAOLifecycle() public {
//        // Setup initial configuration
//        vm.startPrank(daoManager);
//
//        // 1. Configure DAO parameters
//        uint256 minContrib = 0.1 ether;
//        uint256 maxContrib = 4; // 4 contributors max
//        uint256 whitelistMaxContrib = 1 ether;
//        uint256 publicMaxContrib = 0.5 ether; // Smaller amount to test more contributors
//
//        daosWorld.setMinContributionAmount(minContrib);
//        daosWorld.setMaxContributors(maxContrib);
//        daosWorld.setMaxWhitelistAmount(whitelistMaxContrib);
//        daosWorld.setMaxPublicContributionAmount(publicMaxContrib);
//
//        // 2. Setup whitelist phase (tierDivisor = 1)
//        address[] memory whitelistAddrs = new address[](2);
//        for (uint256 i = 0; i < 2; i++) {
//            whitelistAddrs[i] = makeAddr(string.concat("whitelist", vm.toString(i)));
//            vm.deal(whitelistAddrs[i], 10 ether);
//        }
//        daosWorld.addToWhitelist(whitelistAddrs);
//        vm.stopPrank();
//
//        // 3. Test minimum contribution requirement
//        vm.startPrank(whitelistAddrs[0]);
//        vm.expectRevert("Below minimum contribution");
//        daosWorld.contribute{value: 0.05 ether}(); // Below minimum
//        vm.stopPrank();
//
//        // 4. Whitelist phase contributions (1 ETH total)
//        vm.prank(whitelistAddrs[0]);
//        daosWorld.contribute{value: 0.5 ether}();
//        assertEq(daosWorld.tierDivisor(), 1, "First contributor should have tier 1");
//
//        vm.prank(whitelistAddrs[1]);
//        daosWorld.contribute{value: 0.5 ether}();
//        assertEq(daosWorld.totalRaised(), 1 ether, "Should have raised 1 ETH in whitelist");
//
//        // 5. Start public phase with worse tier
//        vm.startPrank(daoManager);
//        daosWorld.setMaxWhitelistAmount(0); // Disable whitelist
//        daosWorld.setTier(2); // Set worse tier for public phase
//        vm.stopPrank();
//
//        // 6. Test public phase contributions
//        address[] memory publicAddrs = new address[](3);
//        for (uint256 i = 0; i < 3; i++) {
//            publicAddrs[i] = makeAddr(string.concat("public", vm.toString(i)));
//            vm.deal(publicAddrs[i], 10 ether);
//        }
//
//        // First public user contributes
//        vm.prank(publicAddrs[0]);
//        daosWorld.contribute{value: 0.5 ether}();
//        assertEq(daosWorld.tierDivisor(), 2, "Public contributor should have tier 2");
//
//        // 7. Test manual pause in public phase
//        vm.prank(daoManager);
//        daosWorld.setGoalReached(); // Manually pause
//        assertTrue(daosWorld.goalReached(), "Should be able to manually set goal reached");
//
//        // Try to contribute after manual pause
//        vm.prank(publicAddrs[1]);
//        vm.expectRevert("Goal already reached");
//        daosWorld.contribute{value: 0.5 ether}();
//
//        // 8. Test with a new DAO to verify maxContributors
//        DaosWorldTiers newDao = _deployNewDao();
//        vm.startPrank(daoManager);
//        newDao.setMaxContributors(3); // Set lower max contributors
//        newDao.setMaxWhitelistAmount(0); // Start in public phase
//        newDao.setTier(2);
//        vm.stopPrank();
//
//        // Fill up to max contributors
//        for (uint256 i = 0; i < 3; i++) {
//            vm.prank(publicAddrs[i]);
//            newDao.contribute{value: 0.5 ether}();
//        }
//
//        // Try to exceed maxContributors
//        address extraUser = makeAddr("extra");
//        vm.deal(extraUser, 10 ether);
//        vm.prank(extraUser);
//        vm.expectRevert("Goal already reached");
//        newDao.contribute{value: 0.5 ether}();
//
//        // Verify goalReached was set when maxContributors hit
//        assertTrue(newDao.goalReached(), "Goal should be reached when max contributors hit");
//
//        // 9. Test finalization and token distribution
//        vm.startPrank(daoManager);
//        bytes32 salt = getSalt(address(daosWorld));
//        daosWorld.finalizeFundraising(initialTick, upperTick, salt, SNIPE_AMOUNT);
//        assertTrue(daosWorld.fundraisingFinalized(), "Fundraising should be finalized");
//        vm.stopPrank();
//
//        // Verify token distribution (tier 1 gets more tokens than tier 2)
//        DaosWorldV1Token token = DaosWorldV1Token(daosWorld.daoToken());
//        uint256 tier1Balance = token.balanceOf(whitelistAddrs[0]);
//        uint256 tier2Balance = token.balanceOf(publicAddrs[0]);
//        assertTrue(tier1Balance > tier2Balance, "Tier 1 should get more tokens than tier 2");
//    }
//}
