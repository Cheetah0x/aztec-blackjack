import * as React from "react";
import { useEffect, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Button } from "../components/ui/button";
import { Card, CardContent } from "../components/ui/card";
import { PinIcon as Chip, DollarSign } from "lucide-react";
import ConnectAccountPopup from "../components/ConnectAccountPopup";
import { useAztecAccount } from "../contexts/AztecAccountContext";
import { AztecAddress } from "@aztec/aztec.js";

const suits = ["♠", "♥", "♦", "♣"];
const values = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"];

function getRandomCard() {
  const suit = suits[Math.floor(Math.random() * suits.length)];
  const value = values[Math.floor(Math.random() * values.length)];
  return { suit, value };
}

interface Card {
  suit: string;
  value: string;
  hidden?: boolean;
}

export default function BlackjackGame() {
  const {
    tokenInstance,
    blackjackInstance,
    tokenAddress,
    blackjackAddress,
    deployTokenContract,
    isLoading,
  } = useAztecAccount();

  const [wallet, setWallet] = useState<any>(null);
  const [playerHand, setPlayerHand] = useState<Card[]>([]);
  const [dealerHand, setDealerHand] = useState<Card[]>([]);
  const [gameState, setGameState] = useState("idle");
  const [bet, setBet] = useState(0);
  const [playerPrivateBalance, setPlayerPrivateBalance] = useState<bigint | null>(null);
  const [playerPublicBalance, setPlayerPublicBalance] = useState<bigint | null>(null);
  const [contractPublicBalance, setContractPublicBalance] = useState<bigint | null>(null);
  const [isPopupOpen, setIsPopupOpen] = useState(false);
  const [secret, setSecret] = useState<string | null>(null);

  const handleSecretGenerated = (secret: string) => {
    setSecret(secret);
    setIsPopupOpen(false);
  };

  const initializeWallet = async () => {
    if (!wallet) {
      console.log("Initializing wallet...");
      try {
        const walletResult = await deployTokenContract(wallet); // Initialize wallet via Aztec
        setWallet(walletResult);
        console.log("Wallet initialized:", walletResult);
      } catch (err) {
        console.error("Error initializing wallet:", err);
      }
    }
  };

  useEffect(() => {
    if (!secret) {
      setIsPopupOpen(true);
    } else {
      initializeWallet();
    }
  }, [secret]);

  const deployContracts = async (wallet: any) => {
    if (wallet) {
      await deployTokenContract(wallet);
    }
  };

  const updateBalances = async () => {
    if (!tokenInstance || !wallet) return;

    try {
      const player = await wallet.getAddress();

      const privateBalance = await tokenInstance.methods.balance_of_private(player).simulate();
      setPlayerPrivateBalance(privateBalance);

      const publicBalance = await tokenInstance.methods.balance_of_public(player).simulate();
      setPlayerPublicBalance(publicBalance);

      if (blackjackAddress) {
        const contractBalance = await tokenInstance.methods
          .balance_of_public(AztecAddress.fromString(blackjackAddress))
          .simulate();
        setContractPublicBalance(contractBalance);
      }
    } catch (err) {
      console.error("Error fetching balances:", err);
    }
  };

  const mintTokens = async () => {
    if (tokenInstance && wallet) {
      try {
        console.log("Minting tokens...");
        const player = await wallet.getAddress();
        const mintTx = await tokenInstance.methods.mint_to_private(player, 1000).send().wait();
        const mintPubTx = await tokenInstance.methods.mint_public(player, 1000).send().wait();
        console.log("Minted 1000 tokens to player:", mintTx);
        console.log("Minted 1000 tokens to player:", mintPubTx);
        await updateBalances();
      } catch (err) {
        console.error("Error minting tokens:", err);
      }
    }
  };

  const placeBet = async () => {
    if (!tokenInstance || !wallet || !blackjackAddress || bet <= 0) return;

    try {
      const player = await wallet.getAddress();
      const transferTx = await tokenInstance.methods
        .transfer_public(player, AztecAddress.fromString(blackjackAddress), bet, 0)
        .send()
        .wait();
      console.log(`Transferred ${bet} tokens to blackjack contract:`, transferTx);
      await updateBalances();
    } catch (err) {
      console.error("Error placing bet:", err);
    }
  };

  const dealCards = () => {
    if (bet <= 0 || contractPublicBalance === null || contractPublicBalance < bet) return;

    setPlayerHand([getRandomCard(), getRandomCard()]);
    setDealerHand([getRandomCard(), { ...getRandomCard(), hidden: true }]);
    setGameState("playing");
  };

  const hit = () => {
    setPlayerHand([...playerHand, getRandomCard()]);
  };

  const stand = () => {
    setDealerHand(dealerHand.map((card) => ({ ...card, hidden: false })));
    setGameState("ended");
  };

  const renderCard = (card: Card, index: number, isDealer = false) => (
    <motion.div
      key={`${card.suit}${card.value}${index}`}
      initial={{ opacity: 0, scale: 0.8, y: -50 }}
      animate={{ opacity: 1, scale: 1, y: 0 }}
      exit={{ opacity: 0, scale: 0.8, y: 50 }}
      transition={{ duration: 0.3 }}
      className={`absolute ${
        card.hidden
          ? "bg-primary text-primary-foreground"
          : "bg-background text-foreground"
      } w-16 h-24 rounded-lg shadow-lg flex items-center justify-center text-2xl font-bold border-2 border-border`}
      style={{ left: `${index * 30}px` }}
    >
      {card.hidden ? "?" : `${card.value}${card.suit}`}
    </motion.div>
  );

  return (
    <div className="min-h-screen bg-green-800 flex flex-col items-center justify-center p-4">
      <ConnectAccountPopup
        isOpen={isPopupOpen}
        onClose={() => setIsPopupOpen(false)}
        onWalletGenerated={setWallet}
        onSecretGenerated={(secret) => console.log("Secret generated:", secret)}
      />
            {tokenAddress ? (
        <div>
          <h2 className="text-white text-xl">Token Deployed</h2>
          <p className="text-white">Token Address: {tokenAddress}</p>
          <p className="text-white">Blackjack Address: {blackjackAddress}</p>
          <h2 className="text-white text-xl">Token Address: {tokenAddress}</h2>
          <h2 className="text-white text-xl">Blackjack Address: {blackjackAddress}</h2>
          <div className="text-white mt-4">
            <p>Private Balance: {playerPrivateBalance?.toString() || "N/A"}</p>
            <p>Public Balance: {playerPublicBalance?.toString() || "N/A"}</p>
            <p>Contract Balance: {contractPublicBalance?.toString() || "N/A"}</p>
          </div>
          <Button onClick={mintTokens} className="bg-yellow-500 text-black px-4 py-2 rounded mt-4">
            Mint Tokens
          </Button>
          <Button
            onClick={placeBet}
            className="bg-blue-500 text-white px-4 py-2 rounded mt-4"
            disabled={bet <= 0 || !blackjackAddress}
          >
            Place Bet ({bet})
          </Button>
        </div>
      ) : (
        <Button
          onClick={() => deployContracts(wallet)}
          disabled={isLoading}
          className="bg-blue-500 text-white px-4 py-2 rounded"
        >
          {isLoading ? "Deploying..." : "Deploy Token & Blackjack"}
        </Button>
      )}

      <Card className="w-full max-w-2xl bg-green-700 shadow-xl">
        <CardContent className="p-6">
          <div className="mb-8">
            <h2 className="text-2xl font-bold mb-2 text-white">Dealer</h2>
            <div className="h-32 relative">
              <AnimatePresence>
                {dealerHand.map((card, index) => renderCard(card, index, true))}
              </AnimatePresence>
            </div>
          </div>

          <div className="mb-8">
            <h2 className="text-2xl font-bold mb-2 text-white">Player</h2>
            <div className="h-32 relative">
              <AnimatePresence>
                {playerHand.map((card, index) => renderCard(card, index))}
              </AnimatePresence>
            </div>
          </div>

          <div className="flex justify-between items-center">
            <div className="flex space-x-2">
              <Button onClick={dealCards} disabled={bet <= 0 || gameState !== "idle"}>
                Deal
              </Button>
              <Button onClick={hit} disabled={gameState !== "playing"}>
                Hit
              </Button>
              <Button onClick={stand} disabled={gameState !== "playing"}>
                Stand
              </Button>
            </div>
            <div className="flex items-center space-x-2">
              <Button
                variant="outline"
                size="icon"
                onClick={() => setBet(Math.max(0, bet - 5))}
                disabled={gameState !== "idle"}
              >
                <Chip className="h-4 w-4" />
              </Button>
              <div className="bg-yellow-400 text-yellow-900 px-3 py-1 rounded-full font-bold flex items-center">
                <DollarSign className="h-4 w-4 mr-1" />
                {bet}
              </div>
              <Button
                variant="outline"
                size="icon"
                onClick={() => setBet(bet + 5)}
                disabled={gameState !== "idle"}
              >
                <Chip className="h-4 w-4" />
              </Button>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
