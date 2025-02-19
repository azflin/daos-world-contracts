// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {LpLocker} from "./LpLocker.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract LockerFactory is Ownable(msg.sender) {
    event deployed(address indexed lockerAddress, address indexed owner, uint256 tokenId, uint256 lockingPeriod);

    address public protocolAdmin;

    constructor() {
        protocolAdmin = msg.sender;
    }

    function deploy(
        address v3PositionManager,
        address daoManager,
        uint256 fundExpiry,
        uint256 tokenId,
        uint256 fees,
        address _daoTreasury
    ) public payable returns (address) {
        address newLockerAddress =
            address(new LpLocker(v3PositionManager, daoManager, fundExpiry, fees, protocolAdmin, _daoTreasury));

        if (newLockerAddress == address(0)) {
            revert("Invalid address");
        }

        emit deployed(newLockerAddress, daoManager, tokenId, fundExpiry);

        return newLockerAddress;
    }

    function setProtocolAdmin(address _protocolAdmin) public onlyOwner {
        protocolAdmin = _protocolAdmin;
    }
}
