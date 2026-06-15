import { getImageById } from "../data/imageStore.js";
import { findPurchaseEventByTxHash } from "../data/purchaseEventStore.js";
import { createPaidOrder, findOrderByTxHash } from "../data/orderStore.js";
import {
  findPendingById,
  findPendingByTxHash,
  markPendingCompleted,
  markPendingFailed,
} from "../data/pendingPurchaseStore.js";
import {
  getProvider,
  getReadOnlyContract,
  parseImagePurchasedFromReceipt,
} from "./blockchainService.js";
import { upsertPurchaseEvent } from "../data/purchaseEventStore.js";

const normalizeTxHash = (raw) => String(raw ?? "").trim().toLowerCase();
const normalizeAddress = (raw) => String(raw ?? "").trim().toLowerCase();

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

export const RECEIPT_FALLBACK_AGE_MS = Number(process.env.PENDING_RECEIPT_FALLBACK_MS ?? 30_000);
export const RECEIPT_POLL_INTERVAL_MS = Number(process.env.RECEIPT_POLL_INTERVAL_MS ?? 2_000);
export const RECEIPT_POLL_MAX_MS = Number(process.env.RECEIPT_POLL_MAX_MS ?? 60_000);

const eventMatchesPending = (pending, event, image) => {
  if (!pending || !event || !image) return false;
  return (
    normalizeAddress(event.buyerAddress) === normalizeAddress(pending.buyerWalletAddress) &&
    String(event.imageHash ?? "")
      .trim()
      .toLowerCase() ===
      String(image.imageHash ?? "")
        .trim()
        .toLowerCase() &&
    Number(event.amount) === Number(image.price) &&
    Number(pending.imageId) === Number(image.id)
  );
};

const parsedMatchesPending = (pending, parsed, image) => {
  if (!pending || !parsed || !image) return false;
  return (
    normalizeAddress(parsed.buyer) === normalizeAddress(pending.buyerWalletAddress) &&
    String(parsed.pHash ?? "")
      .trim()
      .toLowerCase() ===
      String(image.imageHash ?? "")
        .trim()
        .toLowerCase() &&
    Number(parsed.amount) === Number(image.price) &&
    Number(pending.imageId) === Number(image.id)
  );
};

const finalizePendingOrder = (pending) => {
  const orderResult = createPaidOrder({
    buyerUserId: pending.buyerUserId,
    imageId: pending.imageId,
    paymentMethod: pending.paymentMethod,
    txHash: pending.txHash,
  });

  if (orderResult.ok) {
    return markPendingCompleted(pending.pendingId, orderResult.orderId);
  }

  if (orderResult.error === "ALREADY_PURCHASED" || orderResult.error === "DUPLICATE_TX") {
    const existing = findOrderByTxHash(pending.txHash);
    if (existing) {
      return markPendingCompleted(pending.pendingId, existing.orderId);
    }
  }

  const messages = {
    NOT_FOUND: "해당 이미지를 찾을 수 없습니다.",
    SELF: "본인이 등록한 이미지는 구매할 수 없습니다.",
    ALREADY_PURCHASED: "이미 구매한 이미지입니다.",
    DUPLICATE_TX: "이미 사용된 트랜잭션 해시입니다.",
    INVALID_TX: "txHash가 필요합니다.",
  };

  return markPendingFailed(
    pending.pendingId,
    orderResult.error ?? "ORDER_FAILED",
    messages[orderResult.error] ?? "주문 생성에 실패했습니다."
  );
};

/**
 * 구독 DB 이벤트와 pending 요청을 대조해 주문 완료.
 */
export function tryCompletePendingFromSubscription(txHash) {
  const pending = findPendingByTxHash(txHash);
  if (!pending || pending.status !== "PENDING") {
    return { ok: false, reason: "NO_PENDING" };
  }

  const image = getImageById(pending.imageId);
  if (!image) {
    markPendingFailed(pending.pendingId, "NOT_FOUND", "해당 이미지를 찾을 수 없습니다.");
    return { ok: false, reason: "NOT_FOUND" };
  }

  const event = findPurchaseEventByTxHash(pending.txHash);
  if (!event) {
    return { ok: false, reason: "NO_EVENT" };
  }

  if (!eventMatchesPending(pending, event, image)) {
    markPendingFailed(
      pending.pendingId,
      "SUBSCRIPTION_MISMATCH",
      "구독 이벤트와 구매 요청 정보가 일치하지 않습니다."
    );
    return { ok: false, reason: "SUBSCRIPTION_MISMATCH" };
  }

  const completed = finalizePendingOrder(pending);
  return { ok: completed?.status === "COMPLETED", pending: completed };
}

