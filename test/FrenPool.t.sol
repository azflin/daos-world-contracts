// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {DaosWorldV1} from "../src/DaosWorldV1.sol";
import {DaosWorldFactoryV1} from "../src/DaosWorldFactoryV1.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {LockerFactory} from "../src/lp-locker/LockerFactory.sol";

contract FrenPoolTest is Test {
    uint256 baseFork;
    string BASE_RPC_URL = vm.envString("BASE_RPC_URL");

    DaosWorldFactoryV1 public factory;
    LockerFactory public lockerFactory;

    address DEGEN = address(888);

    function setUp() public {
        baseFork = vm.createFork(BASE_RPC_URL);
        vm.selectFork(baseFork);
        vm.rollFork(23515792);
        uint256 currentTimestamp = block.timestamp;
        factory = new DaosWorldFactoryV1();
        vm.deal(DEGEN, 10 ether);
        lockerFactory = new LockerFactory();
    }

    function test_DeployDao() public {
        factory.deployDao(
            "Dao1", "D1", 100000000000000000, 2711111111, 3711111111, address(this), address(lockerFactory), 0, 0
        );
    }

    // TODO: Test refund, goalReached, fundraisingDeadline
}
