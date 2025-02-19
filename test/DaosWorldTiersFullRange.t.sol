// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import {DaosWorldTiersFullRangeFactory} from "../src/DaosWorldTiersFullRangeFactory.sol";
import {DaosWorldV1Token} from "../src/DaosWorldV1Token.sol";
import {console} from "forge-std/console.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {DaosWorldTiersFullRange} from "../src/DaosWorldTiersFullRange.sol";

contract DaosWorldTiersFullRangeTest is Test {
    DaosWorldTiersFullRangeFactory public factory;
    DaosWorldTiersFullRange public daosWorld;
    address[] public users;
    address[] public maxUsers;

    uint256 constant NUM_USERS = 10;
    uint256 constant CONTRIBUTION_AMOUNT = 0.5 ether;
    string constant RPC_ENV_VAR = "BASE_RPC_URL";

    // test helper values
    uint256 constant SNIPE_AMOUNT = 10;

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
        factory = new DaosWorldTiersFullRangeFactory();

        DaosWorldTiersFullRange.DaoConfig memory config = DaosWorldTiersFullRange.DaoConfig({
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
        daosWorld = DaosWorldTiersFullRange(payable(daoAddress));
    }

    function test_notWhitelisted() public {
        address bob = users[0];
        vm.prank(bob);
        vm.expectRevert("You are not whitelisted");
        daosWorld.contribute{value: 1 ether}();
    }

    function test_singleContributorFullRange() public {
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
        console.log("ETH balance before", address(daosWorld).balance);
        daosWorld.finalizeFundraising(-197200, salt, SNIPE_AMOUNT, 1 ether, 200_000_000 ether);
        address daoToken = daosWorld.daoToken();
        console.log(ERC20(daoToken).balanceOf(address(daosWorld)));
        console.log("ETH balance after", address(daosWorld).balance);
        //        address dwc = daosWorld.daosWorldClaim();
        //        address daoToken = daosWorld.daoToken();
        //        assertEq(ERC20(daoToken).balanceOf(dwc), 1_000_000_000 ether);
        //
        //        vm.prank(bob);
        //        daosWorld.claim();
        //        vm.prank(frank);
        //        daosWorld.claim();
        //        vm.prank(alice);
        //        daosWorld.claim();
        //        uint256 bobBalance = ERC20(daoToken).balanceOf(bob);
        //        uint256 frankBalance = ERC20(daoToken).balanceOf(frank);
        //        uint256 aliceBalance = ERC20(daoToken).balanceOf(alice);
        //        uint256 claimBalance = ERC20(daoToken).balanceOf(dwc);
        //        assertEq(bobBalance, 333333333333333333333333333);
        //        assertEq(frankBalance, 333333333333333333333333333);
        //        assertEq(bobBalance, 333333333333333333333333333);
        //        assertEq(claimBalance, 1);
        //
        //        vm.prank(bob);
        //        vm.expectRevert("Already claimed");
        //        daosWorld.claim();
        //
        //        vm.prank(users[4]);
        //        vm.expectRevert("You did not contribute");
        //        daosWorld.claim();
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
