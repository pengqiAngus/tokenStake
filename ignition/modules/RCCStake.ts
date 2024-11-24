// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";


  //  部署获取到的Rcc Token 地址
  const RccToken = "0x5FbDB2315678afecb367f032d93F642f64180aa3";
  // 质押起始区块高度,可以去sepolia上面读取最新的区块高度
  const startBlock = 6529999;
  // 质押结束的区块高度,sepolia 出块时间是12s,想要质押合约运行x秒,那么endBlock = startBlock+x/12
  const endBlock = 9529999;
  // 每个区块奖励的Rcc token的数量
  const RccPerBlock = "20000000000000000";
const RCCStack = buildModule("RccTokenModule", (m) => {
  const rCCStack = m.contract("RCCStack");
    m.call(rCCStack, "initialize", [
      RccToken,
      startBlock,
      endBlock,
      RccPerBlock,
    ]);
  return { rCCStack };
});

export default RCCStack;

