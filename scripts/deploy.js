async function main() {
    const MyNFT = await ethers.getContractFactory("MetaNFT")
  
    // Start deployment, returning a promise that resolves to a contract object
    const myNFT = await MyNFT.deploy()
    await myNFT.deployed()
    console.log("Contract deployed to address:", myNFT.address)
  }
  
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error)
      process.exit(1)
    })

    // token address 0x6a3443193D0171a12595525510B3068a635625c3