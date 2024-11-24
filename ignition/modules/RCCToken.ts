// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";


const RCCToken = buildModule("RccTokenModule", (m) => {
  const rCCToken = m.contract("RccToken");

  return { rCCToken };
});

export default RCCToken;

