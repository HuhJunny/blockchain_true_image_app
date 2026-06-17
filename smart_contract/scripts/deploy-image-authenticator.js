import hre from "hardhat";
import { Wallet } from "ethers";

const { ethers } = hre;

const backendPrivateKey =
  process.env.BACKEND_SIGNER_PRIVATE_KEY ??
  process.env.BLOCKCHAIN_PRIVATE_KEY ??
  process.env.PRIVATE_KEY;

const backendSignerAddress =
  process.env.BACKEND_SIGNER_ADDRESS ??
  (backendPrivateKey ? new Wallet(backendPrivateKey).address : null);

if (!backendSignerAddress) {
  throw new Error(
    "BACKEND_SIGNER_ADDRESS or BACKEND_SIGNER_PRIVATE_KEY is required.",
  );
}

const ImageAuthenticator = await ethers.getContractFactory(
  "ImageAuthenticator",
);
const imageAuthenticator = await ImageAuthenticator.deploy(backendSignerAddress);
await imageAuthenticator.waitForDeployment();

const address = await imageAuthenticator.getAddress();
const deploymentTx = imageAuthenticator.deploymentTransaction();

console.log("ImageAuthenticator deployed");
console.log(`contractAddress=${address}`);
console.log(`backendSigner=${backendSignerAddress}`);
console.log(`deploymentTx=${deploymentTx?.hash ?? ""}`);
