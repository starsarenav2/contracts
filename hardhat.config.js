require('dotenv').config();
require('@nomiclabs/hardhat-waffle');
require('@nomiclabs/hardhat-truffle5');
require("@nomiclabs/hardhat-etherscan");
require('hardhat-gas-reporter');
require('solidity-coverage');
require('@nomiclabs/hardhat-solhint');
require('hardhat-contract-sizer');
require('@openzeppelin/hardhat-upgrades');

const PRIVATE_KEY_TESTNET = process.env.PRIVATE_KEY_TESTNET;
const PRIVATE_KEY_MAINNET = process.env.PRIVATE_KEY_MAINNET;

module.exports = {
    solidity: {
        version: "0.8.7",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200,
            },
        },
    },
    gasReporter: {
        currency: 'USD',
        enabled: false,
        gasPrice: 50,
    },
    networks: {
        hardhat: {},
        fuji: { // Avalanche's C-Chain testnet
            url: "https://api.avax-test.network/ext/bc/C/rpc", // Avalanche C-Chain Testnet
            chainId: 43113,
            gasPrice: 225000000000,
            accounts: [`0x${PRIVATE_KEY_TESTNET}`]
        },
        mainnet: { // Avalanche's C-Chain mainnet
            url: "https://api.avax.network/ext/bc/C/rpc", // Avalanche C-Chain Mainnet
            chainId: 43114,
            gasPrice: 2250000000000,
            accounts: [`0x${PRIVATE_KEY_MAINNET}`]
        }
    }
};
