require('@nomiclabs/hardhat-waffle');
require('@nomiclabs/hardhat-truffle5');
require("@nomiclabs/hardhat-etherscan");
require('hardhat-gas-reporter');
require('solidity-coverage');
require('@nomiclabs/hardhat-solhint');
require('hardhat-contract-sizer');
require('@openzeppelin/hardhat-upgrades');

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
    defaultNetwork: "hardhat",
    networks: {
        hardhat: {},
        avalanche: {
            url: "https://api.avax.network/ext/bc/C/rpc",
            accounts: process.env.DEPLOY_PRIVATE_KEY
              ? [process.env.DEPLOY_PRIVATE_KEY]
              : [],
            chainId: 43114,
            live: true,
            saveDeployments: true,
        },
        fuji: {
            url: "https://api.avax-test.network/ext/bc/C/rpc",
            accounts: process.env.DEPLOY_PRIVATE_KEY
              ? [process.env.DEPLOY_PRIVATE_KEY]
              : [],
            chainId: 43113,
            saveDeployments: true,
        },
    },
    namedAccounts: {
        deployer: 0,
        dev: 1,
    },
    etherscan: {
        apiKey: {
            // See https://hardhat.org/plugins/nomiclabs-hardhat-etherscan.html#multiple-api-keys-and-alternative-block-explorers
            avalanche: process.env.SNOWTRACE_API_KEY,
            avalancheFujiTestnet: process.env.SNOWTRACE_API_KEY,
        },
    },
    gasReporter: {
        enabled: true,
    }
};
