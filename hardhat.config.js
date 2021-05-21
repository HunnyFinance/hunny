/**
 * @type import('hardhat/config').HardhatUserConfig
 */

require('dotenv').config();

require("@nomiclabs/hardhat-waffle");

module.exports = {
  solidity: "0.6.12",
  networks: {
    testnet: {
      url: `${process.env.RPC}`,
      accounts: [`0x${process.env.DEPLOYER}`]
    }
  }
};
