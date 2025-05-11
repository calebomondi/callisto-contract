// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@aave/core-v3/contracts/interfaces/IPool.sol";

import {ILockAsset} from "../../interfaces/ILockAsset.sol";
import {IWETH} from "../../interfaces/IWETH.sol";
import {ILendManager} from "../../interfaces/ILendManager.sol";
import {LockDataTypes} from "../../types/LockDataTypes.sol";
import {MathUtils} from "../../protocol/libraries/math/MathUtils.sol";

contract LockAsset is ILockAsset, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    //create LendManager instance
    ILendManager lendManager;

    /*
    *@notice structs with nested mappings for vaults and transanctions and their variables
    */
    struct Vaults {
        // User -> Vault
        mapping(address => LockDataTypes.Vault[])  userVaults;
    }
    struct Transanctions {
        // User -> Vault ID -> Transaction History
        mapping(address => mapping(uint16 => LockDataTypes.TransacHist[]))  userTransactions;
    }
    struct Earnings {
        // Platform -> Earnings Records
        mapping(address => LockDataTypes.Revenue[]) platformRevenue;
    }

    Vaults private vaults;
    Transanctions private transactions;
    Earnings private earnings;

    // Asset -> totalAmount
    mapping(address => uint256) public totalAssetLocked;

    // Asset -> User -> amountLocked
    mapping(address => mapping(address => uint256)) public userLockedAsset;

    //Transaction fee %
    uint8 public transacFee = 5;
    uint8 public emergencyTransacFee = 50;
    uint8 public gainTransacFee = 50;
    uint16 public transacFeeBase = 1000;

    /*events*/
    event AssetDeposit(string title, address indexed depositer, uint256 amount, uint timestamp);
    event AssetWithdrawal(string title, uint256 amount, uint timestamp);
    event VaultDeleted(string title);
    event Emergency(string title);
    event AaveDeposit(address indexed token, uint amount, address onBehalfOf);
    event AaveDepositFail(string failed);
    event AaveDepositFailWithReason(string reason);
    event AaveWithdraw(address indexed token, uint amount, address onBehalfOf);
    event AaveWithdrawFail(string failed);
    event AaveWithdrawFailWithReason(string reason);
    event AaveApproved(string status);
    event AaveApprovalFail(string status);
    event WithdrawFailed(string status);
    event WithdrawFailedWithReason(string status);
    event Debug(string reason);

    constructor(
        address _lendManagerAddress
    ) Ownable(msg.sender) {
        lendManager = ILendManager(_lendManagerAddress);
    }
    
    /*
    *@notice Implements the creation of Eth vault and initial deposit
    *@param _title The name of the vault
    *@param _lockperiod The time period to lock the assets
    *@param _vaultType The type of vault to create (fixed, scheduled, goal)
    *@param _unlockduration The period within which a portion of locked asset can be avalible to withdraw (for scheduled vaults)
    *@param _unlockfreq How often to unlock portion of assets (after, every, when)
    *@param _unlockamount The amount to unlock after each onlock duration expires
    *@param _unlockgoal For goal acounts, the value of locked assets to reach to unlock vault
    */
    function createEthVault(
        string memory _title,
        uint8 _lockperiod,
        string memory _vaultType,
        int8 _neededSlip,
        uint8 _unlockduration,
        uint _unlockamount,
        uint _unlockgoal,
        address _pool,
        address _dataProvider,
        address _weth
    ) external payable nonReentrant {
        require (msg.value > 0, 'Deposit Must Be Greater Than Zero!');
        require (_lockperiod > 0, 'Lock Duration Must Be Greater Than Zero');

        //get vaultId
        uint16 vaultID = getUserVaultCount(msg.sender);

        // Wrap ETH to WETH
        IWETH(_weth).deposit{value: msg.value}();

        // Check if can supply to aave and create vault
        Main(
            _title, 
            _lockperiod,
            msg.value, 
            _weth, 
            _pool, 
            _dataProvider, 
            _vaultType, 
            _neededSlip, 
            _unlockduration, 
            _unlockamount, 
            _unlockgoal, 
            vaultID,
            true
        );

    }

    /*
    *@notice Implements the addition of Eth to a vault
    *@param _vaultId  Specifies the Vault to add to
    *@param _owner The owner of the vault
    */
    function depositEth(
        address _owner,
        uint16 _vaultId,
        address _pool, 
        address _dataProvider
    ) external payable override nonReentrant {
        require(msg.value > 0, 'Deposit Must Be More Than Zero!');

        address vaultAsset = vaults.userVaults[_owner][_vaultId].asset;
        uint32 vaultEndDate = vaults.userVaults[_owner][_vaultId].endDate;
        string memory vaultTitle = vaults.userVaults[_owner][_vaultId].title;

        require(vaultEndDate > block.timestamp, 'Vault Expired');

        //wrap ETH to WETH
        IWETH(vaultAsset).deposit{value: msg.value}();

        //add asset
        addAsset(
            _owner, 
            _vaultId, 
            msg.value, 
            vaultAsset, 
            _pool, 
            _dataProvider, 
            vaultTitle
        );
    }

    /*
    *@notice Implements the creation of Token vault and initial deposit
    *@param _token The Address of the token to lock
    *@param _title The name of the vault
    *@param _amount The amount of the vault to lock
    *@param _lockperiod The time period to lock the assets
    *@param _vaultType The type of vault to create (fixed, scheduled, goal)
    *@param _unlockduration The period within which a portion of locked asset can be avalible to withdraw (for scheduled vaults)
    *@param _unlockfreq How often to unlock portion of assets (after, every, when)
    *@param _unlockamount The amount to unlock after each onlock duration expires
    *@param _unlockgoal For goal acounts, the value of locked assets to reach to unlock vault
    */
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
        address _pool,
        address _dataProvider
    ) external  override nonReentrant {
        require(_amount > 0, 'Amount To Lock Cannot Be Less Than 0!');
        require(_lockperiod > 0 , 'Lock Duration Must Be Greater Than 0!');

        //check balance
        require(_amount <= IERC20(_token).balanceOf(msg.sender), 'You Have Insufficient Balance!');

        //transfer amount to contract address
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);

        //get vaultId
        uint16 vaultID = getUserVaultCount(msg.sender);

        // Check if can supply to aave and create vault
        Main(
            _title, 
            _lockperiod,
            _amount, 
            _token, 
            _pool, 
            _dataProvider, 
            _vaultType, 
            _neededSlip, 
            _unlockduration, 
            _unlockamount, 
            _unlockgoal, 
            vaultID,
            false
        );

    }

    /*
    *@notice Implements the addition of tokens to a vault
    *@param _owner The owner of the vault
    *@param _vaultId  Specifies the Vault to add to
    *@param _amount The name of the amount to add
    */
    function depositToken(
        address _owner,
        uint16 _vaultId,
        uint _amount,
        address _pool, 
        address _dataProvider
    ) external override nonReentrant {
        require(_amount > 0, 'Deposit Must Be More Than Zero!');

        address vaultAsset = vaults.userVaults[_owner][_vaultId].asset;
        uint32 vaultEndDate = vaults.userVaults[_owner][_vaultId].endDate;
        string memory vaultTitle = vaults.userVaults[_owner][_vaultId].title;

        require(vaultEndDate > block.timestamp, 'Vault Expired');

        // create token instance
        IERC20 thisToken = IERC20(vaultAsset);

        // check balance
        uint256 _tokenBalance = thisToken.balanceOf(msg.sender);
        require(_amount <= _tokenBalance, 'You Have Insufficient Balance!');

        // transfer amount to contract address
        thisToken.transferFrom(msg.sender, address(this), _amount);

        // add asset to vault
        addAsset(
            _owner, 
            _vaultId, 
            _amount, 
            vaultAsset, 
            _pool, 
            _dataProvider, 
            vaultTitle
        );
    }

    //
    function addAsset(
        address _owner,
        uint16 _vaultId,
        uint _amount, 
        address _token, 
        address _pool, 
        address _dataProvider,
        string memory title
    ) internal {        
        //calculate platform fee
        uint platformFee = MathUtils.calculateFee(_amount, transacFee, transacFeeBase);

        //take platform share and record aerning
        transfer_n_record(platformFee, _token);

        uint afterFee = _amount - platformFee;

        //Only approve and deposit for aave approved tokens and if supply cap not exceeded
        if(
            lendManager.getCurrentLiquidityIndex(_token, _pool) != 0 &&
            lendManager.canSupply(afterFee, _token, _dataProvider)
        ) {
            //approve then try to supply
            try IERC20(_token).approve(address(_pool), afterFee) {
                emit AaveApproved("Approval Success!");
            
                try IPool(_pool).supply(_token, afterFee, address(this), 0) {
                    lendManager.userSupply(_owner, _token, afterFee, _pool);
                    
                    emit  AaveDeposit(_token, afterFee, msg.sender);
                } catch Error(string memory reason) {
                    emit AaveDepositFailWithReason(reason);
                } catch(bytes memory) {
                    emit  AaveDepositFail("Failed To Supply Aaave!");
                }  
            } catch {
                emit AaveApprovalFail("Approval failed!");
            }
        } 

        //update amount in vault
        uint accumBalance = lendManager.getAccumulatedBalance(_owner, _token, _pool);

        if(accumBalance > 0) {
            vaults.userVaults[_owner][_vaultId].amount = accumBalance;
        } else {
            vaults.userVaults[_owner][_vaultId].amount += afterFee;
        }
        vaults.userVaults[_owner][_vaultId].principal += afterFee;

        //record transactions
        recordTransac(_owner, _vaultId, afterFee, false);

        //accumulate amount
        totalAssetLocked[_token] += afterFee;
        userLockedAsset[_token][_owner] += afterFee;

        emit AssetDeposit(title, msg.sender, afterFee, block.timestamp);

    }

    //
    function Main(
        string memory _title,
        uint8 _lockperiod,
        uint _amount, 
        address _token, 
        address _pool, 
        address _dataProvider,
        string memory _vaultType,
        int8 _neededSlip,
        uint8 _unlockduration,
        uint _unlockamount,
        uint _unlockgoal,
        uint16 vaultID,
        bool _native
    ) internal {
        //calculate platform fee and record
        uint platformFee = MathUtils.calculateFee(_amount, transacFee, transacFeeBase);

        //take platform share and record aerning
        transfer_n_record(platformFee, _token);

        uint afterFee = _amount - platformFee;

        //Only approve and deposit for aave approved tokens and if supply cap not exceeded
        if(lendManager.getCurrentLiquidityIndex(_token, _pool) != 0) {
            if(lendManager.canSupply(afterFee, _token, _dataProvider)) {
                //approve then try to supply
                try IERC20(_token).approve(address(_pool), afterFee) {
                    emit AaveApproved("Approval Success!");
                
                    try IPool(_pool).supply(_token, afterFee, address(this), 0) {
                        lendManager.userSupply(msg.sender, _token, afterFee, _pool);
                        
                        emit  AaveDeposit(_token, afterFee, msg.sender);
                    } catch Error(string memory reason) {
                        emit AaveDepositFailWithReason(reason);
                    } catch(bytes memory) {
                        emit  AaveDepositFail("Failed To Supply Aaave!");
                    }  
                } catch {
                    emit AaveApprovalFail("Approval failed!");
                }
            } 
        }

        vaults.userVaults[msg.sender].push(LockDataTypes.Vault({
            owner: msg.sender,
            asset:  _token,
            native: _native,
            principal: afterFee,
            amount: afterFee,
            unLockedTotal: 0,
            startDate: uint32(block.timestamp),
            //endDate: uint32(block.timestamp) + 600, 
            endDate: uint32(block.timestamp) + (_lockperiod * 86400),
            vaultType: _vaultType,
            neededSlip: _neededSlip,
            unLockDuration: _unlockduration,
            unLockAmount: _unlockamount,
            unLockGoal: _unlockgoal,
            title: _title,
            emergency: false
        }));

        //record transactions
        recordTransac(msg.sender, vaultID, afterFee, false);

        //accumulate amount
        totalAssetLocked[_token] +=  afterFee;
        userLockedAsset[_token][msg.sender] +=  afterFee;

        emit AssetDeposit(_title, msg.sender, afterFee, block.timestamp);

    }

    /*
    *@notice Implements transaction fee charging and recording of earnings
    *@param platformFee  The amount to take and record
    *@param asset The asset to transfer and record for
    */
    function transfer_n_record(
        uint platformFee,
        address asset
    ) internal {
        // Check balance before transfer
        uint contractBalance = IERC20(asset).balanceOf(address(this));
        require(contractBalance >= platformFee, "Insufficient contract balance!");
            
        //take platform share
        IERC20(asset).safeTransfer(owner(), platformFee);

        //record earnings
        earnings.platformRevenue[owner()].push(LockDataTypes.Revenue({
            asset: asset,
            amount: platformFee,
            timestamp: uint32(block.timestamp)
        }));
    }

    /*
    *@notice Implements the withdrawal of assets from schedule and goal based vaults
    *param _vaultId The Id of the vault to withdraw from
    *param _amount The amount to withdraw
    *param _goalReached Checks whether vault is being unlocked due to goal achievement or schedule
    */
    function withdraw(
        uint16 _vaultId,
        uint _amount,
        address _poolAddress,
        bool _goalReached
    ) external nonReentrant {
        LockDataTypes.Vault memory vault = getUserVaultByIndex(msg.sender, _vaultId);

        require(_amount > 0 && _amount <= vault.amount, "Amount To Withdraw > 0!");

        if(_goalReached) {
            require( block.timestamp < vault.endDate, "Lock Period Has Expired!");
        } else {
            require( block.timestamp > vault.endDate, "Lock Period Has Not Yet Expired!");
        }

        vaults.userVaults[msg.sender][_vaultId].unLockedTotal += _amount;
        vaults.userVaults[msg.sender][_vaultId].principal -= _amount;

        bool wasSupplied = false;
        uint toWithdraw = _amount;
        
        // get accumulated balance and principal
        uint accumBalance = lendManager.getAccumulatedBalance(msg.sender, vault.asset, _poolAddress);

        //check if supplied to aave and withdraw with accumulated interest
        if(accumBalance > 0) {
            wasSupplied = true;           
            vaults.userVaults[msg.sender][_vaultId].amount = accumBalance - _amount;
            
            try IPool(_poolAddress).withdraw(vault.asset, _amount, address(this)) {
                lendManager.updatePrincipal(msg.sender, vault.asset, _amount, _poolAddress);

                emit AaveWithdraw(vault.asset, _amount, address(this));
            } catch Error(string memory reason) {
                emit AaveWithdrawFailWithReason(reason);
                return;
            } catch (bytes memory) {
                emit AaveWithdrawFail("Failed to withdraw Asset!");
                return;
            }
            
        } 
        
        if(!wasSupplied){
            vaults.userVaults[msg.sender][_vaultId].amount -= _amount;
        }
        
        if((wasSupplied && (accumBalance > vault.principal)) || vault.emergency) {
            //calculate platform fee
            uint platformFee = MathUtils.calculateFee(_amount, vault.emergency ? emergencyTransacFee : gainTransacFee, transacFeeBase);

            //take platform share and record aerning
            transfer_n_record(platformFee, vault.asset);

            toWithdraw -= platformFee;       
        }
        
        uint thisAsset = IERC20(vault.asset).balanceOf(address(this));
        require(thisAsset >= toWithdraw, "Insufficient WETH balance for unwrapping");
        
        if (vault.native) {
            // First unwrap WETH to ETH
            try IWETH(vault.asset).withdraw(toWithdraw) {
                // Then send ETH to user
                (bool success, ) = msg.sender.call{value: toWithdraw}("");
                require(success, "ETH transfer failed");
            } catch Error(string memory reason) {
                emit AaveWithdrawFail(reason);
                return;
            } catch (bytes memory) {
                emit AaveWithdrawFail("Failed To Withdraw Asset!");
                return;
            }
        } else {
            // If not native, transfer ERC20
            IERC20(vault.asset).safeTransfer(msg.sender, toWithdraw);
        }
    
        //record transaction
        recordTransac( msg.sender, _vaultId, toWithdraw, true);

        //deduct amount
        totalAssetLocked[vault.asset] -=  toWithdraw;
        userLockedAsset[vault.asset][msg.sender] -=  toWithdraw;

        emit AssetWithdrawal(vault.title, toWithdraw, block.timestamp);        
    }

    // Allow contract to receive ETH from WETH withdraw
    receive() external payable {}

    /*
    *@notice Implements the withdrawal of funds under an emergency
    *param _vaultId The Id of the vault to withdraw from
    *param _slippage If the emergency is due to a slippage in asset value
    */
    function emergencyUnlock(
        uint16 _vaultId,
        bool _slip
    ) external {
        uint32 vaultEndDate = vaults.userVaults[msg.sender][_vaultId].endDate;
        string memory vaultTitle = vaults.userVaults[msg.sender][_vaultId].title;
        address vaultOwner = vaults.userVaults[msg.sender][_vaultId].owner;

        require(msg.sender == vaultOwner, "Only The Owner Of The Vault Can Unlock!");
        require( block.timestamp < vaultEndDate, "Lock Period Has Expired!");

        vaults.userVaults[msg.sender][_vaultId].endDate = uint32(block.timestamp);

        if (!_slip) {
            vaults.userVaults[msg.sender][_vaultId].emergency = true;
        }

        emit Emergency(vaultTitle);
    }

    /*
    *@notice Implements the recording of vault transanctions
    *param _vaultOwner The address of the owner of the vault
    *param _vaultId The Id of the vault to which the transaction was made
    *param _amount The amount to that was transacted
    *param _withdraw Check if the transaction was a withdrawal, if not it was a deposit
    */
    function recordTransac(
        address _vaultOwner,
        uint16 _vaultId, 
        uint256 _amount, 
        bool _withdraw
    ) internal {
        transactions.userTransactions[_vaultOwner][_vaultId].push(LockDataTypes.TransacHist({
            depositor: msg.sender,
            amount: _amount,
            withdrawn: _withdraw,
            timestamp: uint32(block.timestamp)
        }));
    }

    /*
    *@notice Implements the setting up of the transaction fee
    *param _newFee The new transaction fee to be charged
    *@dev the denominator of transaction fee is 1000
    *@dev the numberator will start from 1, where 1 represents 0.1%
    */
    function setTransactionFee(uint8 _newFee) external onlyOwner {
        transacFee = _newFee;
    }

    /*
    *@notice Implements the setting up of the emergency transaction fee
    *param _newFee The new emergency fee to be charged
    *@dev the denominator of transaction fee is 1000
    *@dev the numberator will start from 1, where 1 represents 0.1%
    */
    function setEmergencyTransactionFee(uint8 _newFee) external onlyOwner {
        emergencyTransacFee = _newFee;
    }

    /*
    *@notice Implements the setting up of the gain transaction fee
    *param _newFee The new gain fee to be charged
    *@dev the denominator of transaction fee is 1000
    *@dev the numberator will start from 1, where 1 represents 0.1%
    */
    function setGainTransactionFee(uint8 _newFee) external onlyOwner {
        gainTransacFee = _newFee;
    }

    /*
    *@notice Retrieves the number of vaults under an address
    *@param _owner The address of the account that owns the vaults
    *@return an integer representing the number of vaults
    */
    function getUserVaultCount(address _owner) public  view returns (uint16) {
        return uint16(vaults.userVaults[_owner].length);
    }

    /*
    *@notice Allows the retrieval  of vault data for a specific address
    *@param _owner The address of the account that owns the vaults
    *@param _vaultId  Specifies the Vault to add to
    *@return an array with one element of type LockDataTypes.Vault object 
    */
    function getUserVaultByIndex(
        address _owner, 
        uint256 _vaultId
    ) public view returns (LockDataTypes.Vault memory) {
        return vaults.userVaults[_owner][_vaultId];
    }

    /*
    *@notice Allows the retrieval of a vault's transanctions
    *@param _owner The address of the account that owns the vaults
    *@param _vaultId  Specifies the Vault to add to
    *@return array of LockDataTypes.TransacHist objects containing information about all transactions for a particular vault
    */
    function getUserTransactions(
        address _owner, 
        uint16 _vaultId
    ) external view returns (LockDataTypes.TransacHist[] memory ) {
        return transactions.userTransactions[_owner][_vaultId];
    }

    /*
    *@notice Retrieves the platforms earnings from the charged fees
    *@return array of LockDataTypes.Revenue objects containing all fees charged from transactions made
    */
    function getPlatformEarnings() external view returns (LockDataTypes.Revenue[] memory ) {
        return earnings.platformRevenue[owner()];
    }

    /*
    *@notice Implements the deletion of a vault
    *param _vaultId The Id of the vault to delete from
    */
    function deleteVault(
        uint16 _vaultId
    ) external {
        LockDataTypes.Vault memory vault = getUserVaultByIndex(msg.sender, _vaultId);

        require(msg.sender == vault.owner, "You Are Not The Owner Of This Vault, Cannot Delete!");
        require(block.timestamp > vault.endDate, "Lock Period Not Yet Expired!");
        require(vault.amount == 0, "Withdraw All Assets Before Deleting!");

        //get last index
        uint16 lastIndex = getUserVaultCount(msg.sender) - 1;

        //swap if asset ID not last index
        if(_vaultId != lastIndex) {
            vaults.userVaults[msg.sender][_vaultId] = vaults.userVaults[msg.sender][lastIndex];
        }

        //remove last element
        vaults.userVaults[msg.sender].pop();

        emit VaultDeleted(vault.title);
    }
}