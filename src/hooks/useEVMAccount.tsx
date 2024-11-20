import {
    Address,
    WalletClient,
    createPublicClient,
    createWalletClient,
    custom,
    http,
  } from "viem";
  import { anvil } from "viem/chains";
  
  //from 0xrafi

  declare global {
    interface Window {
      ethereum?: {
        request: (args: { method: string }) => Promise<string[]>;
      };
    }
  }
  
  export const publicClient = createPublicClient({
    chain: anvil,
    transport: http(),
  });
  
  export const connectMetaMask = async (): Promise<{
    walletClient: WalletClient;
    account: Address;
  }> => {
    if (typeof window.ethereum !== "undefined") {
      try {
        const accounts = await window.ethereum.request({
          method: "eth_requestAccounts",
        });
  
        const walletClient = createWalletClient({
          chain: anvil,
          transport: custom(window.ethereum),
        });
  
        console.log("Connected to wallet:", accounts[0]);
        return { walletClient, account: accounts[0] as `0x${string}` };
      } catch (error) {
        throw new Error(`Failed to connect to wallet: ${JSON.stringify(error)}`);
      }
    } else {
      throw new Error("MetaMask is not installed");
    }
  };