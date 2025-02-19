// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {DaosWorldShitcoinFactory} from "../src/lp-factory/DaosWorldShitcoinFactory.sol";
import {DaosWorldFactoryV2} from "../src/DaosWorldFactoryV2.sol";
import {DaosWorldFactoryV2Vesting} from "../src/DaosWorldFactoryV2Vesting.sol";
import {DaosWorldPayFactory} from "../src/vesting/DaosWorldPayFactory.sol";
import {DaosWorldV2Vesting} from "../src/DaosWorldV2Vesting.sol";
import {DaosWorld404} from "../src/DaosWorld404.sol";
import {DaosWorldFactory404} from "../src/DaosWorldFactory404.sol";
import {DaosWorldWhitelistToken} from "../src/dwl/DaosWorldWhitelistToken.sol";
import {DWLConverter} from "../src/dwl/DWLConverter.sol";
import {DaosWorldTiersFactory} from "../src/DaosWorldTiersFactory.sol";
import {DaosWorldTiers} from "../src/DaosWorldTiers.sol";
import {DaosWorldV1Token} from "../src/DaosWorldV1Token.sol";
import {DaosWorldClaim} from "../src/DaosWorldClaim.sol";
import {SniperManager} from "../src/utils/SniperManager.sol";
import {DaosWorldTiersFactoryV2} from "../src/DaosWorldTiersFactoryV2.sol";
import {DaosWorldTiersV2} from "../src/DaosWorldTiersV2.sol";
import {DaosWorldV2Token} from "../src/DaosWorldV2Token.sol";

contract DaosWorldShitcoinFactoryScript is Script {
    DaosWorldShitcoinFactory public daosWorldShitcoinFactory;
    address public weth = 0x4200000000000000000000000000000000000006;
    address public nonFungiblePositionManager = 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1;
    address public uniswapV3Factory = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        daosWorldShitcoinFactory = new DaosWorldShitcoinFactory(weth, nonFungiblePositionManager, uniswapV3Factory);
        vm.stopBroadcast();
        console2.log("DaosWorldShitcoinFactory deployed to:", address(daosWorldShitcoinFactory));
    }
}

contract DaosWorldFactoryV2Script is Script {
    DaosWorldFactoryV2 public daosWorldFactoryV2;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        daosWorldFactoryV2 = new DaosWorldFactoryV2();
        vm.stopBroadcast();
        console2.log("DaosWorldFactoryV2 deployed to:", address(daosWorldFactoryV2));
    }
}

contract DaosWorldFactoryV2VestingScript is Script {
    DaosWorldFactoryV2Vesting public daosWorldFactoryV2Vesting;
    DaosWorldV2Vesting public daosWorldV2Vesting;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        daosWorldFactoryV2Vesting = new DaosWorldFactoryV2Vesting();
        DaosWorldV2Vesting.Config memory config = DaosWorldV2Vesting.Config({
            _fundraisingGoal: 1000000000000000, // 0.001 ETH for testing
            _name: "Bear",
            _symbol: "Bear",
            _fundraisingDeadline: 1746978545,
            _fundExpiry: 1751058145,
            _daoManager: 0x0c0d274060766d0F8DcDebc8c4B305a3e8a676C0, // Or specify a different address
            _liquidityLockerFactory: 0x21104fA3b456d9171D46996eE8Bfb377a936bf5d, // Replace with actual address
            _maxWhitelistAmount: 1000000000000000000, // 1 ETH
            _protocolAdmin: 0x0c0d274060766d0F8DcDebc8c4B305a3e8a676C0, // Or specify a different address
            _maxPublicContributionAmount: 1000000000000000, // 0.001 ETH
            _daosWorldPayFactory: 0x7Bc9a96770f6679AA6Afa8Df5B22A2C4E9383bB9 // Replace with actual address
        });

        daosWorldV2Vesting = new DaosWorldV2Vesting(config);
        vm.stopBroadcast();
        console2.log("DaosWorldFactoryV2Vesting deployed to:", address(daosWorldFactoryV2Vesting));
    }
}

contract DaosWorldPayFactoryScript is Script {
    DaosWorldPayFactory public daosWorldPayFactory;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        daosWorldPayFactory = new DaosWorldPayFactory();

        vm.stopBroadcast();
        console2.log("DaosWorldPayFactory deployed to:", address(daosWorldPayFactory));
    }
}

