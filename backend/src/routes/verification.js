import crypto from "crypto";
import express from "express";
import multer from "multer";
import { findImageByContentHash, listImagesWithPerceptualHash } from "../data/imageStore.js";
import { findImageByWatermarkedDeliveryHash } from "../data/watermarkDeliveryStore.js";
import {
  computePerceptualHash,
  findBestPerceptualMatch,
  LIKELY_RESIZE_THRESHOLD,
} from "../services/perceptualHashService.js";
import { verifyToken } from "../middlewares/authMiddleware.js";

const router = express.Router();

const normalize0xHex = (raw) => {
  const s = String(raw ?? "").trim();
  if (!s) return "";
  return s.startsWith("0x") ? s.toLowerCase() : `0x${s}`.toLowerCase();
};

const digestBufferSha256Hex0x = (buffer) =>
  `0x${crypto.createHash("sha256").update(buffer).digest("hex")}`;

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024,
  },
});

router.post("/check", verifyToken, upload.single("image"), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: "image 파일은 필수입니다." });
    }

    const computed = digestBufferSha256Hex0x(req.file.buffer);
    const normalized = normalize0xHex(computed);
    const matched = findImageByContentHash(normalized);

    if (matched) {
      return res.status(200).json({
        isVerified: true,
        verificationStatus: "MATCHED",
        verificationTier: "L1_EXACT",
        imageId: matched.id,
        imageHash: matched.imageHash,
        txHash: matched.txHash,
        message: "등록된 원본과 동일한 파일입니다.",
      });
    }

    const wmMatch = findImageByWatermarkedDeliveryHash(normalized);
    if (wmMatch) {
      return res.status(200).json({
        isVerified: true,
        verificationStatus: "MATCHED_WATERMARK",
        verificationTier: "L1_EXACT",
        imageId: wmMatch.imageId,
        imageHash: wmMatch.imageHash,
        deliveredContentHash: normalized,
        orderId: wmMatch.orderId,
        txHash: wmMatch.txHash,
        message: "플랫폼에서 발급한 워터마크 복사본과 일치합니다.",
      });
    }

    try {
      const uploadPerceptualHash = await computePerceptualHash(req.file.buffer);
      const candidates = listImagesWithPerceptualHash();
      const likely = findBestPerceptualMatch(uploadPerceptualHash, candidates);

      if (likely) {
        return res.status(200).json({
          isVerified: false,
          verificationStatus: "LIKELY_RESIZE",
          verificationTier: "L3_PERCEPTUAL",
          imageId: likely.imageId,
          imageHash: likely.imageHash,
          txHash: likely.txHash,
          hammingDistance: likely.hammingDistance,
          threshold: LIKELY_RESIZE_THRESHOLD,
          uploadedImageHash: normalized,
          message:
            "등록된 원본과 바이트는 다르지만, 리사이즈·압축된 동일 이미지일 가능성이 있습니다.",
        });
      }
    } catch (phashError) {
      console.warn("[POST /verification/check] perceptual hash 실패:", phashError?.message || phashError);
    }

    return res.status(200).json({
      isVerified: false,
      verificationStatus: "NOT_MATCHED",
      verificationTier: "NONE",
      imageHash: normalized,
      reason:
        "등록된 원본 해시 또는 플랫폼에서 발급한 워터마크 복사본 해시와 일치하지 않습니다.",
    });
  } catch (error) {
    console.error("[POST /verification/check]", error);
    return res.status(500).json({ message: "해시 계산 또는 검증 처리 중 서버 오류가 발생했습니다." });
  }
});

router.use((error, req, res, next) => {
  if (error instanceof multer.MulterError && error.code === "LIMIT_FILE_SIZE") {
    return res.status(413).json({ message: "업로드 파일 크기 제한을 초과했습니다." });
  }
  return next(error);
});

export default router;
