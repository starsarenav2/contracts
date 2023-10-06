const {ethers, upgrades, network} = require('hardhat');

async function main() {
    let existingAddress;

    if (network.name === 'fuji') {
        existingAddress = '';
    } else if (network.name === 'mainnet') {
        existingAddress = '0xA481B139a1A654cA19d2074F174f17D7534e8CeC';
    }

    const [deployer] = await ethers.getSigners();
    const deployerAddress = await deployer.getAddress();
    console.log('Deploying StarShares with address:', deployerAddress, network.name);

    const StarsArena = await ethers.getContractFactory('StarsArena');
    const starsArena = await upgrades.upgradeProxy(existingAddress, StarsArena);

    console.log('StarShares upgraded to:', starsArena.address);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
