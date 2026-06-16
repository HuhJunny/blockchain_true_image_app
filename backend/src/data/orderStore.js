import db from "./db.js";

const normalizeTxHash = (raw) => String(raw ?? "").trim().toLowerCase();

/**
 * PAID 주문 생성. 동일 buyer+image_id 또는 동일 tx_hash 중복 시 거부.
 * @returns {{ ok: true, orderId, imageId, price, orderStatus, purchasedAt, txHash } | { error: 'NOT_FOUND'|'SELF'|'ALREADY_PURCHASED'|'DUPLICATE_TX' }}
 */
export function createPaidOrder({ buyerUserId, imageId, paymentMethod, txHash }) {
  const normalizedTx = normalizeTxHash(txHash);
  if (!normalizedTx) {
    return { error: "INVALID_TX" };
  }

  const txn = db.transaction((buyerId, imgId, payMethod, tx) => {
    const image = db
      .prepare(`SELECT id, user_id, price FROM images WHERE id = ?`)
      .get(imgId);
    if (!image) {
      return { error: "NOT_FOUND" };
    }
    if (image.user_id === buyerId) {
      return { error: "SELF" };
    }

    const existingPurchase = db
      .prepare(
        `
        SELECT id FROM orders
        WHERE buyer_user_id = ? AND image_id = ?
        LIMIT 1
        `
      )
      .get(buyerId, imgId);
    if (existingPurchase) {
      return { error: "ALREADY_PURCHASED" };
    }

    const existingTx = db
      .prepare(`SELECT id FROM orders WHERE tx_hash = ? LIMIT 1`)
      .get(tx);
    if (existingTx) {
      return { error: "DUPLICATE_TX" };
    }

    const purchasedAt = new Date().toISOString();
    const ins = db
      .prepare(
        `
        INSERT INTO orders (
          buyer_user_id, image_id, price, payment_method, order_status, purchased_at, tx_hash
        )
        VALUES (?, ?, ?, ?, 'PAID', ?, ?)
        `
      )
      .run(buyerId, imgId, image.price, payMethod, purchasedAt, tx);

    return {
      ok: true,
      orderId: Number(ins.lastInsertRowid),
      imageId: imgId,
      price: image.price,
      orderStatus: "PAID",
      purchasedAt,
      txHash: tx,
    };
  });

  return txn(buyerUserId, imageId, paymentMethod, normalizedTx);
}

/**
 * 구매자 주문 목록 (최근 구매순). images 조인으로 제목·썸네일 포함.
 */
export function listOrdersByBuyerPaged(buyerUserId, page, pageSize) {
  const offset = page * pageSize;
  const rows = db
    .prepare(
      `
      SELECT
        o.id AS order_id,
        o.image_id,
        i.title,
        i.thumbnail_url,
        o.price,
        o.order_status,
        o.purchased_at,
        o.tx_hash
      FROM orders o
      INNER JOIN images i ON i.id = o.image_id
      WHERE o.buyer_user_id = ?
      ORDER BY datetime(o.purchased_at) DESC, o.id DESC
      LIMIT ? OFFSET ?
      `
    )
    .all(buyerUserId, pageSize, offset);

  return rows.map((row) => ({
    orderId: row.order_id,
    imageId: row.image_id,
    title: row.title,
    thumbnailUrl: row.thumbnail_url,
    price: row.price,
    orderStatus: row.order_status,
    purchasedAt: row.purchased_at,
    txHash: row.tx_hash,
  }));
}

export function getOrderById(orderId) {
  const id = Number(orderId);
  if (!Number.isInteger(id) || id < 1) return null;
  const row = db
    .prepare(
      `SELECT id, buyer_user_id, image_id, order_status, tx_hash FROM orders WHERE id = ?`
    )
    .get(id);
  if (!row) return null;
  return {
    orderId: row.id,
    buyerUserId: row.buyer_user_id,
    imageId: row.image_id,
    orderStatus: row.order_status,
    txHash: row.tx_hash,
  };
}

export function findOrderByTxHash(txHash) {
  const normalizedTx = normalizeTxHash(txHash);
  if (!normalizedTx) return null;

  const row = db
    .prepare(
      `
      SELECT id, buyer_user_id, image_id, price, order_status, tx_hash, purchased_at
      FROM orders
      WHERE tx_hash = ?
      `
    )
    .get(normalizedTx);

  if (!row) return null;

  return {
    orderId: row.id,
    buyerUserId: row.buyer_user_id,
    imageId: row.image_id,
    price: row.price,
    orderStatus: row.order_status,
    txHash: row.tx_hash,
    purchasedAt: row.purchased_at,
  };
}

/** 구매자가 해당 이미지에 대해 가진 첫 주문 id (상세 화면 다운로드 등) */
export function findFirstOrderIdForBuyerAndImage(buyerUserId, imageId) {
  const row = db
    .prepare(
      `
      SELECT id FROM orders
      WHERE buyer_user_id = ? AND image_id = ?
      ORDER BY id ASC
      LIMIT 1
      `
    )
    .get(buyerUserId, imageId);
  return row ? row.id : null;
}
