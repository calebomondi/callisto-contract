// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LockDataTypes} from "contracts/types/LockDataTypes.sol";

interface ILockAsset {
    //Create ETH Vault
    function createEthVault(
        string memory _title,
        uint8 _lockperiod,
        string memory _vaultType,
        int8 _neededSlip,
        uint8 _unlockduration,
        uint _unlockamount,
        uint _unlockgoal,
        //aave addresses
        address _pool,
        address _dataProvider,
        address _weth
    ) external payable;

    //Create Token Vault
    function createTokenVault(
        address _token, 
        string memory _title,
        uint _amount,
        uint8 _lockperiod,
        string memory _vaultType,
        int8 _neededSlip,
        uint8 _unlockduration,
        uint _unlockamount,
        uint _unlockgoal,
        //aave addresses
        address _pool,
        address _dataProvider
    ) external;

    //Add more ETH to a vault
    function depositEth(
        address owner,
        uint16 vaultId,
        address _pool, 
        address _dataProvider
    ) external payable;

    //Add more ETH to a vault
    function depositToken(
        address _owner,
        uint16 _vaultId,
        uint _amount,
        address _pool, 
        address _dataProvider
    ) external;

    //withdraw ETH from schedule or goal vaults
     function withdraw(
        uint16 _vaultId, 
        uint _amount,
        address _poolAddress,
        bool _goalReached
    ) external;

    //unlock vault due to an emergency
    function emergencyUnlock(
        uint16 _vaultId,
        bool _slip
    ) external ;

    //update the transactional fee
    function setTransactionFee(
        uint8 _newFee
    ) external;

    //update the emergency transactional fee
    function setEmergencyTransactionFee(
        uint8 _newFee
    ) external;

    //get vault transactions
    function getUserTransactions(
        address _owner, 
        uint16 _vaultId
    ) external view returns (LockDataTypes.TransacHist[] memory );

    //delete the vault
    function deleteVault(
        uint16 _vaultId
    ) external;

    //get total vaults count by an address
    function getUserVaultCount(
        address _owner
    ) external  view returns (uint16);

    //get specific vault  
    function getUserVaultByIndex(
        address _owner, 
        uint256 _vaultId
    ) external view returns (LockDataTypes.Vault memory);
}