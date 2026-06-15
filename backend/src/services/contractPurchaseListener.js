import { upsertPurchaseEvent } from "../data/purchaseEventStore.js";
import { getReadOnlyContract } from "./blockchainService.js";
import { tryCompletePendingFromSubscription } from "./purchaseCompletionService.js";

let listenerStarted = false;

/**
 * ImagePurchased 이벤트를 구독해 contract_purchase_events 테이블에 저장.
 */
export function startContractPurchaseListener() {
  if (listenerStarted) {
    return;
  }

  if (!process.env.BLOCKCHAIN_RPC_URL?.trim()) {
    console.warn("[purchase-listener] BLOCKCHAIN_RPC_URL 없음 — 구독 비활성");
    return;
  }

  try {
    const contract = getReadOnlyContract();

    contract.on(
      "ImagePurchased",
      (buyer, owner, pHash, amount, timestamp, event) => {
        try {
          const txHash = event?.log?.transactionHash ?? event?.transactionHash;
          if (!txHash) return;

          upsertPurchaseEvent({
            txHash,
            buyerAddress: buyer,
            ownerAddress: owner,
            imageHash: pHash,
            amount: Number(amount),
            blockNumber: event?.log?.blockNumber ?? event?.blockNumber ?? null,
            eventTimestamp: Number(timestamp),
          });

          tryCompletePendingFromSubscription(txHash);
        } catch (error) {
          console.error("[purchase-listener] 이벤트 저장 실패:", error?.message || error);
        }
      }
    );

    listenerStarted = true;
    console.log("[purchase-listener] ImagePurchased 구독 시작");
  } catch (error) {
    console.error("[purchase-listener] 시작 실패:", error?.message || error);
  }
}
