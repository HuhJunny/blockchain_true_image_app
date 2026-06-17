import sharp from "sharp";
import imghash from "imghash";

export const LIKELY_RESIZE_THRESHOLD = Number(
  process.env.PHASH_LIKELY_RESIZE_THRESHOLD ?? 14
);
export const LIKELY_REGION_THRESHOLD = Number(
  process.env.PHASH_LIKELY_REGION_THRESHOLD ?? 12
);

const PATCH_SCALES = [0.45, 0.6, 0.75];
const PATCH_POSITIONS = [0, 0.5, 1];

export async function computePerceptualHash(buffer) {
  if (!buffer?.length) {
    throw new Error("Image buffer is empty.");
  }
  const normalized = await normalizeImageBuffer(buffer);
  return computeHashFromNormalized(normalized);
}

async function normalizeImageBuffer(buffer) {
  return sharp(buffer).rotate().jpeg({ quality: 95 }).toBuffer();
}

async function computeHashFromNormalized(buffer) {
  return imghash.hash(buffer);
}

async function computeRegionHash(normalizedBuffer, region) {
  const cropped = await sharp(normalizedBuffer)
    .extract(region)
    .jpeg({ quality: 90 })
    .toBuffer();
  return computeHashFromNormalized(cropped);
}

function uniqueRegions(width, height) {
  const seen = new Set();
  const regions = [];

  const addRegion = (label, left, top, regionWidth, regionHeight) => {
    const normalized = {
      left: Math.max(0, Math.min(width - 1, Math.round(left))),
      top: Math.max(0, Math.min(height - 1, Math.round(top))),
      width: Math.max(1, Math.min(width, Math.round(regionWidth))),
      height: Math.max(1, Math.min(height, Math.round(regionHeight))),
    };
    normalized.left = Math.min(normalized.left, width - normalized.width);
    normalized.top = Math.min(normalized.top, height - normalized.height);

    const key = `${normalized.left}:${normalized.top}:${normalized.width}:${normalized.height}`;
    if (seen.has(key)) return;
    seen.add(key);
    regions.push({ label, ...normalized });
  };

  for (const scale of PATCH_SCALES) {
    const regionWidth = width * scale;
    const regionHeight = height * scale;
    const maxLeft = width - regionWidth;
    const maxTop = height - regionHeight;

    for (const y of PATCH_POSITIONS) {
      for (const x of PATCH_POSITIONS) {
        addRegion(
          `scale-${scale}:x-${x}:y-${y}`,
          maxLeft * x,
          maxTop * y,
          regionWidth,
          regionHeight
        );
      }
    }
  }

  return regions;
}

export async function computePerceptualPatchHashes(buffer) {
  if (!buffer?.length) {
    throw new Error("Image buffer is empty.");
  }

  const normalized = await normalizeImageBuffer(buffer);
  return computePerceptualPatchHashesFromNormalized(normalized);
}

async function computePerceptualPatchHashesFromNormalized(normalizedBuffer) {
  const metadata = await sharp(normalizedBuffer).metadata();
  const width = metadata.width;
  const height = metadata.height;
  if (!width || !height) return [];

  const regions = uniqueRegions(width, height);
  const patches = await Promise.all(
    regions.map(async (region) => ({
      label: region.label,
      hash: await computeRegionHash(normalizedBuffer, {
        left: region.left,
        top: region.top,
        width: region.width,
        height: region.height,
      }),
    }))
  );

  const seen = new Set();
  return patches.filter((patch) => {
    if (!patch.hash || seen.has(patch.hash)) return false;
    seen.add(patch.hash);
    return true;
  });
}

export async function computePerceptualFingerprint(buffer) {
  if (!buffer?.length) {
    throw new Error("Image buffer is empty.");
  }

  const normalized = await normalizeImageBuffer(buffer);
  const [perceptualHash, perceptualPatchHashes] = await Promise.all([
    computeHashFromNormalized(normalized),
    computePerceptualPatchHashesFromNormalized(normalized),
  ]);
  return { perceptualHash, perceptualPatchHashes };
}

function toBinaryHash(hash) {
  const value = String(hash ?? "").trim();
  if (!value) return "";
  if (/^[01]+$/.test(value)) return value;

  const hex = value.startsWith("0x") ? value.slice(2) : value;
  return imghash.hexToBinary(hex);
}

