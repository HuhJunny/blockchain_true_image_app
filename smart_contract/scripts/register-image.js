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
    getArg("--contract") || "0x6154ab54f64106e00C715EBfC7cE6ce8C5dfF9CB";
  const pHash = getArg("--phash") || "1234";
  const priceEth = getArg("--price-eth") || "0.001";

  const imageAuthenticator = await ethers.getContractAt(
    "ImageAuthenticator",
    contractAddress,
  );
  const [signer] = await ethers.getSigners();

  console.log("Network:", (await ethers.provider.getNetwork()).name);
  console.log("Contract:", contractAddress);
  console.log("Signer:", signer.address);
  console.log("pHash:", pHash);
  console.log("Price:", priceEth, "ETH");

  const alreadyRegistered = await imageAuthenticator.isRegistered(pHash);

  if (alreadyRegistered) {
    const owner = await imageAuthenticator.getOwner(pHash);
    const price = await imageAuthenticator.getPrice(pHash);

    console.log("Already registered.");
    console.log("Owner:", owner);
    console.log("Stored price:", ethers.formatEther(price), "ETH");
    return;
  }

  const tx = await imageAuthenticator.registerImage(
    pHash,
    ethers.parseEther(priceEth),
  );

  console.log("Submitted tx:", tx.hash);

  const receipt = await tx.wait();
  const owner = await imageAuthenticator.getOwner(pHash);
  const price = await imageAuthenticator.getPrice(pHash);

  console.log("Confirmed in block:", receipt.blockNumber);
  console.log("Registered owner:", owner);
  console.log("Stored price:", ethers.formatEther(price), "ETH");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
