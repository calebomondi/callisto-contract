// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@aave/core-v3/contracts/interfaces/IPool.sol";
import "@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol";
import "@aave/core-v3/contracts/interfaces/IPoolDataProvider.sol";

import "../../interfaces/ILendManager.sol";

contract LendManager is Ownable, ReentrancyGuard, ILendManager {
    // User -> Token -> Principal Locked
    mapping(address => mapping(address => uint256)) public principal;

    // User -> Token -> User's Last Known Index
    mapping(address => mapping(address => uint256)) public userIndex;

    event LiquidIndex(string found);
    event AaveDeposit(address indexed token, uint amount, address onBehalfOf);
    event AaveDepositFail(address indexed token, uint amount, address onBehalfOf);
    event AaveDepositFailWithReason(string reason);
    event CanSupply(uint supplyCap, uint totalSupply, uint amountToSupply, bool canSupply);
    
    constructor() Ownable(msg.sender) {}

    // @notice Get current liquidity index
    function getCurrentLiquidityIndex(
        address asset,
        address poolAddress
    ) public view returns (uint256) {
        IPool pool = IPool(poolAddress);
        
        // Get the reserve data struct
        DataTypes.ReserveData memory reserveData = pool.getReserveData(asset);
        
        // Return the liquidity index from the struct
        return reserveData.liquidityIndex;
    }

    // @notice Get actual balance + accrued interest
    function getAccumulatedBalance(
        address user, 
        address asset,
        address poolAddress
    ) public view returns (uint256) {
        if (principal[user][asset] == 0) return 0;

        uint256 index = getCurrentLiquidityIndex(asset, poolAddress);

        return principal[user][asset] * index / userIndex[user][asset];
    }

    // @notice Set the Principal and userIndex
    function userSupply(
        address user, 
        address asset, 
        uint amount,
        address poolAddress
    ) external nonReentrant { 
        //update principle and userIndex
        uint balance = getAccumulatedBalance(user, asset, poolAddress);
        principal[user][asset] = balance + amount;
        userIndex[user][asset]  = getCurrentLiquidityIndex(asset, poolAddress);      
    }

    //update user principal
    function updatePrincipal(
        address user, 
        address asset, 
        uint amountToDeduct,
        address poolAddress
    ) external nonReentrant {
        //update principle and userIndex
        uint balance = getAccumulatedBalance(user, asset, poolAddress);
        
        //if there is enough amount of principal to pay for the withdrawal + accrued interest then subtract from the principal 
        if (balance >= amountToDeduct) {
            principal[user][asset] = balance - amountToDeduct;
            
            userIndex[user][asset]  = getCurrentLiquidityIndex(asset, poolAddress);  
        }
    }

    //check if can supply
    function canSupply(uint _amount, address _asset, address _dataProvider) external returns (bool) {
        IPoolDataProvider dataProvider = IPoolDataProvider(_dataProvider);

        //get supply cap for asset
        (,uint supplyCap) = dataProvider.getReserveCaps(_asset);

        //cap 0 = no supply cap
        if (supplyCap == 0) return true;
        
        //get total supply
        (,,uint256 totalAToken,,,,,,,,,) = dataProvider.getReserveData(_asset);

        //can supply
        bool supply = totalAToken + _amount < supplyCap;

        emit CanSupply(supplyCap, totalAToken, _amount, supply);

        return supply;
    }
}