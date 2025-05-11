// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILendManager {
    // get user's principal with accrued interest
    function getAccumulatedBalance(
        address user, 
        address token,
        address poolAddress
    ) external view returns (uint256);
    
    //set the vault principal
    function userSupply(
        address user, 
        address token, 
        uint amount,
        address poolAddress
    ) external;

    //update principal after withdrawal
    function updatePrincipal(
        address user, 
        address asset, 
        uint amountToDeduct,
        address poolAddress
    ) external;

    //get liquidity index
    function getCurrentLiquidityIndex(
        address asset,
        address poolAddress
    ) external view returns (uint256);

    //check if  aave supply cap is reached
    function canSupply(
        uint _amount, 
        address _asset, 
        address _dataProvider
    ) external returns (bool);
}