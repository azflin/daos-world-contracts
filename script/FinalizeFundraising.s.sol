// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/DaosWorld404.sol";
import "../src/DaosWorld404Token.sol";

contract FinalizeFundraisingScript is Script {
    int24 initialTick = -171400;
    int24 upperTick = 887200;
    address weth = 0x4200000000000000000000000000000000000006;
    string name = "Bear";
    string symbol = "Bear";
    string tokenBaseURI = "https://google.com";
    uint8 decimals = 18;
    uint256 maxTotalSupplyERC721 = 10000;
    uint256 unitsPerNFT = 10000 * 1e18;
    address initialOwner = 0x0c0d274060766d0F8DcDebc8c4B305a3e8a676C0;
    address initialMintRecipient = 0x0c0d274060766d0F8DcDebc8c4B305a3e8a676C0;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address payable daosWorldAddress = payable(vm.envAddress("DAOSWORLD_ADDRESS"));
        DaosWorld404 daosWorld = DaosWorld404(daosWorldAddress);

        // Setup

        vm.startBroadcast(deployerPrivateKey);

        bytes32 initCodeHash = keccak256(
            abi.encodePacked(
                type(DaosWorld404Token).creationCode,
                abi.encode(
                    name, symbol, tokenBaseURI, decimals, maxTotalSupplyERC721, initialOwner, initialMintRecipient
                )
            )
        );

        bytes32 salt;
        address computedAddr;
        uint256 attempts = 0;
        bool found = false;

        while (attempts < 1000) {
            attempts++;
            salt = keccak256(abi.encodePacked(attempts, block.timestamp, name, symbol));

            computedAddr = address(
                uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), daosWorldAddress, salt, initCodeHash))))
            );

            if (computedAddr < weth) {
                found = true;
            }
            try daosWorld.finalizeFundraising(initialTick, upperTick, tokenBaseURI, salt, 1, 1 * 1e18) {
                console2.log("Salt found after attempts:", attempts);
                console2.log("Salt:", vm.toString(salt));

                found = true;
                break;
            } catch Error(string memory reason) {
                console2.log("Reverted with reason:", reason);
            } catch (bytes memory data) {
                console2.log("Reverted with unknown error:", vm.toString(data));
            }
        }

        require(found, "No valid salt found");

        vm.stopBroadcast();
    }
}
