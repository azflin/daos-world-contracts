// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {DaosWorldV2Vesting} from "./DaosWorldV2Vesting.sol";

import {Bytes32AddressLib} from "./lib/external/Bytes32AddressLib.sol";

contract DaosWorldFactoryV2Vesting is Ownable {
    using Bytes32AddressLib for bytes32;

    address public constant WETH = 0x4200000000000000000000000000000000000006;
    // if true, only the protocol admin (owner) can deploy
    bool public gatedDeployments = true;

    event DaosWorldCreated(address dao);

    constructor() Ownable(msg.sender) {}

    function deployDao(
        string calldata _name,
        string calldata _symbol,
        uint256 _fundraisingGoal,
        uint256 _fundraisingDeadline,
        uint256 _fundExpiry,
        address daoManager,
        address liquidityLockerFactory,
        uint256 maxWhitelistAmount,
        uint256 maxPublicContributionAmount,
        address daosWorldPayFactory
    ) external returns (DaosWorldV2Vesting dao) {
        if (gatedDeployments) {
            require(msg.sender == owner());
        }
        dao = new DaosWorldV2Vesting(
            DaosWorldV2Vesting.Config({
                _fundraisingGoal: _fundraisingGoal,
                _name: _name,
                _symbol: _symbol,
                _fundraisingDeadline: _fundraisingDeadline,
                _fundExpiry: _fundExpiry,
                _daoManager: daoManager,
                _liquidityLockerFactory: liquidityLockerFactory,
                _maxWhitelistAmount: maxWhitelistAmount,
                _protocolAdmin: owner(),
                _maxPublicContributionAmount: maxPublicContributionAmount,
                _daosWorldPayFactory: daosWorldPayFactory
            })
        );

        emit DaosWorldCreated(address(dao));
    }

    function setGatedDeployments(bool _gatedDeployments) external onlyOwner {
        gatedDeployments = _gatedDeployments;
    }
}
