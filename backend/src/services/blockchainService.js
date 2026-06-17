import { ethers } from "ethers";
import fs from "fs";
import path from "path";

let providerInstance = null;
let contractInstance = null;
let readOnlyContractInstance = null;

const DEFAULT_CONTRACT_ADDRESS = "";
const DEFAULT_ABI_PATH = path.resolve(
  process.cwd(),
  "../smart_contract/artifacts/contracts/ImageAuthenticator.sol/ImageAuthenticator.json"
);

const getRequiredEnv = (key) => {
  const value = process.env[key];
  if (!value || !value.trim()) {
    throw new Error(`${key} 환경변수가 필요합니다.`);
  }
  return value.trim();
};

export const getProvider = () => {
  if (providerInstance) {
    return providerInstance;
  }

  const rpcUrl = getRequiredEnv("BLOCKCHAIN_RPC_URL");
  providerInstance = new ethers.JsonRpcProvider(rpcUrl);
  return providerInstance;
};

const loadContractAbi = () => {
  const abiPath = process.env.BLOCKCHAIN_CONTRACT_ABI_PATH?.trim();
  const abiJsonFromEnv = process.env.BLOCKCHAIN_CONTRACT_ABI_JSON?.trim();

  if (abiPath) {
    const resolvedPath = path.resolve(process.cwd(), abiPath);
    if (!fs.existsSync(resolvedPath)) {
      throw new Error(`ABI 파일을 찾을 수 없습니다: ${resolvedPath}`);
    }
    const raw = fs.readFileSync(resolvedPath, "utf-8");
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : parsed.abi;
  }

  if (abiJsonFromEnv) {
    try {
      return JSON.parse(abiJsonFromEnv);
    } catch {
      throw new Error("BLOCKCHAIN_CONTRACT_ABI_JSON 파싱에 실패했습니다.");
    }
  }

  if (fs.existsSync(DEFAULT_ABI_PATH)) {
    const raw = fs.readFileSync(DEFAULT_ABI_PATH, "utf-8");
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : parsed.abi;
  }

  throw new Error(
    "BLOCKCHAIN_CONTRACT_ABI_PATH, BLOCKCHAIN_CONTRACT_ABI_JSON 또는 기본 ABI 경로가 필요합니다."
  );
};

export const getContractAddress = () =>
  String(
    process.env.BLOCKCHAIN_CONTRACT_ADDRESS ??
      process.env.IMAGE_AUTHENTICATOR_CONTRACT ??
      process.env.CONTRACT_ADDRESS ??
      DEFAULT_CONTRACT_ADDRESS
  ).trim();

export const getReadOnlyContract = () => {
  if (readOnlyContractInstance) {
    return readOnlyContractInstance;
  }

  const contractAbi = loadContractAbi();
  if (!Array.isArray(contractAbi)) {
    throw new Error("ABI 형식이 올바르지 않습니다. 배열(abi)이 필요합니다.");
  }

  readOnlyContractInstance = new ethers.Contract(
    getContractAddress(),
    contractAbi,
    getProvider()
  );
  return readOnlyContractInstance;
};

const getContract = () => {
  if (contractInstance) {
    return contractInstance;
  }

  const privateKey = getRequiredEnv("BLOCKCHAIN_PRIVATE_KEY");
  const contractAbi = loadContractAbi();
  if (!Array.isArray(contractAbi)) {
    throw new Error("ABI 형식이 올바르지 않습니다. 배열(abi)이 필요합니다.");
  }

  const wallet = new ethers.Wallet(privateKey, getProvider());
  contractInstance = new ethers.Contract(getContractAddress(), contractAbi, wallet);
  return contractInstance;
};

const parseEventFromReceipt = (contract, receipt, eventName) => {
  if (!receipt?.logs?.length) {
    return null;
  }
  for (const log of receipt.logs) {
    try {
      const parsed = contract.interface.parseLog(log);
      if (parsed?.name === eventName) {
        return parsed.args;
      }
    } catch {
      // ignore non-contract logs
    }
  }
  return null;
};

export const parseImagePurchasedFromReceipt = (receipt) => {
  const contract = getReadOnlyContract();
  const args = parseEventFromReceipt(contract, receipt, "ImagePurchased");
  if (!args) return null;

  return {
    buyer: args.buyer?.toString?.() ?? null,
    owner: args.owner?.toString?.() ?? null,
    pHash: args.pHash?.toString?.() ?? null,
    amount: args.amount?.toString?.() ?? null,
    timestamp: args.timestamp?.toString?.() ?? null,
  };
};

const parseImageRegisteredEvent = (contract, receipt) =>
  parseEventFromReceipt(contract, receipt, "ImageRegistered");

export const registerImageHashOnChain = async ({ imageHash, price, metadata = "" }) => {
  const expectedChainId = process.env.BLOCKCHAIN_CHAIN_ID
    ? Number.parseInt(process.env.BLOCKCHAIN_CHAIN_ID, 10)
    : null;
  const provider = getProvider();
  const network = await provider.getNetwork();
  if (expectedChainId && Number(network.chainId) !== expectedChainId) {
    throw new Error(
      `체인 ID가 일치하지 않습니다. expected=${expectedChainId}, actual=${network.chainId}`
    );
  }

  const contract = getContract();
  let tx;
  if (typeof contract.registerImage === "function") {
    tx = await contract.registerImage(String(imageHash), BigInt(price));
  } else if (typeof contract.registerImageHash === "function") {
    tx = await contract.registerImageHash(imageHash, String(metadata));
  } else {
    throw new Error(
      "컨트랙트에서 registerImage 또는 registerImageHash 함수를 찾지 못했습니다."
    );
  }
  const receipt = await tx.wait();
  const imageRegistered = parseImageRegisteredEvent(contract, receipt);

  return {
    txHash: tx.hash,
    verificationStatus: receipt?.status === 1 ? "VERIFIED" : "FAILED",
    chainEvent: imageRegistered
      ? {
          owner: imageRegistered.owner?.toString?.() ?? null,
          pHash: imageRegistered.pHash?.toString?.() ?? null,
          price: imageRegistered.price?.toString?.() ?? null,
          timestamp: imageRegistered.timestamp?.toString?.() ?? null,
        }
      : null,
  };
};
