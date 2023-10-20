const {ethers, upgrades, run} = require('hardhat');

async function main() {
  const proxyAddress = '0x563395A2a04a7aE0421d34d62ae67623cAF67D03';
  const gas = await ethers.provider.getGasPrice();
  const StarsArena = await ethers.getContractFactory('StarsArena');
  console.log("Upgrading StarsArena...");
  const starsArena = await upgrades.upgradeProxy(proxyAddress, StarsArena, {
    gasPrice: gas,
  });
  console.log('StarShares upgraded to:', starsArena.address);
  await run(`verify:verify`, {
    address: starsArena.address,
    constructorArguments: [],
  });
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
