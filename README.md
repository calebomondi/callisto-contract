# FVP SMART CONTRACTS

![Image](https://github.com/user-attachments/assets/15127a40-0f80-4416-a1c7-08f79d5678b4)

## Overview
FVP is a self-custodial financial management tool that allows users to better manage their crypto assets by allowing them to set up virtual vaults for locking the assets. The vaults will unlock when the set conditions are met. This will allow them to curb their impulsive spending behaviour and also to invest in their future by saving up in the locked vaults.

## Smart Contract Details
- **Solidity Version**: ^0.8.28
- **Frameworks & Libraries**: OpenZeppelin Contracts (IERC20, SafeERC20, ReentrancyGuard, Ownable)
- **Security Features**:
  - Prevents reentrancy attacks.
  - Uses SafeERC20 for secure token transactions.
  - Implements access control for admin-only functions such as contract pausing.

## Deployment
### Prerequisites
Ensure you have the following installed:
- Node.js
- Hardhat
- Metamask (for interacting with the contract)
- Infura or Alchemy RPC URL and API endpoints

### Steps
1. Clone the repository:
   ```sh
   git clone https://github.com/calebomondi/callisto-contract
   cd callisto-contract
   ```
2. Install dependencies:
   ```sh
   npm install
   ```
3. Compile the contract:
   ```sh
   npx hardhat compile
   ```
4. Deploy the contract:
   ```sh
   npx hardhat run scripts/deploy.js --network <network>
   ```

## Main Functions
1. `createEthVault()`: Create vault for ETH after wrapping it.
2. `createTokenVault()`: Create vault for ERC20 tokens.
3. `depositEth()`: Add more ETH to existing lock .
4. `depositToken()`: Add more tokens to existing lock.
5. `withdraw()`: Withdraw locked assets from an expired vault.
6. `emergencyUnlock()`: Breaks a vault making it withdrawable.

## Contributing
1. Fork the repository
2. Create your feature branch
3. Commit changes
4. Push to branch
5. Create pull request

## Verified and Published in Sepolia Blockscout and Sepolia Etherscan
1. [LendManager](https://basescan.org/address/0xA293820714506eeC12DDf3E8Fad3a1f8c5ADE26F#code)
2. [LockAsset](https://basescan.org/address/0x8135c6A0021D700C2e0101A3Fb23f86ed63a435e#code)
