require("dotenv").config();

const API_URL = process.env.API_URL;
const PUBLIC_KEY = process.env.PUBLIC_KEY;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
// const {createAlchemyWeb3} = require("@alch/alchemy-web3");
// const web3 = createAlchemyWeb3(API_URL);

// const nWeb3 = require('web3');


const HDWalletProvider = require('@truffle/hdwallet-provider');
let provider = new HDWalletProvider(PRIVATE_KEY, 'https://data-seed-prebsc-1-s1.binance.org:8545');
const Web3 = require('web3');
let web3 = new Web3(provider);

const contract = require("../artifacts/contracts/MetaNFT.sol/MetaNFT.json");

const contractAddress = "0x6a3443193D0171a12595525510B3068a635625c3";

const nftContract = new web3.eth.Contract(contract.abi, contractAddress);


async function mintNFT(tokenURI) {
    const nonce = await web3.eth.getTransactionCount(PUBLIC_KEY, "latest") //get latest nonce
  
    //the transaction
    const tx = {
      from: PUBLIC_KEY,
      to: contractAddress,
      nonce: nonce,
      gas: 500000,
      data: nftContract.methods.mint(PUBLIC_KEY, tokenURI).encodeABI(),
    }
  
    const signPromise = web3.eth.accounts.signTransaction(tx, PRIVATE_KEY)
    signPromise
      .then((signedTx) => {
        web3.eth.sendSignedTransaction(
          signedTx.rawTransaction,
          function (err, hash) {
            if (!err) {
              console.log(
                "The hash of your transaction is: ",
                hash,
                "\nCheck Alchemy's Mempool to view the status of your transaction!"
              )
            } else {
              console.log(
                "Something went wrong when submitting your transaction:",
                err
              )
            }
          }
        )
      })
      .catch((err) => {
        console.log(" Promise failed:", err)
      })
  }

  mintNFT("https://gateway.pinata.cloud/ipfs/Qme6xy2khE6Xyjd7JXeyUe6r61gepS9gNiREdNS8Uu8nvx");