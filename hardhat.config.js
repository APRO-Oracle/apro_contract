require("@nomicfoundation/hardhat-toolbox");
require('dotenv').config()

const MAIN_NETWORK_RPC = `https://eth-mainnet.alchemyapi.io/v2/e2cTYLgIc1f2NCqbm0Jm8FaXejUp8z64`
const SEPOLIA_NETWORK_RPC = `https://sepolia.infura.io/v3/897c53137e02440c9214606d6ecd6a56`
const BITLAYER_NETWORK_RPC = `https://rpc.bitlayer.org`
const BITLAYER_TEST_NETWORK_RPC = `https://testnet-rpc.bitlayer.org`
const MERLIN_NETWORK_RPC = `https://rpc.merlinchain.io`
const MERLIN_TEST_NETWORK_RPC = `https://testnet-rpc.merlinchain.io`

const COMMON_DEPLOYER_PRIVATE_KEY = process.env.COMMON_DEPLOYER_PRIVATE_KEY;
const MAINNET_DEPLOYER_PRIVATE_KEY = process.env.MAINNET_DEPLOYER_PRIVATE_KEY;
const SEPOLIA_DEPLOYER_PRIVATE_KEY = process.env.SEPOLIA_DEPLOYER_PRIVATE_KEY;
const BITLAYER_DEPLOYER_PRIVATE_KEY = process.env.BITLAYER_DEPLOYER_PRIVATE_KEY;

// etherscan api keys
const ETHERSCAN_ETHEREUM_API_KEY = process.env.ETHERSCAN_ETHEREUM_API_KEY;
// custom chains
const ETHERSCAN_BITLAYER_API_KEY = process.env.ETHERSCAN_BITLAYER_API_KEY;
const ETHERSCAN_MERLIN_API_KEY = process.env.ETHERSCAN_MERLIN_API_KEY;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [    //可指定多个sol版本
      {version: "0.8.20",
      settings: {
        optimizer: {enabled: true, runs: 200},
        evmVersion: 'istanbul',
      }},
      {version: "0.6.6",
      settings: {
        optimizer: {enabled: true, runs: 200},
        evmVersion: 'istanbul',
      }},
      {version: "0.7.6",
      settings: {
        optimizer: {enabled: true, runs: 200},
        evmVersion: 'istanbul',
      }},
    ],
  },

  settings: {
    optimizer: {
      enabled: true,
      runs: 1000000
    }
  },
  networks: {
    mainnet: {
      url: `${MAIN_NETWORK_RPC}`,
      accounts: [`0x${MAINNET_DEPLOYER_PRIVATE_KEY}`],
    },
    sepolia: {
      url: `${SEPOLIA_NETWORK_RPC}`,
      chainId:  11155111,
      accounts: [`0x${SEPOLIA_DEPLOYER_PRIVATE_KEY}`]
    },
    bitlayer: {
      url: `${BITLAYER_NETWORK_RPC}`,
      chainId:  200901,
      gasPrice: 110000000,
      accounts: [`0x${BITLAYER_DEPLOYER_PRIVATE_KEY}`]
    },
    bitlayerTest: {
      url: `${BITLAYER_TEST_NETWORK_RPC}`,
      chainId:  200810,
      gasPrice: 110000000,
      accounts: [`0x${BITLAYER_DEPLOYER_PRIVATE_KEY}`]
    },
    merlin: {
      url: `${MERLIN_NETWORK_RPC}`,
      chainId:  4200,
      accounts: [`0x${COMMON_DEPLOYER_PRIVATE_KEY}`]
    },
    merlinTest: {
      url: `${MERLIN_TEST_NETWORK_RPC}`,
      chainId:  686868,
      accounts: [`0x${COMMON_DEPLOYER_PRIVATE_KEY}`]
    }
  },
  etherscan: {
    apiKey:{
      mainnet: `${ETHERSCAN_ETHEREUM_API_KEY}`,
      sepolia: `${ETHERSCAN_ETHEREUM_API_KEY}`,
      bitlayer:`${ETHERSCAN_BITLAYER_API_KEY}`,
      bitlayerTest:`${ETHERSCAN_BITLAYER_API_KEY}`,
      merlin:`${ETHERSCAN_MERLIN_API_KEY}`,
      merlinTest:`${ETHERSCAN_MERLIN_API_KEY}`,

    },
    customChains: [
      {
        network: "bitlayer",
        chainId: 200901,
        urls:{
          apiURL: "https://www.btrscan.com/apis",
          browserURL: "https://www.btrscan.com/"
        }
      },
      {
        network: "bitlayerTest",
        chainId: 200810,
        urls:{
          apiURL: "https://api-testnet.btrscan.com/scan/api",
          browserURL: "https://testnet-scan.bitlayer.org/"
        }
      },
      {
        network: "merlin",
        chainId: 4200,
        urls:{
          apiURL: "",
          browserURL: "https://scan.merlinchain.io"
        }
      },
      {
        network: "merlinTest",
        chainId: 686868,
        urls:{
          apiURL: "",
          browserURL: "https://testnet-scan.merlinchain.io"
        }
      },
    ],
  },

  sourcify: {
    enabled: true
  }
};

// set proxy
// const proxyUrl = 'http://127.0.0.1:7890';   // change to yours, With the global proxy enabled, change the proxyUrl to your own proxy link. The port may be different for each client.
// const { ProxyAgent, setGlobalDispatcher } = require("undici");
// const proxyAgent = new ProxyAgent(proxyUrl);
// setGlobalDispatcher(proxyAgent);


