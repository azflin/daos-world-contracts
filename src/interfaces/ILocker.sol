// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ILockerFactory {
    function deploy(
        address token,
        address beneficiary,
        uint256 durationSeconds,
        uint256 tokenId,
        uint256 fees,
        address daoTreasury
    ) external payable returns (address);
}

interface ILocker {
    function initializer(uint256 tokenId) external;
    function extendFundExpiry(uint256 fundExpiry) external;
}
