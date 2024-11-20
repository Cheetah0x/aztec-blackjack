import React, { createContext, useState, useContext, ReactNode } from "react";
import { Address } from "viem";
import { Contract, AccountWallet } from "@aztec/aztec.js";
import { TokenContract, TokenContractArtifact } from "../circuits/src/artifacts/Token"; // Adjust path
import { BlackJackContract, BlackJackContractArtifact } from "../circuits/src/artifacts/BlackJack";

interface AztecAccountContextType {
  isConnected: boolean;
  connect: () => void;
  disconnect: () => void;
  evmAccount: Address | null;
  setEvmAccount: (account: Address | null) => void;
  deployTokenContract: (wallet: AccountWallet) => Promise<{
    tokenAddress: Address | null;
    blackjackAddress: Address | null;
    tokenInstance: TokenContract | null;
    blackjackInstance: BlackJackContract | null;
  }>;
  isLoading: boolean;
  error: string | null;
  tokenAddress: Address | null;
  blackjackAddress: Address | null;
  tokenInstance: TokenContract | null;
  blackjackInstance: BlackJackContract | null;
}

const AztecAccountContext = createContext<AztecAccountContextType | undefined>(
  undefined
);

export const AztecAccountProvider: React.FC<{ children: ReactNode }> = ({
  children,
}) => {
  const [isConnected, setIsConnected] = useState(false);
  const [evmAccount, setEvmAccount] = useState<Address | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [tokenAddress, setTokenAddress] = useState<Address | null>(null);
  const [blackjackAddress, setBlackjackAddress] = useState<Address | null>(null);
  const [tokenInstance, setTokenInstance] = useState<TokenContract | null>(null);
  const [blackjackInstance, setBlackjackInstance] = useState<BlackJackContract | null>(null);

  const connect = () => {
    setIsConnected(true);
  };

  const disconnect = () => {
    setIsConnected(false);
    setEvmAccount(null);
    setError(null);
  };

  const deployTokenContract = async (wallet: AccountWallet) => {
    if (!wallet || !evmAccount) {
      setError("Wallet is required to deploy a token contract.");
      console.error("Wallet is required to deploy a token contract.");
      return {
        tokenAddress: null,
        blackjackAddress: null,
        tokenInstance: null,
        blackjackInstance: null
      };
    }

    setIsLoading(true);
    setError(null);

    const address = await wallet.getAddress()

    try {
      const tokenContract = await Contract.deploy(
        wallet, // Use the wallet for deployment
        TokenContractArtifact,
        [
            address,
            'TestToken0000000000000000000000',
            'TT00000000000000000000000000000',
            18,
            ],
        "constructor"
      )
        .send()
        .deployed();

      const playerTokenInstance = await TokenContract.at(tokenContract.address, wallet);
      console.log("Player token instance created at");

    //make contract instance
    const blackjackContract = await Contract.deploy(
        wallet,
        BlackJackContractArtifact,
        [],
        "constructor"
    )
        .send()
        .deployed();

    // instance of the contract for the player
    const playerBlackJackInstance = await BlackJackContract.at(
            blackjackContract.address,
            wallet
        );
        console.log("Player instance created at");

        


      console.log("Token contract deployed at:", tokenContract.address);
      console.log("Blackjack contract deployed at:", blackjackContract.address);

      setTokenAddress(tokenContract.address.toString() as Address);
    setTokenInstance(playerTokenInstance);
      setBlackjackAddress(blackjackContract.address.toString() as Address);
      setBlackjackInstance(playerBlackJackInstance);
      
      return {
        tokenAddress: tokenContract.address.toString() as Address,
        blackjackAddress: blackjackContract.address.toString() as Address,
        tokenInstance: playerTokenInstance,
        blackjackInstance: playerBlackJackInstance
      };
    } catch (err) {
      console.error("Error deploying token contract:", err);
      setError("Failed to deploy token contract. Please try again.");
      return {
        tokenAddress: null,
        blackjackAddress: null,
        tokenInstance: null,
        blackjackInstance: null
      };
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <AztecAccountContext.Provider
      value={{
        tokenAddress,
        blackjackAddress,
        tokenInstance,
        blackjackInstance,
        isConnected,
        connect,
        disconnect,
        evmAccount,
        setEvmAccount,
        deployTokenContract,
        isLoading,
        error,
      }}
    >
      {children}
    </AztecAccountContext.Provider>
  );
};

export const useAztecAccount = () => {
  const context = useContext(AztecAccountContext);
  if (context === undefined) {
    throw new Error(
      "useAztecAccount must be used within an AztecAccountProvider"
    );
  }
  return context;
};



