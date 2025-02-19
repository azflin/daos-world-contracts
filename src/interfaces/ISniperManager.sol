//SPDX-License-Identifier: None
pragma solidity 0.8.26;

interface ISniperManager {
    function isSniper(address account) external view returns (bool);
}
