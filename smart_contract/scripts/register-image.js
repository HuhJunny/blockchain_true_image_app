import hre from "hardhat";

const { ethers } = hre;

function getArg(flag) {
  const index = process.argv.indexOf(flag);

  if (index === -1 || index + 1 >= process.argv.length) {
    return undefined;
  }

  return process.argv[index + 1];
}

async function main() {
  const contractAddress =
    getArg("--contract") ||
    process.env.BLOCKCHAIN_CONTRACT_ADDRESS ||
    process.env.IMAGE_AUTHENTICATOR_CONTRACT ||
    process.env.CONTRACT_ADDRESS;
  const pHash = getArg("--phash") || "1234";
  const priceEth = getArg("--price-eth") || "0.001";
  const backendPrivateKey =
    process.env.BACKEND_SIGNER_PRIVATE_KEY ||
    process.env.BLOCKCHAIN_PRIVATE_KEY;

  if (!contractAddress) {
    throw new Error("--contract or BLOCKCHAIN_CONTRACT_ADDRESS is required.");
  }
  if (!backendPrivateKey) {
    throw new Error("BACKEND_SIGNER_PRIVATE_KEY is required.");
  }

  const imageAuthenticator = await ethers.getContractAt(
    "ImageAuthenticator",
    contractAddress,
  );
  const [signer] = await ethers.getSigners();
  const backendSigner = new ethers.Wallet(backendPrivateKey);
  const network = await ethers.provider.getNetwork();
  const price = ethers.parseEther(priceEth);
  const nonce = BigInt(Date.now());
  const deadline = BigInt(Math.floor(Date.now() / 1000) + 5 * 60);
  const action = ethers.id("REGISTER_IMAGE");
  const approvalHash = ethers.keccak256(
    ethers.AbiCoder.defaultAbiCoder().encode(
      [
        "uint256",
        "address",
        "bytes32",
        "address",
        "bytes32",
        "uint256",
        "uint256",
        "uint256",
      ],
      [
        network.chainId,
        contractAddress,
        action,
        signer.address,
        ethers.keccak256(ethers.toUtf8Bytes(pHash)),
        price,
        nonce,
        deadline,
      ],
    ),
  );
  const backendSignature = await backendSigner.signMessage(
    ethers.getBytes(approvalHash),
  );

  console.log("Network:", network.name);
  console.log("Contract:", contractAddress);
  console.log("Signer:", signer.address);
  console.log("Backend signer:", backendSigner.address);
  console.log("pHash:", pHash);
  console.log("Price:", priceEth, "ETH");
  console.log("Approval hash:", approvalHash);

  const alreadyRegistered = await imageAuthenticator.isRegistered(pHash);

  if (alreadyRegistered) {
    const owner = await imageAuthenticator.getOwner(pHash);
    const storedPrice = await imageAuthenticator.getPrice(pHash);

    console.log("Already registered.");
    console.log("Owner:", owner);
    console.log("Stored price:", ethers.formatEther(storedPrice), "ETH");
    return;
  }

  const tx = await imageAuthenticator.registerImage(
    pHash,
    price,
    nonce,
    deadline,
    backendSignature,
  );

  console.log("Submitted tx:", tx.hash);

  const receipt = await tx.wait();
  const owner = await imageAuthenticator.getOwner(pHash);
  const storedPrice = await imageAuthenticator.getPrice(pHash);

  console.log("Confirmed in block:", receipt.blockNumber);
  console.log("Registered owner:", owner);
  console.log("Stored price:", ethers.formatEther(storedPrice), "ETH");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
