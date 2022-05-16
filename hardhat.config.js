/**
* @type import('hardhat/config').HardhatUserConfig
*/
require('dotenv').config();
require("@nomiclabs/hardhat-ethers");
const { API_URL, PRIVATE_KEY } = process.env;
module.exports = {
   solidity: "0.8.12",
   defaultNetwork: "ropsten",
   settings: {
      optimizer: {
        enabled: true,
        runs: 1,
      },
    },
   networks: {
      hardhat: {},
      ropsten: {
         url: API_URL,
         accounts: [`0x${PRIVATE_KEY}`]
      },
      bsc_testnet: {
         url: "https://data-seed-prebsc-1-s1.binance.org:8545",
         chainId: 97,
         accounts:
           process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
       },
   },
}