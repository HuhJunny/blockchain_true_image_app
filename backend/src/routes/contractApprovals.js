import express from "express";
import { getImageById } from "../data/imageStore.js";
import {
  findUserByEmail,
  findUserByGoogleId,
  findUserById,
  findUserByWalletAddress,
} from "../data/userStore.js";
import { verifyToken } from "../middlewares/authMiddleware.js";
import { signContractApproval } from "../services/contractApprovalService.js";

const router = express.Router();

const getCurrentUser = (req) =>
  (req.user?.id ? findUserById(req.user.id) : null) ??
  (req.user?.walletAddress
    ? findUserByWalletAddress(req.user.walletAddress)
    : null) ??
  (req.user?.googleId ? findUserByGoogleId(req.user.googleId) : null) ??
  (req.user?.email ? findUserByEmail(req.user.email) : null);

const parseImageId = (raw) => {
  const value = Number.parseInt(String(raw ?? ""), 10);
  return Number.isInteger(value) && value > 0 ? value : null;
};

const normalizePositivePrice = (raw) => {
  try {
    const value = BigInt(String(raw ?? "").trim());
    return value > 0n ? value.toString() : null;
  } catch {
    return null;
  }
};

const walletAddressForRequest = (req, currentUser) =>
  String(currentUser?.walletAddress ?? req.user?.walletAddress ?? "").trim();

const sameHash = (a, b) =>
  String(a ?? "").trim().toLowerCase() ===
  String(b ?? "").trim().toLowerCase();

router.post("/register", verifyToken, async (req, res) => {
  try {
    const currentUser = getCurrentUser(req);
    const walletAddress = walletAddressForRequest(req, currentUser);
    const pHash = String(req.body?.pHash ?? "").trim();
    const price = normalizePositivePrice(req.body?.price);

    if (!walletAddress) {
      return res.status(401).json({ message: "Wallet address is required." });
    }
    if (!pHash || !price) {
      return res.status(400).json({ message: "pHash and price are required." });
    }

    const approval = await signContractApproval({
      action: "REGISTER_IMAGE",
      actor: walletAddress,
      pHash,
      price,
    });
    return res.status(200).json(approval);
  } catch (error) {
    console.error("[POST /contract-approvals/register]", error);
    return res.status(500).json({ message: "Failed to sign register approval." });
  }
});

router.post("/update-price", verifyToken, async (req, res) => {
  try {
    const currentUser = getCurrentUser(req);
    const walletAddress = walletAddressForRequest(req, currentUser);
    const imageId = parseImageId(req.body?.imageId);
    const price = normalizePositivePrice(req.body?.price);

    if (!currentUser || !walletAddress) {
      return res.status(401).json({ message: "Wallet login is required." });
    }
    if (!imageId || !price) {
      return res.status(400).json({ message: "imageId and price are required." });
    }

    const image = getImageById(imageId);
    if (!image) {
      return res.status(404).json({ message: "Image not found." });
    }
    if (image.userId !== currentUser.id) {
      return res.status(403).json({ message: "Only the image owner can update price." });
    }
    if (req.body?.pHash && !sameHash(req.body.pHash, image.imageHash)) {
      return res.status(400).json({ message: "pHash does not match the image." });
    }

    const approval = await signContractApproval({
      action: "UPDATE_PRICE",
      actor: walletAddress,
      pHash: image.imageHash,
      price,
    });
    return res.status(200).json(approval);
  } catch (error) {
    console.error("[POST /contract-approvals/update-price]", error);
    return res.status(500).json({ message: "Failed to sign update approval." });
  }
});

router.post("/purchase", verifyToken, async (req, res) => {
  try {
    const currentUser = getCurrentUser(req);
    const walletAddress = walletAddressForRequest(req, currentUser);
    const imageId = parseImageId(req.body?.imageId);
    const requestedPrice = req.body?.price
      ? normalizePositivePrice(req.body.price)
      : null;

    if (!currentUser || !walletAddress) {
      return res.status(401).json({ message: "Wallet login is required." });
    }
    if (!imageId) {
      return res.status(400).json({ message: "imageId is required." });
    }

    const image = getImageById(imageId);
    if (!image) {
      return res.status(404).json({ message: "Image not found." });
    }
    if (image.userId === currentUser.id) {
      return res.status(400).json({ message: "Owner cannot purchase own image." });
    }
    if (req.body?.pHash && !sameHash(req.body.pHash, image.imageHash)) {
      return res.status(400).json({ message: "pHash does not match the image." });
    }
    if (requestedPrice && requestedPrice !== BigInt(image.price).toString()) {
      return res.status(409).json({ message: "Requested price is stale." });
    }

    const approval = await signContractApproval({
      action: "PURCHASE_IMAGE",
      actor: walletAddress,
      pHash: image.imageHash,
      price: image.price,
    });
    return res.status(200).json(approval);
  } catch (error) {
    console.error("[POST /contract-approvals/purchase]", error);
    return res.status(500).json({ message: "Failed to sign purchase approval." });
  }
});

export default router;
