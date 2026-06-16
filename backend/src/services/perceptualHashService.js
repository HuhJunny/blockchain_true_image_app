import imghash from "imghash";

/** blockhash 해밍 거리 ≤ threshold 이면 리사이즈/압축 변형 가능성 */
export const LIKELY_RESIZE_THRESHOLD = Number(
  process.env.PHASH_LIKELY_RESIZE_THRESHOLD ?? 10
);

export async function computePerceptualHash(buffer) {
  if (!buffer?.length) {
    throw new Error("이미지 버퍼가 비어 있습니다.");
  }
  return imghash.hash(buffer);
}

export function perceptualHammingDistance(hashA, hashB) {
  return imghash.hammingDistance(String(hashA ?? ""), String(hashB ?? ""));
}

/**
 * @param {string} uploadHash
 * @param {Array<{ id, imageHash, txHash, perceptualHash }>} candidates
 */
export function findBestPerceptualMatch(uploadHash, candidates, threshold = LIKELY_RESIZE_THRESHOLD) {
  let best = null;

  for (const candidate of candidates) {
    if (!candidate?.perceptualHash) continue;
    const distance = perceptualHammingDistance(uploadHash, candidate.perceptualHash);
    if (distance <= threshold && (!best || distance < best.hammingDistance)) {
      best = {
        imageId: candidate.id,
        imageHash: candidate.imageHash,
        txHash: candidate.txHash,
        hammingDistance: distance,
      };
    }
  }

  return best;
}
