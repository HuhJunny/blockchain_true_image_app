import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs.js";
import { expect } from "chai";
import hre from "hardhat";

const { ethers } = hre;

describe("ImageAuthenticator", function () {
  async function deployImageAuthenticatorFixture() {
    const [owner, buyer, otherAccount] = await ethers.getSigners();
    const ImageAuthenticator = await ethers.getContractFactory(
      "ImageAuthenticator",
    );
    const imageAuthenticator = await ImageAuthenticator.deploy();
    await imageAuthenticator.waitForDeployment();

    return { imageAuthenticator, owner, buyer, otherAccount };
  }

  describe("registerImage", function () {
    it("stores the caller as the owner and saves the initial price", async function () {
      const { imageAuthenticator, owner } = await loadFixture(
        deployImageAuthenticatorFixture,
      );
      const pHash = "ff00aa1122";
      const price = ethers.parseEther("0.01");

      await expect(imageAuthenticator.registerImage(pHash, price))
        .to.emit(imageAuthenticator, "ImageRegistered")
        .withArgs(owner.address, pHash, price, anyValue);

      expect(await imageAuthenticator.getOwner(pHash)).to.equal(owner.address);
      expect(await imageAuthenticator.getPrice(pHash)).to.equal(price);

      const [storedOwner, storedPrice] = await imageAuthenticator.getImage(
        pHash,
      );
      expect(storedOwner).to.equal(owner.address);
      expect(storedPrice).to.equal(price);

      const imageData = await imageAuthenticator.getImageData(pHash);
      expect(imageData.pHash).to.equal(pHash);
    });

    it("reverts when the pHash is already registered", async function () {
      const { imageAuthenticator } = await loadFixture(
        deployImageAuthenticatorFixture,
      );
      const pHash = "duplicate-hash";
      const price = ethers.parseEther("0.01");

      await imageAuthenticator.registerImage(pHash, price);

      await expect(
        imageAuthenticator.registerImage(pHash, price),
      ).to.be.revertedWithCustomError(
        imageAuthenticator,
        "ImageAlreadyRegistered",
      );
    });
  });

  describe("updatePrice", function () {
    it("lets the image owner change the price", async function () {
      const { imageAuthenticator, owner } = await loadFixture(
        deployImageAuthenticatorFixture,
      );
      const pHash = "price-change-hash";
      const oldPrice = ethers.parseEther("0.01");
      const newPrice = ethers.parseEther("0.025");

      await imageAuthenticator.registerImage(pHash, oldPrice);

      await expect(imageAuthenticator.updatePrice(pHash, newPrice))
        .to.emit(imageAuthenticator, "ImagePriceUpdated")
        .withArgs(owner.address, pHash, oldPrice, newPrice, anyValue);

      expect(await imageAuthenticator.getPrice(pHash)).to.equal(newPrice);
    });

    it("reverts when a non-owner tries to update the price", async function () {
      const { imageAuthenticator, otherAccount } = await loadFixture(
        deployImageAuthenticatorFixture,
      );
      const pHash = "owner-only-hash";
      const price = ethers.parseEther("0.01");

      await imageAuthenticator.registerImage(pHash, price);

      await expect(
        imageAuthenticator.connect(otherAccount).updatePrice(pHash, price),
      ).to.be.revertedWithCustomError(imageAuthenticator, "NotImageOwner");
    });
  });

  describe("purchaseImage", function () {
    it("forwards the payment to the owner and emits buyer/pHash in the event", async function () {
      const { imageAuthenticator, owner, buyer } = await loadFixture(
        deployImageAuthenticatorFixture,
      );
      const pHash = "purchase-hash";
      const price = ethers.parseEther("0.05");

      await imageAuthenticator.registerImage(pHash, price);

      const ownerBalanceBefore = await ethers.provider.getBalance(owner.address);

      await expect(
        imageAuthenticator.connect(buyer).purchaseImage(pHash, { value: price }),
      )
        .to.emit(imageAuthenticator, "ImagePurchased")
        .withArgs(buyer.address, owner.address, pHash, price, anyValue);

      const ownerBalanceAfter = await ethers.provider.getBalance(owner.address);
      expect(ownerBalanceAfter - ownerBalanceBefore).to.equal(price);
    });

    it("reverts when the buyer sends the wrong amount", async function () {
      const { imageAuthenticator, buyer } = await loadFixture(
        deployImageAuthenticatorFixture,
      );
      const pHash = "wrong-payment-hash";
      const price = ethers.parseEther("0.05");
      const wrongPrice = ethers.parseEther("0.03");

      await imageAuthenticator.registerImage(pHash, price);

      await expect(
        imageAuthenticator
          .connect(buyer)
          .purchaseImage(pHash, { value: wrongPrice }),
      )
        .to.be.revertedWithCustomError(imageAuthenticator, "IncorrectPayment")
        .withArgs(price, wrongPrice);
    });

    it("reverts when the owner tries to purchase their own image", async function () {
      const { imageAuthenticator } = await loadFixture(
        deployImageAuthenticatorFixture,
      );
      const pHash = "self-purchase-hash";
      const price = ethers.parseEther("0.05");

      await imageAuthenticator.registerImage(pHash, price);

      await expect(
        imageAuthenticator.purchaseImage(pHash, { value: price }),
      ).to.be.revertedWithCustomError(
        imageAuthenticator,
        "OwnerCannotPurchaseOwnImage",
      );
    });
  });
});
