import express from "express";
import { verifyToken } from "../middlewares/authMiddleware.js";
import { getImageById } from "../data/imageStore.js";
import {
  createPendingPurchase,
  findPendingByTxHash,
} from "../data/pendingPurchaseStore.js";
import {
  findFirstOrderIdForBuyerAndImage,
  findOrderByTxHash,
} from "../data/orderStore.js";
import {
  buildOrderStatusResponse,
  tryCompletePendingImmediately,
} from "../services/purchaseCompletionService.js";

const router = express.Router();

const isValidEthereumTxHash = (raw) =>
  /^0x[a-fA-F0-9]{64}$/.test(String(raw ?? "").trim());

const normalizeTxHash = (raw) => String(raw ?? "").trim().toLowerCase();

router.post("/", verifyToken, async (req, res) => {
  try {
    const buyerUserId = req.user?.id;
    if (!buyerUserId || !Number.isInteger(Number(buyerUserId))) {
      return res.status(401).json({ message: "인증이 필요합니다." });
    }

    const body = req.body ?? {};
    const imageIdRaw = body.imageId;
    const paymentMethod = typeof body.paymentMethod === "string" ? body.paymentMethod.trim() : "";
    const txHash = typeof body.txHash === "string" ? body.txHash.trim() : "";
    const buyerWalletAddress = req.user?.walletAddress;

    const imageId =
      typeof imageIdRaw === "number" && Number.isInteger(imageIdRaw)
        ? imageIdRaw
        : typeof imageIdRaw === "string" && imageIdRaw.trim() !== ""
          ? Number.parseInt(imageIdRaw.trim(), 10)
          : NaN;

    if (!Number.isInteger(imageId) || imageId < 1) {
      return res.status(400).json({ message: "imageId는 필수입니다." });
    }
    if (!paymentMethod) {
      return res.status(400).json({ message: "paymentMethod는 필수입니다." });
    }
    if (!isValidEthereumTxHash(txHash)) {
      return res.status(400).json({ message: "유효한 txHash(0x + 64 hex)가 필요합니다." });
    }
    if (!buyerWalletAddress || typeof buyerWalletAddress !== "string") {
      return res.status(401).json({ message: "구매자 지갑 주소가 필요합니다." });
    }

    const normalizedTx = normalizeTxHash(txHash);
    const existingOrder = findOrderByTxHash(normalizedTx);
    if (existingOrder) {
      return res.status(200).json({
        status: "COMPLETED",
        orderId: existingOrder.orderId,
        imageId: existingOrder.imageId,
        price: existingOrder.price,
        orderStatus: existingOrder.orderStatus,
        purchasedAt: existingOrder.purchasedAt,
        txHash: existingOrder.txHash,
        message: "이미 처리된 구매입니다.",
      });
    }

    const existingPending = findPendingByTxHash(normalizedTx);
    if (existingPending) {
      if (existingPending.buyerUserId !== Number(buyerUserId)) {
        return res.status(409).json({ message: "이미 사용된 트랜잭션 해시입니다." });
      }
      const statusBody = buildOrderStatusResponse(existingPending);
      const statusCode = existingPending.status === "COMPLETED" ? 200 : 202;
      return res.status(statusCode).json(statusBody);
    }

    const image = getImageById(imageId);
    if (!image) {
      return res.status(404).json({ message: "해당 이미지를 찾을 수 없습니다." });
    }
    if (image.userId === Number(buyerUserId)) {
      return res.status(400).json({ message: "본인이 등록한 이미지는 구매할 수 없습니다." });
    }

    const existingPurchase = findFirstOrderIdForBuyerAndImage(Number(buyerUserId), imageId);
    if (existingPurchase) {
      return res.status(409).json({ message: "이미 구매한 이미지입니다." });
    }

    const pending = createPendingPurchase({
      buyerUserId: Number(buyerUserId),
      buyerWalletAddress,
      imageId,
      paymentMethod,
      txHash: normalizedTx,
    });

    tryCompletePendingImmediately(pending.pendingId);

    const latest = findPendingByTxHash(normalizedTx) ?? pending;
    const statusBody = buildOrderStatusResponse(latest);
    if (latest.status === "COMPLETED") {
      return res.status(201).json(statusBody);
    }
    if (latest.status === "FAILED") {
      return res.status(400).json({
        ...statusBody,
        message: statusBody.message ?? "구매 처리에 실패했습니다.",
      });
    }

    return res.status(202).json(statusBody);
  } catch (error) {
    console.error("[POST /orders]", error);
    return res.status(500).json({ message: "서버 오류 또는 결제 처리에 실패했습니다." });
  }
});

router.get("/status", verifyToken, (req, res) => {
  try {
    const buyerUserId = req.user?.id;
    if (!buyerUserId || !Number.isInteger(Number(buyerUserId))) {
      return res.status(401).json({ message: "인증이 필요합니다." });
    }

    const txHash = typeof req.query.txHash === "string" ? req.query.txHash.trim() : "";
    if (!isValidEthereumTxHash(txHash)) {
      return res.status(400).json({ message: "유효한 txHash query가 필요합니다." });
    }

    const pending = findPendingByTxHash(normalizeTxHash(txHash));
    if (!pending) {
      const order = findOrderByTxHash(normalizeTxHash(txHash));
      if (!order || order.buyerUserId !== Number(buyerUserId)) {
        return res.status(404).json({ message: "구매 요청을 찾을 수 없습니다." });
      }
      return res.status(200).json({
        status: "COMPLETED",
        orderId: order.orderId,
        imageId: order.imageId,
        price: order.price,
        orderStatus: order.orderStatus,
        purchasedAt: order.purchasedAt,
        txHash: order.txHash,
        message: "구매가 완료되었습니다.",
      });
    }

    if (pending.buyerUserId !== Number(buyerUserId)) {
      return res.status(403).json({ message: "해당 구매 요청에 접근할 수 없습니다." });
    }

    return res.status(200).json(buildOrderStatusResponse(pending));
  } catch (error) {
    console.error("[GET /orders/status]", error);
    return res.status(500).json({ message: "서버 내부 오류가 발생했습니다." });
  }
});

export default router;
