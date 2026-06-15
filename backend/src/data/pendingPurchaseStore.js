import db from "./db.js";

const normalizeTxHash = (raw) => String(raw ?? "").trim().toLowerCase();
const normalizeAddress = (raw) => String(raw ?? "").trim().toLowerCase();

const mapRow = (row) =>
  row
    ? {
        pendingId: row.id,
        buyerUserId: row.buyer_user_id,
        buyerWalletAddress: row.buyer_wallet_address,
        imageId: row.image_id,
        paymentMethod: row.payment_method,
        txHash: row.tx_hash,
        status: row.status,
        orderId: row.order_id,
        failureCode: row.failure_code,
        failureMessage: row.failure_message,
        createdAt: row.created_at,
        updatedAt: row.updated_at,
      }
    : null;

export function findPendingById(pendingId) {
  const id = Number(pendingId);
  if (!Number.isInteger(id) || id < 1) return null;
  return mapRow(
    db
      .prepare(
        `
        SELECT
          id, buyer_user_id, buyer_wallet_address, image_id, payment_method,
          tx_hash, status, order_id, failure_code, failure_message,
          created_at, updated_at
        FROM pending_purchases
        WHERE id = ?
        `
      )
      .get(id)
  );
}

export function findPendingByTxHash(txHash) {
  const normalizedTx = normalizeTxHash(txHash);
  if (!normalizedTx) return null;
  return mapRow(
    db
      .prepare(
        `
        SELECT
          id, buyer_user_id, buyer_wallet_address, image_id, payment_method,
          tx_hash, status, order_id, failure_code, failure_message,
          created_at, updated_at
        FROM pending_purchases
        WHERE tx_hash = ?
        `
      )
      .get(normalizedTx)
  );
}

export function createPendingPurchase({
  buyerUserId,
  buyerWalletAddress,
  imageId,
  paymentMethod,
  txHash,
}) {
  const normalizedTx = normalizeTxHash(txHash);
  const wallet = normalizeAddress(buyerWalletAddress);
  const now = new Date().toISOString();

  const result = db
    .prepare(
      `
      INSERT INTO pending_purchases (
        buyer_user_id, buyer_wallet_address, image_id, payment_method,
        tx_hash, status, created_at, updated_at
      )
      VALUES (?, ?, ?, ?, ?, 'PENDING', ?, ?)
      `
    )
    .run(buyerUserId, wallet, imageId, paymentMethod, normalizedTx, now, now);

  return findPendingById(result.lastInsertRowid);
}

export function markPendingCompleted(pendingId, orderId) {
  const now = new Date().toISOString();
  db.prepare(
    `
    UPDATE pending_purchases
    SET status = 'COMPLETED', order_id = ?, failure_code = NULL, failure_message = NULL, updated_at = ?
    WHERE id = ? AND status = 'PENDING'
    `
  ).run(orderId, now, pendingId);
  return findPendingById(pendingId);
}

export function markPendingFailed(pendingId, failureCode, failureMessage) {
  const now = new Date().toISOString();
  db.prepare(
    `
    UPDATE pending_purchases
    SET status = 'FAILED', failure_code = ?, failure_message = ?, updated_at = ?
    WHERE id = ? AND status = 'PENDING'
    `
  ).run(failureCode, failureMessage ?? null, now, pendingId);
  return findPendingById(pendingId);
}

export function markPendingTimeout(pendingId) {
  return markPendingFailed(
    pendingId,
    "TIMEOUT",
    "구매 확인 시간이 초과되었습니다. 트랜잭션 상태를 확인 후 다시 시도해주세요."
  );
}

/** receipt 백업 대상: PENDING 이고 created_at 기준 ageMs 이상 경과 */
export function listPendingForReceiptFallback(ageMs) {
  const seconds = Math.max(0, Math.floor(ageMs / 1000));
  const rows = db
    .prepare(
      `
      SELECT
        id, buyer_user_id, buyer_wallet_address, image_id, payment_method,
        tx_hash, status, order_id, failure_code, failure_message,
        created_at, updated_at
      FROM pending_purchases
      WHERE status = 'PENDING'
        AND datetime(created_at) <= datetime('now', ?)
      ORDER BY id ASC
      `
    )
    .all(`-${seconds} seconds`);
  return rows.map(mapRow);
}

/** 전체 타임아웃 대상 */
export function listPendingForTimeout(ageMs) {
  const seconds = Math.max(0, Math.floor(ageMs / 1000));
  const rows = db
    .prepare(
      `
      SELECT id
      FROM pending_purchases
      WHERE status = 'PENDING'
        AND datetime(created_at) <= datetime('now', ?)
      ORDER BY id ASC
      `
    )
    .all(`-${seconds} seconds`);
  return rows.map((row) => row.id);
}
