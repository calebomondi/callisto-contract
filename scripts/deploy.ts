import { ethers } from 'hardhat';
 
async function main() {
    /*/deploy main contract
    const main = await ethers.deployContract('Main');
    await main.waitForDeployment();
    console.log('Main Contract Deployed at ' + main.target);
    */
    //deploy LendManager then contract
    const lendmanager = await ethers.deployContract('LendManager');
    await lendmanager.waitForDeployment();
    console.log('LendManager Contract Deployed at ' + lendmanager.target);

    //deploy LockAsset contract
    const lockasset = await ethers.deployContract('LockAsset', [lendmanager.target]);
    await lockasset.waitForDeployment();
    console.log('LockAsset Contract Deployed at ' + lockasset.target);
}
 
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});