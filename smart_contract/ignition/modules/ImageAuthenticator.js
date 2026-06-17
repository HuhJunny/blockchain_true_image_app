import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("ImageAuthenticatorModule", (m) => {
  const backendSigner = m.getParameter("backendSigner");
  const imageAuthenticator = m.contract("ImageAuthenticator", [backendSigner]);

  return { imageAuthenticator };
});