export function perceptualHammingDistance(hashA, hashB) {
  const a = toBinaryHash(hashA);
  const b = toBinaryHash(hashB);
  if (!a || !b || a.length !== b.length) {
    return Number.MAX_SAFE_INTEGER;
  }

  let distance = 0;
  for (let i = 0; i < a.length; i += 1) {
    if (a[i] !== b[i]) distance += 1;
  }
  return distance;
}

function normalizePatchHashes(value) {
  if (!value) return [];
  if (Array.isArray(value)) return value;
  if (typeof value !== "string") return [];

  try {
    const parsed = JSON.parse(value);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function normalizeFingerprint(value) {
  if (typeof value === "string") {
    return {
      perceptualHash: value,
      perceptualPatchHashes: [],
    };
  }

  return {
    perceptualHash: value?.perceptualHash ?? value?.hash ?? "",
    perceptualPatchHashes: normalizePatchHashes(
      value?.perceptualPatchHashes ?? value?.patchHashes
    ),
  };
}

function comparableHashes(fingerprint) {
  const hashes = [];
  if (fingerprint.perceptualHash) {
    hashes.push({
      scope: "full",
      label: "full",
      hash: fingerprint.perceptualHash,
    });
  }

  for (const patch of fingerprint.perceptualPatchHashes) {
    const hash = typeof patch === "string" ? patch : patch?.hash;
    if (!hash) continue;
    hashes.push({
      scope: "region",
      label: typeof patch === "string" ? "region" : patch.label ?? "region",
      hash,
    });
  }

  return hashes;
}

function pairThreshold(uploadHash, candidateHash, options) {
  if (uploadHash.scope === "full" && candidateHash.scope === "full") {
    return options.fullThreshold;
  }
  return options.regionThreshold;
}

function compareHashPair(uploadHash, candidateHash, candidate, options, best) {
  const threshold = pairThreshold(uploadHash, candidateHash, options);
  const distance = perceptualHammingDistance(uploadHash.hash, candidateHash.hash);
  if (distance > threshold || (best && distance >= best.hammingDistance)) {
    return best;
  }

  return {
    imageId: candidate.id,
    imageHash: candidate.imageHash,
    txHash: candidate.txHash,
    hammingDistance: distance,
    threshold,
    matchType:
      uploadHash.scope === "full" && candidateHash.scope === "full"
        ? "FULL_PHASH"
        : uploadHash.scope === "full"
          ? "UPLOAD_FULL_TO_CANDIDATE_REGION"
          : "UPLOAD_REGION_TO_CANDIDATE_FULL",
    uploadRegion: uploadHash.label,
    candidateRegion: candidateHash.label,
  };
}

/**
 * @param {string|{ perceptualHash, perceptualPatchHashes }} uploadFingerprint
 * @param {Array<{ id, imageHash, txHash, perceptualHash, perceptualPatchHashes }>} candidates
 */
export function findBestPerceptualMatch(
  uploadFingerprint,
  candidates,
  options = {}
) {
  const normalizedOptions =
    typeof options === "number"
      ? {
          fullThreshold: options,
          regionThreshold: LIKELY_REGION_THRESHOLD,
        }
      : {
          fullThreshold: options.fullThreshold ?? LIKELY_RESIZE_THRESHOLD,
          regionThreshold: options.regionThreshold ?? LIKELY_REGION_THRESHOLD,
        };
  const uploadHashes = comparableHashes(normalizeFingerprint(uploadFingerprint));
  const uploadFull = uploadHashes.find((hash) => hash.scope === "full");
  const uploadRegions = uploadHashes.filter((hash) => hash.scope === "region");
  let best = null;

  for (const candidate of candidates) {
    if (!candidate?.perceptualHash) continue;
    const candidateHashes = comparableHashes(normalizeFingerprint(candidate));
    const candidateFull = candidateHashes.find((hash) => hash.scope === "full");
    const candidateRegions = candidateHashes.filter((hash) => hash.scope === "region");

    if (uploadFull && candidateFull) {
      best = compareHashPair(
        uploadFull,
        candidateFull,
        candidate,
        normalizedOptions,
        best
      );
    }

    if (uploadFull) {
      for (const candidateRegion of candidateRegions) {
        best = compareHashPair(
          uploadFull,
          candidateRegion,
          candidate,
          normalizedOptions,
          best
        );
      }
    }

    if (candidateFull) {
      for (const uploadRegion of uploadRegions) {
        best = compareHashPair(
          uploadRegion,
          candidateFull,
          candidate,
          normalizedOptions,
          best
        );
      }
    }
  }

  return best;
}
