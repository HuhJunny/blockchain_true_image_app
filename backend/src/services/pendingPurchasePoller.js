import {
  listPendingForReceiptFallback,
  listPendingForTimeout,
  markPendingTimeout,
} from "../data/pendingPurchaseStore.js";
import {
  RECEIPT_FALLBACK_AGE_MS,
  tryCompletePendingFromReceipt,
} from "./purchaseCompletionService.js";

const POLL_INTERVAL_MS = Number(process.env.PENDING_POLL_INTERVAL_MS ?? 5_000);
const PENDING_TOTAL_TIMEOUT_MS = Number(process.env.PENDING_TOTAL_TIMEOUT_MS ?? 120_000);

let pollerStarted = false;

/**
 * PENDING 구매 요청을 주기적으로 확인.
 * - 30초 경과: receipt 폴링 백업
 * - 120초 경과: TIMEOUT 처리
 */
export function startPendingPurchasePoller() {
  if (pollerStarted) {
    return;
  }

  if (!process.env.BLOCKCHAIN_RPC_URL?.trim()) {
    console.warn("[pending-poller] BLOCKCHAIN_RPC_URL 없음 — 폴링 비활성");
    return;
  }

  pollerStarted = true;
  console.log(
    `[pending-poller] 시작 (receipt 백업 ${RECEIPT_FALLBACK_AGE_MS}ms, timeout ${PENDING_TOTAL_TIMEOUT_MS}ms)`
  );

  setInterval(async () => {
    try {
      const timeoutIds = listPendingForTimeout(PENDING_TOTAL_TIMEOUT_MS);
      for (const pendingId of timeoutIds) {
        markPendingTimeout(pendingId);
      }

      const receiptTargets = listPendingForReceiptFallback(RECEIPT_FALLBACK_AGE_MS);
      for (const pending of receiptTargets) {
        await tryCompletePendingFromReceipt(pending.pendingId, { poll: true });
      }
    } catch (error) {
      console.error("[pending-poller] 처리 실패:", error?.message || error);
    }
  }, POLL_INTERVAL_MS);
}
