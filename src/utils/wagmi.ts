import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import {
  arbitrum,
  base,
  mainnet,
  optimism,
  polygon,
  sepolia,
} from 'wagmi/chains';
import { http, createConfig } from "wagmi";

// from https://cloud.walletconnect.com/
const ProjectId = 'e3242412afd6123ce1dda1de23a8c016'
import { type Chain } from "viem";


export const localhostChain = {
  id: 31337,
  name: "Localhost",
  nativeCurrency: { name: "Angus", symbol: "KPQ", decimals: 18 },
  rpcUrls: {
    default: { http: ["http://127.0.0.1:8545"] },
  },
  testnet:true,
} as const satisfies Chain;

export const config = getDefaultConfig({
  appName: "Rcc Stake",
  projectId: ProjectId,
  chains: [sepolia, localhostChain],
  ssr: true,
});

export const defaultChainId: number = localhostChain.id;