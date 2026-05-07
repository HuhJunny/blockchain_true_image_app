import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("ImageAuthenticatorModule", (m) => {
  const imageAuthenticator = m.contract("ImageAuthenticator");

  return { imageAuthenticator };
});
