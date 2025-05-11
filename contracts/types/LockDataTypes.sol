// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LockDataTypes {
    //Vault DataType
    struct Vault {
        /*owner*/
        address owner;
        /*asset details*/
        address asset;
        bool native;
        /*lock amount and duration*/
        uint principal;
        uint amount;
        uint unLockedTotal;
        uint32 startDate;
        uint32 endDate;
        /*Vault Type*/
        string vaultType;   //'fixed', 'schedule', 'goal'
        int8 neededSlip;
        //schedule
        uint8 unLockDuration;
        uint unLockAmount;
        //fixed
        uint unLockGoal;
        /*Vault Details*/
        string title;
        bool emergency;
    }

    //Transactions DataType
    struct TransacHist {
        address depositor;
        uint256 amount;
        bool withdrawn;
        uint32 timestamp;
    }

    //revenue tracking
    struct Revenue {
        address asset;
        uint amount;
        uint32 timestamp;
    }
}