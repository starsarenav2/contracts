const { ethers, upgrades, run } = require('hardhat');

async function main() {
    const [deployer] = await ethers.getSigners();
    const deployerAddress = await deployer.getAddress();
    console.log('Deploying StarsArena with address:', deployerAddress);

    const StarsArena = await ethers.getContractFactory('StarsArena');
    const starsArena = await upgrades.deployProxy(StarsArena, []);
    await starsArena.deployed();

    console.log('StarsArena deployed to:', starsArena.address);

  await run(`verify:verify`, {
    address: starsArena.address,
    constructorArguments: [],
  });
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
