import "dotenv/config";
import "@nomicfoundation/hardhat-toolbox";

/** @type import('hardhat/config').HardhatUserConfig */
const networks = {};

if (process.env.ALCHEMY_RPC_URL && process.env.PRIVATE_KEY) {
  networks.sepolia = {
    url: process.env.ALCHEMY_RPC_URL,
    accounts: [process.env.PRIVATE_KEY],
  };
}

export default {
  solidity: "0.8.24",
  networks,
};
