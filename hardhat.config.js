require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.17",
  networks: {
    hardhat: {
      accounts: [{
        privateKey: "52fcb38e4ee12d15b7b3c52740a265274d999825cf653f73d86fe2c7fcceaf40",
        balance: "100000000000000000000"
      }, {
        privateKey: "1814b58085b15a3e72b314f62c97712598355a677b5b11eebad27f3a4bc6a10a",
        balance: "100000000000000000000"
      }]
    }
  }
};
