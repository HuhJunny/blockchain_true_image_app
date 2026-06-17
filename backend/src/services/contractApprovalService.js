import crypto from "crypto";
import { ethers } from "ethers";
import { getContractAddress } from "./blockchainService.js";

const abiCoder = ethers.AbiCoder.defaultAbiCoder();

export const CONTRACT_ACTIONS = Object.freeze({
  REGISTER_IMAGE: ethers.id("REGISTER_IMAGE"),
  UPDATE_PRICE: ethers.id("UPDATE_PRICE"),
  PURCHASE_IMAGE: ethers.id("PURCHASE_IMAGE"),
});

let signerWallet = null;

const getApprovalPrivateKey = () => {
  const privateKey =
    process.env.BACKEND_SIGNER_PRIVATE_KEY ??
    process.env.BLOCKCHAIN_PRIVATE_KEY ??
    process.env.PRIVATE_KEY;
  if (!privateKey || !privateKey.trim()) {
    throw new Error(
      "BACKEND_SIGNER_PRIVATE_KEY is required to sign contract approvals.",
    );
  }
  return privateKey.trim();
};

const getSignerWallet = () => {
  if (!signerWallet) {
    signerWallet = new ethers.Wallet(getApprovalPrivateKey());
  }
  return signerWallet;
};

const getChainId = () => {
  const raw = process.env.BLOCKCHAIN_CHAIN_ID ?? process.env.CHAIN_ID ?? "11155111";
  const parsed = Number.parseInt(String(raw), 10);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new Error("BLOCKCHAIN_CHAIN_ID must be a positive integer.");
  }
  return BigInt(parsed);
};

const normalizeAddress = (raw, fieldName) => {
  const value = String(raw ?? "").trim();
  if (!ethers.isAddress(value)) {
    throw new Error(`${fieldName} must be a valid Ethereum address.`);
  }
  return ethers.getAddress(value);
};

const normalizePHash = (raw) => {
  const value = String(raw ?? "").trim();
  if (!value) {
    throw new Error("pHash is required.");
  }
  return value;
};

const normalizePositiveUint = (raw, fieldName) => {
  try {
    const value = BigInt(String(raw ?? "").trim());
    if (value <= 0n) {
      throw new Error();
    }
    return value;
  } catch {
    throw new Error(`${fieldName} must be a positive integer.`);
  }
};

const makeNonce = () =>
  BigInt(`0x${crypto.randomBytes(16).toString("hex")}`);

export const buildContractApprovalHash = ({
  action,
  actor,
  pHash,
  price,
  nonce,
  deadline,
}) => {
  const actionHash = CONTRACT_ACTIONS[action];
  if (!actionHash) {
    throw new Error(`Unsupported contract approval action: ${action}`);
  }

  return ethers.keccak256(
    abiCoder.encode(
      [
        "uint256",
        "address",
        "bytes32",
        "address",
        "bytes32",
        "uint256",
        "uint256",
        "uint256",
      ],
      [
        getChainId(),
        normalizeAddress(getContractAddress(), "contractAddress"),
        actionHash,
        normalizeAddress(actor, "actor"),
        ethers.keccak256(ethers.toUtf8Bytes(normalizePHash(pHash))),
        normalizePositiveUint(price, "price"),
        BigInt(nonce),
        BigInt(deadline),
      ],
    ),
  );
};

export const signContractApproval = async ({
  action,
  actor,
  pHash,
  price,
  ttlSeconds = 5 * 60,
}) => {
  const signer = getSignerWallet();
  const nonce = makeNonce();
  const deadline = BigInt(Math.floor(Date.now() / 1000) + ttlSeconds);
  const approvalHash = buildContractApprovalHash({
    action,
    actor,
    pHash,
    price,
    nonce,
    deadline,
  });
  const signature = await signer.signMessage(ethers.getBytes(approvalHash));

  return {
    action,
    contractAddress: normalizeAddress(getContractAddress(), "contractAddress"),
    backendSigner: signer.address,
    actor: normalizeAddress(actor, "actor"),
    pHash: normalizePHash(pHash),
    price: normalizePositiveUint(price, "price").toString(),
    nonce: nonce.toString(),
    deadline: deadline.toString(),
    approvalHash,
    signature,
  };
};
