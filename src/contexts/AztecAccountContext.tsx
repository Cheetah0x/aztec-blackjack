import React, { createContext, useState, useContext, ReactNode, useEffect } from "react";
import { Contract, AccountWallet } from "@aztec/aztec.js";
import { TokenContract, TokenContractArtifact } from "../circuits/src/artifacts/Token";
import { BlackJackContract, BlackJackContractArtifact } from "../circuits/src/artifacts/BlackJack";
import { deployerEnv } from "../config"; // Adjust path to your config

interface AztecAccountContextType {
  wallet: AccountWallet | null;
  tokenAddress: string | null;
  blackjackAddress: string | null;
  tokenInstance: TokenContract | null;
  blackjackInstance: BlackJackContract | null;
  isLoading: boolean;
  error: string | null;
}

const AztecAccountContext = createContext<AztecAccountContextType | undefined>(
  undefined
);

export const AztecAccountProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
  const [wallet, setWallet] = useState<AccountWallet | null>(null);
  const [isLoading, setIsLoading] = useState(true); // Start as loading
  const [error, setError] = useState<string | null>(null);
  const [tokenAddress, setTokenAddress] = useState<string | null>(null);
  const [blackjackAddress, setBlackjackAddress] = useState<string | null>(null);
  const [tokenInstance, setTokenInstance] = useState<TokenContract | null>(null);
  const [blackjackInstance, setBlackjackInstance] = useState<BlackJackContract | null>(null);

  useEffect(() => {
    const initializeAztecAccount = async () => {
      try {
        console.log("Creating a new Aztec wallet...");
        const { wallet: newWallet } = await deployerEnv.createNewWallet();
        setWallet(newWallet);
        console.log("Deploying contracts...");
        await deployTokenContract(newWallet);
        setIsLoading(false);
      } catch (e) {
        console.error("Error initializing Aztec account:", e);
        setError("Error initializing Aztec account.");
        setIsLoading(false);
      }
    };

    initializeAztecAccount();
  }, []);

  const deployTokenContract = async (wallet: AccountWallet) => {
    if (!wallet) {
      setError("Wallet is required to deploy contracts.");
      console.error("Wallet is required to deploy contracts.");
      return;
    }

    setError(null);

    try {
      const address = await wallet.getAddress();

      const tokenContract = await Contract.deploy(
        wallet,
        TokenContractArtifact,
        [
          address,
          "TestToken0000000000000000000000",
          "TT00000000000000000000000000000",
          18,
        ],
        "constructor"
      )
        .send()
        .deployed();

      const playerTokenInstance = await TokenContract.at(tokenContract.address, wallet);

      const blackjackContract = await Contract.deploy(
        wallet,
        BlackJackContractArtifact,
        [],
        "constructor"
      )
        .send()
        .deployed();

      const playerBlackJackInstance = await BlackJackContract.at(
        blackjackContract.address,
        wallet
      );

      console.log("Token contract deployed at:", tokenContract.address);
      console.log("Blackjack contract deployed at:", blackjackContract.address);

      setTokenAddress(tokenContract.address.toString());
      setTokenInstance(playerTokenInstance);
      setBlackjackAddress(blackjackContract.address.toString());
      setBlackjackInstance(playerBlackJackInstance);
    } catch (err) {
      console.error("Error deploying contracts:", err);
      setError("Failed to deploy contracts. Please try again.");
    }
  };

  return (
    <AztecAccountContext.Provider
      value={{
        wallet,
        tokenAddress,
        blackjackAddress,
        tokenInstance,
        blackjackInstance,
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
    throw new Error("useAztecAccount must be used within an AztecAccountProvider");
  }
  return context;
};
