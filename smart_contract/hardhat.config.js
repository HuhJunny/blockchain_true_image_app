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
  solidity: {
    version: "0.8.24",
    settings: {
      evmVersion: "cancun",
    },
  },
  networks,
  etherscan: {
    enabled: Boolean(process.env.ETHERSCAN_API_KEY),
    apiKey: process.env.ETHERSCAN_API_KEY ?? "",
  },
  sourcify: {
    enabled: true,
  },
};
