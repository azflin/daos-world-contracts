//SPDX-License-Identifier: None
pragma solidity ^0.8.25;

import {DaosWorldPay} from "./DaosWorldPay.sol";

contract DaosWorldPayFactory {
    bytes32 constant INIT_CODEHASH = keccak256(type(DaosWorldPay).creationCode);

    address public parameter;
    uint256 public getDaosWorldPayContractCount;
    address[1000000000] public getDaosWorldPayContractByIndex; // 1 billion indices

    event DaosWorldPayCreated(address token, address llamaPay);

    /**
     * @notice Create a new Llama Pay Streaming instance for `_token`
     *     @dev Instances are created deterministically via CREATE2 and duplicate
     *         instances will cause a revert
     *     @param _token The ERC20 token address for which a Llama Pay contract should be deployed
     *     @return llamaPayContract The address of the newly created Llama Pay contract
     */
    function createDaosWorldPayContract(address _token) external returns (address llamaPayContract) {
        // set the parameter storage slot so the contract can query it
        parameter = _token;
        // use CREATE2 so we can get a deterministic address based on the token
        llamaPayContract = address(new DaosWorldPay{salt: bytes32(uint256(uint160(_token)))}());
        // CREATE2 can return address(0), add a check to verify this isn't the case
        // See: https://eips.ethereum.org/EIPS/eip-1014
        require(llamaPayContract != address(0));

        // Append the new contract address to the array of deployed contracts
        uint256 index = getDaosWorldPayContractCount;
        getDaosWorldPayContractByIndex[index] = llamaPayContract;
        unchecked {
            getDaosWorldPayContractCount = index + 1;
        }

        emit DaosWorldPayCreated(_token, llamaPayContract);
    }

    /**
     * @notice Query the address of the Llama Pay contract for `_token` and whether it is deployed
     *   @param _token An ERC20 token address
     *   @return predictedAddress The deterministic address where the llama pay contract will be deployed for `_token`
     *   @return isDeployed Boolean denoting whether the contract is currently deployed
     */
    function getDaosWorldPayContractByToken(address _token)
        external
        view
        returns (address predictedAddress, bool isDeployed)
    {
        predictedAddress = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(bytes1(0xff), address(this), bytes32(uint256(uint160(_token))), INIT_CODEHASH)
                    )
                )
            )
        );
        isDeployed = predictedAddress.code.length != 0;
    }
}
