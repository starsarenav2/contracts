const { ethers } = require('hardhat');

async function main() {
    const [deployer] = await ethers.getSigners();
    const deployerAddress = await deployer.getAddress();
    console.log('Deploying StarShares with address:', deployerAddress);

    const proxyAdmin = await ethers.getContractAt('ProxyAdmin', '0x87A610E176731Ad38da8ab88E0B82acA234A3A9b');

    console.log('StarShares deployed to:', proxyAdmin.address);
    const x = await proxyAdmin.upgrade('0xA481B139a1A654cA19d2074F174f17D7534e8CeC', '0x8aF92C23a169B58c2E5AC656D8D8a23FC725080f');

    console.log('StarShares deployed to:', x);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
