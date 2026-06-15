import db from "./db.js";

const normalizeTxHash = (raw) => String(raw ?? "").trim().toLowerCase();
const normalizeAddress = (raw) => String(raw ?? "").trim().toLowerCase();
const normalizeImageHash = (raw) => String(raw ?? "").trim();

/**
 * 컨트랙트 ImagePurchased 구독·검증 결과를 저장 (tx_hash 기준 upsert).
 */
export function upsertPurchaseEvent({
  txHash,
  buyerAddress,
  ownerAddress,
  imageHash,
  amount,
  blockNumber = null,
  eventTimestamp = null,
}) {
  const normalizedTx = normalizeTxHash(txHash);
  if (!normalizedTx) {
    throw new Error("txHash is required");
  }

  db.prepare(
    `
    INSERT INTO contract_purchase_events (
      tx_hash, buyer_address, owner_address, image_hash, amount,
      block_number, event_timestamp, created_at
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'))
    ON CONFLICT(tx_hash) DO UPDATE SET
      buyer_address = excluded.buyer_address,
      owner_address = excluded.owner_address,
      image_hash = excluded.image_hash,
      amount = excluded.amount,
      block_number = excluded.block_number,
      event_timestamp = excluded.event_timestamp
    `
  ).run(
    normalizedTx,
    normalizeAddress(buyerAddress),
    normalizeAddress(ownerAddress),
    normalizeImageHash(imageHash),
    Number(amount),
    blockNumber !== null && blockNumber !== undefined ? Number(blockNumber) : null,
    eventTimestamp !== null && eventTimestamp !== undefined ? Number(eventTimestamp) : null
  );

  return findPurchaseEventByTxHash(normalizedTx);
}

export function findPurchaseEventByTxHash(txHash) {
  const normalizedTx = normalizeTxHash(txHash);
  if (!normalizedTx) return null;

  const row = db
    .prepare(
      `
      SELECT
        id, tx_hash, buyer_address, owner_address, image_hash, amount,
        block_number, event_timestamp, created_at
      FROM contract_purchase_events
      WHERE tx_hash = ?
      `
    )
    .get(normalizedTx);

  if (!row) return null;

  return {
    id: row.id,
    txHash: row.tx_hash,
    buyerAddress: row.buyer_address,
    ownerAddress: row.owner_address,
    imageHash: row.image_hash,
    amount: row.amount,
    blockNumber: row.block_number,
    eventTimestamp: row.event_timestamp,
    createdAt: row.created_at,
  };
}

export function findPurchaseEventByBuyerAndImageHash(buyerAddress, imageHash) {
  const buyer = normalizeAddress(buyerAddress);
  const hash = normalizeImageHash(imageHash);
  if (!buyer || !hash) return null;

  const row = db
    .prepare(
      `
      SELECT
        id, tx_hash, buyer_address, owner_address, image_hash, amount,
        block_number, event_timestamp, created_at
      FROM contract_purchase_events
      WHERE buyer_address = ? AND LOWER(TRIM(image_hash)) = LOWER(TRIM(?))
      ORDER BY id DESC
      LIMIT 1
      `
    )
    .get(buyer, hash);

  if (!row) return null;

  return {
    id: row.id,
    txHash: row.tx_hash,
    buyerAddress: row.buyer_address,
    ownerAddress: row.owner_address,
    imageHash: row.image_hash,
    amount: row.amount,
    blockNumber: row.block_number,
    eventTimestamp: row.event_timestamp,
    createdAt: row.created_at,
  };
}
