import { getImageById } from "../data/imageStore.js";
import { upsertPurchaseEvent } from "../data/purchaseEventStore.js";
import {
  getProvider,
  getReadOnlyContract,
  parseImagePurchasedFromReceipt,
} from "./blockchainService.js";

const normalizeTxHash = (raw) => String(raw ?? "").trim().toLowerCase();
const normalizeAddress = (raw) => String(raw ?? "").trim().toLowerCase();

/**
 * txHash 영수증에서 ImagePurchased 이벤트를 파싱해 이미지·구매자와 일치하는지 검증.
 * @returns {{ ok: true, event: object } | { error: string, message?: string }}
 */
export async function verifyPurchaseTx({ txHash, imageId, buyerWalletAddress }) {
  const normalizedTx = normalizeTxHash(txHash);
  const wallet = normalizeAddress(buyerWalletAddress);

  if (!wallet) {
    return { error: "NO_WALLET", message: "구매자 지갑 주소가 필요합니다." };
  }

  const image = getImageById(imageId);
  if (!image) {
    return { error: "NOT_FOUND", message: "해당 이미지를 찾을 수 없습니다." };
  }

  let receipt;
  try {
    receipt = await getProvider().getTransactionReceipt(normalizedTx);
  } catch (error) {
    return {
      error: "RPC_ERROR",
      message: error?.message ?? "블록체인 RPC 조회에 실패했습니다.",
    };
  }

  if (!receipt) {
    return { error: "TX_NOT_FOUND", message: "트랜잭션 영수증을 찾을 수 없습니다." };
  }
  if (receipt.status !== 1) {
    return { error: "TX_NOT_CONFIRMED", message: "트랜잭션이 성공적으로 확정되지 않았습니다." };
  }

  const contract = getReadOnlyContract();
  const contractAddress = String(await contract.getAddress()).toLowerCase();
  const hasContractLog = receipt.logs?.some(
    (log) => String(log.address ?? "").toLowerCase() === contractAddress
  );
  if (!hasContractLog) {
    return {
      error: "CONTRACT_MISMATCH",
      message: "해당 트랜잭션에 컨트랙트 이벤트가 없습니다.",
    };
  }

  const parsed = parseImagePurchasedFromReceipt(receipt);
  if (!parsed) {
    return {
      error: "EVENT_NOT_FOUND",
      message: "ImagePurchased 이벤트를 찾을 수 없습니다.",
    };
  }

  const pHash = String(parsed.pHash ?? "").trim();
  const imageHash = String(image.imageHash ?? "").trim();
  if (pHash.toLowerCase() !== imageHash.toLowerCase()) {
    return { error: "HASH_MISMATCH", message: "이미지 해시가 일치하지 않습니다." };
  }

  const amount = Number(parsed.amount);
  if (!Number.isFinite(amount) || amount !== Number(image.price)) {
    return { error: "PRICE_MISMATCH", message: "결제 금액이 이미지 가격과 일치하지 않습니다." };
  }

  const buyer = normalizeAddress(parsed.buyer);
  if (buyer !== wallet) {
    return { error: "BUYER_MISMATCH", message: "구매자 지갑 주소가 일치하지 않습니다." };
  }

  const storedEvent = upsertPurchaseEvent({
    txHash: normalizedTx,
    buyerAddress: buyer,
    ownerAddress: parsed.owner,
    imageHash: pHash,
    amount,
    blockNumber: receipt.blockNumber,
    eventTimestamp: parsed.timestamp,
  });

  return {
    ok: true,
    event: storedEvent,
  };
}
