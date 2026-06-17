import { loadFixture, time } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs.js";
import { expect } from "chai";
import hre from "hardhat";

const { ethers } = hre;

const ACTIONS = {
  REGISTER: ethers.id("REGISTER_IMAGE"),
  UPDATE_PRICE: ethers.id("UPDATE_PRICE"),
  PURCHASE: ethers.id("PURCHASE_IMAGE"),
};

describe("ImageAuthenticator", function () {
  async function deployImageAuthenticatorFixture() {
    const [owner, buyer, otherAccount, backendSigner, wrongSigner] =
      await ethers.getSigners();
    const ImageAuthenticator = await ethers.getContractFactory(
      "ImageAuthenticator",
    );
    const imageAuthenticator = await ImageAuthenticator.deploy(
      backendSigner.address,
    );
    await imageAuthenticator.waitForDeployment();

    let nextNonce = 1n;
    const signApproval = async ({
      action,
      actor = owner,
      pHash,
      price,
      signer = backendSigner,
      nonce = nextNonce++,
      deadline,
    }) => {
      const effectiveDeadline =
        deadline ?? BigInt((await time.latest()) + 60 * 60);
      const actorAddress =
        typeof actor === "string" ? actor : await actor.getAddress();
      const approvalHash = await imageAuthenticator.getApprovalHash(
        action,
        actorAddress,
        pHash,
        price,
        nonce,
        effectiveDeadline,
      );
      const signature = await signer.signMessage(ethers.getBytes(approvalHash));

      return {
        nonce,
        deadline: effectiveDeadline,
        signature,
        approvalHash,
      };
    };

    const register = async ({
      actor = owner,
      pHash,
      price,
      signer = backendSigner,
    }) => {
      const approval = await signApproval({
        action: ACTIONS.REGISTER,
        actor,
        pHash,
        price,
        signer,
      });
      return {
        approval,
        tx: imageAuthenticator
          .connect(actor)
          .registerImage(
            pHash,
            price,
            approval.nonce,
            approval.deadline,
            approval.signature,
          ),
      };
    };

    return {
      imageAuthenticator,
      owner,
      buyer,
      otherAccount,
      backendSigner,
      wrongSigner,
      signApproval,
      register,
    };
  }

  describe("registerImage", function () {
    it("stores the caller as the owner and saves the initial price with backend approval", async function () {
      const { imageAuthenticator, owner, register } = await loadFixture(
        deployImageAuthenticatorFixture,
      );
      const pHash = "ff00aa1122";
      const price = ethers.parseEther("0.01");

      const { tx } = await register({ pHash, price });

      await expect(tx)
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

    it("reverts when the backend approval is not signed by the backend signer", async function () {
      const { imageAuthenticator, register, wrongSigner } = await loadFixture(
        deployImageAuthenticatorFixture,
      );
      const pHash = "wrong-signer-hash";
      const price = ethers.parseEther("0.01");

      const { tx } = await register({ pHash, price, signer: wrongSigner });

      await expect(tx).to.be.revertedWithCustomError(
        imageAuthenticator,
        "InvalidBackendApproval",
      );
    });

    it("reverts when the approval payload is tampered", async function () {
      const { imageAuthenticator, owner, signApproval } = await loadFixture(
        deployImageAuthenticatorFixture,
      );
      const pHash = "reused-approval-hash";
      const price = ethers.parseEther("0.01");
      const approval = await signApproval({
        action: ACTIONS.REGISTER,
        actor: owner,
        pHash,
        price,
      });

      await imageAuthenticator.registerImage(
        pHash,
        price,
        approval.nonce,
        approval.deadline,
        approval.signature,
      );

      await expect(
        imageAuthenticator.registerImage(
          "different-hash",
          price,
          approval.nonce,
          approval.deadline,
          approval.signature,
        ),
      ).to.be.revertedWithCustomError(
        imageAuthenticator,
        "InvalidBackendApproval",
      );
    });

    it("reverts when the pHash is already registered", async function () {
      const { imageAuthenticator, register } = await loadFixture(
        deployImageAuthenticatorFixture,
      );
      const pHash = "duplicate-hash";
      const price = ethers.parseEther("0.01");

      await (await register({ pHash, price })).tx;

      const { tx } = await register({ pHash, price });
      await expect(tx).to.be.revertedWithCustomError(
        imageAuthenticator,
        "ImageAlreadyRegistered",
      );
    });
  });

  describe("updatePrice", function () {
    it("lets the image owner change the price with backend approval", async function () {
      const { imageAuthenticator, owner, register, signApproval } =
        await loadFixture(deployImageAuthenticatorFixture);
      const pHash = "price-change-hash";
      const oldPrice = ethers.parseEther("0.01");
      const newPrice = ethers.parseEther("0.025");

      await (await register({ pHash, price: oldPrice })).tx;

      const approval = await signApproval({
        action: ACTIONS.UPDATE_PRICE,
        actor: owner,
        pHash,
        price: newPrice,
      });

      await expect(
        imageAuthenticator.updatePrice(
          pHash,
          newPrice,
          approval.nonce,
          approval.deadline,
          approval.signature,
        ),
      )
        .to.emit(imageAuthenticator, "ImagePriceUpdated")
        .withArgs(owner.address, pHash, oldPrice, newPrice, anyValue);

      expect(await imageAuthenticator.getPrice(pHash)).to.equal(newPrice);
    });

    it("reverts when a non-owner tries to update the price", async function () {
      const {
        imageAuthenticator,
        otherAccount,
        register,
        signApproval,
      } = await loadFixture(deployImageAuthenticatorFixture);
      const pHash = "owner-only-hash";
      const price = ethers.parseEther("0.01");

      await (await register({ pHash, price })).tx;
      const approval = await signApproval({
        action: ACTIONS.UPDATE_PRICE,
        actor: otherAccount,
        pHash,
        price,
      });

      await expect(
        imageAuthenticator
          .connect(otherAccount)
          .updatePrice(
            pHash,
            price,
            approval.nonce,
            approval.deadline,
            approval.signature,
          ),
      ).to.be.revertedWithCustomError(imageAuthenticator, "NotImageOwner");
    });

    it("reverts when an update approval is reused", async function () {
      const { imageAuthenticator, owner, register, signApproval } =
        await loadFixture(deployImageAuthenticatorFixture);
      const pHash = "reused-update-approval-hash";
      const oldPrice = ethers.parseEther("0.01");
      const newPrice = ethers.parseEther("0.02");

      await (await register({ pHash, price: oldPrice })).tx;
      const approval = await signApproval({
        action: ACTIONS.UPDATE_PRICE,
        actor: owner,
        pHash,
        price: newPrice,
      });

      await imageAuthenticator.updatePrice(
        pHash,
        newPrice,
        approval.nonce,
        approval.deadline,
        approval.signature,
      );

      await expect(
        imageAuthenticator.updatePrice(
          pHash,
          newPrice,
          approval.nonce,
          approval.deadline,
          approval.signature,
        ),
      ).to.be.revertedWithCustomError(
        imageAuthenticator,
        "BackendApprovalAlreadyUsed",
      );
    });
  });

  describe("purchaseImage", function () {
    it("forwards the payment to the owner and emits buyer/pHash in the event with backend approval", async function () {
      const { imageAuthenticator, owner, buyer, register, signApproval } =
        await loadFixture(deployImageAuthenticatorFixture);
      const pHash = "purchase-hash";
      const price = ethers.parseEther("0.05");

      await (await register({ pHash, price })).tx;

      const approval = await signApproval({
        action: ACTIONS.PURCHASE,
        actor: buyer,
        pHash,
        price,
      });
      const ownerBalanceBefore = await ethers.provider.getBalance(owner.address);

      await expect(
        imageAuthenticator
          .connect(buyer)
          .purchaseImage(
            pHash,
            price,
            approval.nonce,
            approval.deadline,
            approval.signature,
            { value: price },
          ),
      )
        .to.emit(imageAuthenticator, "ImagePurchased")
        .withArgs(buyer.address, owner.address, pHash, price, anyValue);

      const ownerBalanceAfter = await ethers.provider.getBalance(owner.address);
      expect(ownerBalanceAfter - ownerBalanceBefore).to.equal(price);
    });

    it("reverts when the buyer sends the wrong amount", async function () {
      const { imageAuthenticator, buyer, register, signApproval } =
        await loadFixture(deployImageAuthenticatorFixture);
      const pHash = "wrong-payment-hash";
      const price = ethers.parseEther("0.05");
      const wrongPrice = ethers.parseEther("0.03");

      await (await register({ pHash, price })).tx;
      const approval = await signApproval({
        action: ACTIONS.PURCHASE,
        actor: buyer,
        pHash,
        price,
      });

      await expect(
        imageAuthenticator
          .connect(buyer)
          .purchaseImage(
            pHash,
            price,
            approval.nonce,
            approval.deadline,
            approval.signature,
            { value: wrongPrice },
          ),
      )
        .to.be.revertedWithCustomError(imageAuthenticator, "IncorrectPayment")
        .withArgs(price, wrongPrice);
    });

    it("reverts when the owner tries to purchase their own image", async function () {
      const { imageAuthenticator, owner, register, signApproval } =
        await loadFixture(deployImageAuthenticatorFixture);
      const pHash = "self-purchase-hash";
      const price = ethers.parseEther("0.05");

      await (await register({ pHash, price })).tx;
      const approval = await signApproval({
        action: ACTIONS.PURCHASE,
        actor: owner,
        pHash,
        price,
      });

      await expect(
        imageAuthenticator.purchaseImage(
          pHash,
          price,
          approval.nonce,
          approval.deadline,
          approval.signature,
          { value: price },
        ),
      ).to.be.revertedWithCustomError(
        imageAuthenticator,
        "OwnerCannotPurchaseOwnImage",
      );
    });
  });
});
