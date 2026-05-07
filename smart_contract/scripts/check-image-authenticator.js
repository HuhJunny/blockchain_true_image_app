import hre from "hardhat";

const { ethers } = hre;

async function main() {
  const [owner, buyer] = await ethers.getSigners();
  const ImageAuthenticator = await ethers.getContractFactory(
    "ImageAuthenticator",
  );
  const imageAuthenticator = await ImageAuthenticator.deploy();

  await imageAuthenticator.waitForDeployment();

  const pHash = "demo-hash-001";
  const initialPrice = ethers.parseEther("0.01");
  const updatedPrice = ethers.parseEther("0.02");

  console.log("Contract deployed:", await imageAuthenticator.getAddress());
  console.log("Owner signer:", owner.address);
  console.log("Buyer signer:", buyer.address);

  console.log("\n[1] Register image");
  await (
    await imageAuthenticator.registerImage(pHash, initialPrice)
  ).wait();
  console.log("Registered pHash:", pHash);

  console.log("\n[2] Read owner and price");
  console.log("getOwner:", await imageAuthenticator.getOwner(pHash));
  console.log(
    "getPrice:",
    ethers.formatEther(await imageAuthenticator.getPrice(pHash)),
    "ETH",
  );

  console.log("\n[3] Update price");
  await (await imageAuthenticator.updatePrice(pHash, updatedPrice)).wait();
  console.log(
    "Updated getPrice:",
    ethers.formatEther(await imageAuthenticator.getPrice(pHash)),
    "ETH",
  );

  console.log("\n[4] Purchase image");
  const ownerBalanceBefore = await ethers.provider.getBalance(owner.address);
  await (
    await imageAuthenticator.connect(buyer).purchaseImage(pHash, {
      value: updatedPrice,
    })
  ).wait();
  const ownerBalanceAfter = await ethers.provider.getBalance(owner.address);

  console.log(
    "Owner balance delta:",
    ethers.formatEther(ownerBalanceAfter - ownerBalanceBefore),
    "ETH",
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
