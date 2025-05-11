// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library MathUtils {
    //when depositing to a vault
    function calculateFee(
        uint receivedAmount, 
        uint8 feePercent, 
        uint16 feeBase
    ) internal pure returns (uint256) {
        uint fee = (receivedAmount * feePercent) /  feeBase;
        return fee;
    }
}