contract DaoWorldFactory4Script is Script {
    DaosWorldFactory404 public daosWorldFactoryV1404;
    DaosWorld404 public daosWorldV1404;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        daosWorldFactoryV1404 = new DaosWorldFactory404();
        daosWorldV1404 = new DaosWorld404(
            1000000000000000,
            "Bear",
            "Bear",
            1746978545,
            1751058145,
            0x0c0d274060766d0F8DcDebc8c4B305a3e8a676C0,
            0x21104fA3b456d9171D46996eE8Bfb377a936bf5d,
            1000000000000000000,
            0x0c0d274060766d0F8DcDebc8c4B305a3e8a676C0,
            1000000000000000
        );
        vm.stopBroadcast();
        console2.log("DaosWorldFactoryV1404 deployed to:", address(daosWorldFactoryV1404));
    }
}

contract DWLConverterScript is Script {
    DWLConverter public dwlConverter;
    //    DaosWorldWhitelistToken public daosWorldWhitelistToken;
    //    DaosWorldWhitelistToken public daosWorldWhitelistToken2;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        //        daosWorldWhitelistToken = new DaosWorldWhitelistToken();
        //        daosWorldWhitelistToken2 = new DaosWorldWhitelistToken();
        dwlConverter =
            new DWLConverter(0x956e1A6B5fF341e38C4e277a03E661A8801806f6, 0x41F86A22C05500Cb62DDC82B77C01C7c5912FA37);
        vm.stopBroadcast();
        console2.log("DWLConverter deployed to:", address(dwlConverter));
        //            address(daosWorldWhitelistToken),
        //            address(daosWorldWhitelistToken2)
    }
}

contract DaosWorldTiersFactoryScript is Script {
    DaosWorldTiersFactory public daosWorldTiersFactory;
    DaosWorldTiers public daosWorldTiers;
    DaosWorldV1Token public token;
    DaosWorldClaim public claim;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        daosWorldTiersFactory = new DaosWorldTiersFactory();
        DaosWorldTiers.DaoConfig memory daoConfig = DaosWorldTiers.DaoConfig(
            "abc",
            "ABC",
            0x626358e33076453160a58eBD03CbAEF3449F1964,
            0x626358e33076453160a58eBD03CbAEF3449F1964,
            1000,
            10001000100010001000,
            100010001000100010001,
            10001000100010001000,
            10001000100010001000,
            10001000100010001000,
            0x21104fA3b456d9171D46996eE8Bfb377a936bf5d
        );
        daosWorldTiers = new DaosWorldTiers(daoConfig);
        token = new DaosWorldV1Token("truce", "TRUE");
        claim = new DaosWorldClaim(address(daosWorldTiers), 0x9d5536f05357510E0751F2114D70d16925d00B71);
        vm.stopBroadcast();
        console2.log("DaosWorldTiersFactory deployed to:", address(daosWorldTiersFactory));
        console2.log("DaosWorldTiers deployed to:", address(daosWorldTiers));
        console2.log("DaosWorldV1Token deployed to:", address(token));
        console2.log("DaosWorldClaim deployed to:", address(claim));
    }
}

contract SniperManagerScript is Script {
    SniperManager public sniperManager;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        sniperManager = new SniperManager();
        vm.stopBroadcast();
        console2.log("SniperManager deployed to:", address(sniperManager));
    }
}

contract DaosWorldTiersFactoryV2Script is Script {
    DaosWorldTiersFactoryV2 public daosWorldTiersFactory;
    DaosWorldTiersV2 public daosWorldTiers;
    DaosWorldV2Token public token;
    DaosWorldClaim public claim;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        daosWorldTiersFactory = new DaosWorldTiersFactoryV2();
        DaosWorldTiersV2.DaoConfig memory daoConfig = DaosWorldTiersV2.DaoConfig(
            "abc",
            "ABC",
            0x626358e33076453160a58eBD03CbAEF3449F1964,
            0x626358e33076453160a58eBD03CbAEF3449F1964,
            1000,
            10001000100010001000,
            100010001000100010001,
            10001000100010001000,
            10001000100010001000,
            10001000100010001000,
            0x21104fA3b456d9171D46996eE8Bfb377a936bf5d,
            0x54BaF5C5050b629886fa99273D412E6A05D0C393
        );
        daosWorldTiers = new DaosWorldTiersV2(daoConfig);
        token = new DaosWorldV2Token("truce", "TRUE", 0x54BaF5C5050b629886fa99273D412E6A05D0C393);
        claim = new DaosWorldClaim(address(daosWorldTiers), 0x9d5536f05357510E0751F2114D70d16925d00B71);
        vm.stopBroadcast();
        console2.log("DaosWorldTiersFactory deployed to:", address(daosWorldTiersFactory));
        console2.log("DaosWorldTiers deployed to:", address(daosWorldTiers));
        console2.log("DaosWorldV1Token deployed to:", address(token));
        console2.log("DaosWorldClaim deployed to:", address(claim));
    }
}
