// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {DaosWorldV2} from "./DaosWorldV2.sol";

import {Bytes32AddressLib} from "./lib/external/Bytes32AddressLib.sol";

contract DaosWorldFactoryV2 is Ownable {
    using Bytes32AddressLib for bytes32;

    address public constant WETH = 0x4200000000000000000000000000000000000006;
    // if true, only the protocol admin (owner) can deploy
    bool public gatedDeployments = true;

    event DaosWorldCreated(address indexed dao);

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
        uint256 maxPublicContributionAmount
    ) external returns (DaosWorldV2 dao) {
        if (gatedDeployments) {
            require(msg.sender == owner());
        }
        dao = new DaosWorldV2(
            _fundraisingGoal,
            _name,
            _symbol,
            _fundraisingDeadline,
            _fundExpiry,
            daoManager,
            liquidityLockerFactory,
            maxWhitelistAmount,
            owner(),
            maxPublicContributionAmount
        );
        emit DaosWorldCreated(address(dao));
    }

    function setGatedDeployments(bool _gatedDeployments) external onlyOwner {
        gatedDeployments = _gatedDeployments;
    }
}
