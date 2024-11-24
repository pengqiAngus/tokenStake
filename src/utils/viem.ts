import { sepolia } from "viem/chains";
import { PublicClient, defineChain, createPublicClient, http } from "viem";
import { mainnet } from 'viem/chains'




export const localhost = /*#__PURE__*/ defineChain({
  id: 31337,
  name: "localhost",
  nativeCurrency: { name: "Angus", symbol: "KPQ", decimals: 18 },
  rpcUrls: {
    default: { http: ["http://127.0.0.1:8545"] },
  },
});

export const viemClients = (chaiId: number): PublicClient => {
  const clients: {
    [key: number]: PublicClient;
  } = {
    [localhost.id]: createPublicClient({
      chain: localhost,
      transport: http(),
    }),
  };
    
    
  return clients[chaiId];
}