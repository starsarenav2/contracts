const { ethers, upgrades } = require('hardhat');

async function main() {
    const [deployer] = await ethers.getSigners();
    const deployerAddress = await deployer.getAddress();
    console.log('Deploying StarShares with address:', deployerAddress);

    const StarShares = await ethers.getContractFactory('StarShares');
    const starShares = await upgrades.deployProxy(StarShares, [/* constructor arguments here */]);
    await starShares.deployed();

    console.log('StarShares deployed to:', starShares.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