/**
 * receipt 폴링으로 pending 완료 (구독이 늦을 때 백업).
 */
export async function tryCompletePendingFromReceipt(pendingId, { poll = true } = {}) {
  const pending = findPendingById(pendingId);
  if (!pending || pending.status !== "PENDING") {
    return { ok: false, reason: "NO_PENDING" };
  }

  const image = getImageById(pending.imageId);
  if (!image) {
    markPendingFailed(pending.pendingId, "NOT_FOUND", "해당 이미지를 찾을 수 없습니다.");
    return { ok: false, reason: "NOT_FOUND" };
  }

  let receipt = null;
  try {
    if (poll) {
      const deadline = Date.now() + RECEIPT_POLL_MAX_MS;
      while (Date.now() < deadline) {
        receipt = await getProvider().getTransactionReceipt(pending.txHash);
        if (receipt && receipt.status === 1) break;
        await sleep(RECEIPT_POLL_INTERVAL_MS);
      }
    } else {
      receipt = await getProvider().getTransactionReceipt(pending.txHash);
    }
  } catch (error) {
    return {
      ok: false,
      reason: "RPC_ERROR",
      message: error?.message ?? "블록체인 RPC 조회에 실패했습니다.",
    };
  }

  if (!receipt) {
    return { ok: false, reason: "TX_NOT_FOUND" };
  }
  if (receipt.status !== 1) {
    markPendingFailed(
      pending.pendingId,
      "TX_NOT_CONFIRMED",
      "트랜잭션이 성공적으로 확정되지 않았습니다."
    );
    return { ok: false, reason: "TX_NOT_CONFIRMED" };
  }

  const contract = getReadOnlyContract();
  const contractAddress = String(await contract.getAddress()).toLowerCase();
  const hasContractLog = receipt.logs?.some(
    (log) => String(log.address ?? "").toLowerCase() === contractAddress
  );
  if (!hasContractLog) {
    markPendingFailed(
      pending.pendingId,
      "CONTRACT_MISMATCH",
      "해당 트랜잭션에 컨트랙트 이벤트가 없습니다."
    );
    return { ok: false, reason: "CONTRACT_MISMATCH" };
  }

  const parsed = parseImagePurchasedFromReceipt(receipt);
  if (!parsed) {
    markPendingFailed(
      pending.pendingId,
      "EVENT_NOT_FOUND",
      "ImagePurchased 이벤트를 찾을 수 없습니다."
    );
    return { ok: false, reason: "EVENT_NOT_FOUND" };
  }

  if (!parsedMatchesPending(pending, parsed, image)) {
    markPendingFailed(
      pending.pendingId,
      "RECEIPT_MISMATCH",
      "영수증 이벤트와 구매 요청 정보가 일치하지 않습니다."
    );
    return { ok: false, reason: "RECEIPT_MISMATCH" };
  }

  upsertPurchaseEvent({
    txHash: pending.txHash,
    buyerAddress: parsed.buyer,
    ownerAddress: parsed.owner,
    imageHash: parsed.pHash,
    amount: Number(parsed.amount),
    blockNumber: receipt.blockNumber,
    eventTimestamp: parsed.timestamp,
  });

  const completed = finalizePendingOrder(pending);
  return { ok: completed?.status === "COMPLETED", pending: completed };
}

/** POST 직후: 구독 이벤트가 이미 DB에 있으면 즉시 완료 시도 */
export function tryCompletePendingImmediately(pendingId) {
  const pending = findPendingById(pendingId);
  if (!pending || pending.status !== "PENDING") {
    return { ok: false, reason: "NO_PENDING" };
  }
  return tryCompletePendingFromSubscription(pending.txHash);
}

export function buildOrderStatusResponse(pending) {
  if (!pending) return null;

  const base = {
    pendingId: pending.pendingId,
    status: pending.status,
    txHash: pending.txHash,
    imageId: pending.imageId,
  };

  if (pending.status === "COMPLETED") {
    const order =
      (pending.orderId ? findOrderByTxHash(pending.txHash) : null) ??
      findOrderByTxHash(pending.txHash);
    return {
      ...base,
      orderId: pending.orderId ?? order?.orderId ?? null,
      price: order?.price ?? null,
      orderStatus: order?.orderStatus ?? "PAID",
      purchasedAt: order?.purchasedAt ?? null,
      message: "구매가 완료되었습니다.",
    };
  }

  if (pending.status === "FAILED") {
    return {
      ...base,
      code: pending.failureCode,
      message: pending.failureMessage ?? "구매 처리에 실패했습니다.",
    };
  }

  return {
    ...base,
    message: "구매 확인 중입니다.",
  };
}
