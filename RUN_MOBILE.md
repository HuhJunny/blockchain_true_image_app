# Mobile run checklist

## 1. Deploy the new contract

Current Sepolia deployment:

```text
contractAddress=0x103315f0d90Fd0DB0A665f0942A32A868c1d4E2D
backendSigner=0x67285A909eAa6EBB420446d0e7b66799889530d5
deploymentTx=0x3a988e543cd02aa55201adce5f6a15915f07288338864de65703e437f5a979b8
```

```powershell
cd C:\Users\USER\Documents\trans\smart_contract
copy .env.example .env
```

Fill `smart_contract\.env`:

```env
ALCHEMY_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/...
PRIVATE_KEY=0x...deployer-private-key-with-sepolia-eth
BACKEND_SIGNER_PRIVATE_KEY=0x...backend-approval-signer-private-key
```

Deploy:

```powershell
npx hardhat run scripts/deploy-image-authenticator.js --network sepolia
```

Copy the printed `contractAddress`.

## 2. Run the backend

```powershell
cd C:\Users\USER\Documents\trans\backend
copy .env.example .env
```

Fill `backend\.env`:

```env
PORT=4000
JWT_SECRET=replace-with-a-long-random-secret
BLOCKCHAIN_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/...
BLOCKCHAIN_CHAIN_ID=11155111
BLOCKCHAIN_CONTRACT_ADDRESS=0x103315f0d90Fd0DB0A665f0942A32A868c1d4E2D
BLOCKCHAIN_CONTRACT_ABI_PATH=../smart_contract/artifacts/contracts/ImageAuthenticator.sol/ImageAuthenticator.json
BACKEND_SIGNER_PRIVATE_KEY=0x...same-backend-approval-signer-private-key
```

Run:

```powershell
npm run dev
```

## 3. Run Flutter on a phone

Find the PC LAN IP:

```powershell
ipconfig
```

Use the IPv4 address reachable from the phone, then run:

```powershell
cd C:\Users\USER\Documents\trans\frontend
flutter devices
flutter run -d <device-id> --dart-define=API_BASE_URL=http://<PC-IP>:4000 --dart-define=REOWN_PROJECT_ID=<your-reown-project-id>
```

If no Android phone appears in `flutter devices`, enable USB debugging on the phone, reconnect the cable, accept the RSA prompt, and run `flutter doctor`.
