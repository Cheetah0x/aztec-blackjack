import * as React from "react";
import { useEffect, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Button } from "../components/ui/button";
import { Card, CardContent } from "../components/ui/card";
import { PinIcon as Chip, DollarSign } from "lucide-react";
import ConnectAccountPopup from "../components/ConnectAccountPopup";
import { useAztecAccount } from "../contexts/AztecAccountContext";
import { AztecAddress } from "@aztec/aztec.js";

const suitSymbols = ["♠", "♥", "♦", "♣"];
const rankSymbols: { [key: number]: string } = {
  1: "A",
  2: "2",
  3: "3",
  4: "4",
  5: "5",
  6: "6",
  7: "7",
  8: "8",
  9: "9",
  10: "10",
  11: "J",
  12: "Q",
  13: "K",
};

// function getRandomCard() {
//   const suit = suits[Math.floor(Math.random() * suits.length)];
//   const value = values[Math.floor(Math.random() * values.length)];
//   return { suit, value };
// }

interface Card {
  suit: string;
  value: string;
  hidden?: boolean;
}

interface CardData {
  rank: bigint;
  suit: bigint;
}

interface ProcessedCard {
  value: string;
  suit: string;
  hidden: boolean;
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
  const [playerPoints, setPlayerPoints] = useState(0);
  const [dealerPoints, setDealerPoints] = useState(0);
  const [isPlayerBust, setIsPlayerBust] = useState(false);
  const [isDealerBust, setIsDealerBust] = useState(false);
  const [isBlackjack, setIsBlackjack] = useState(false);

  const handleSecretGenerated = (secret: string) => {
    setSecret(secret);
    setIsPopupOpen(false);
  };

  useEffect(() => {
    if (gameState === "ended") {
      // Display game result to the player
      if (isPlayerBust) {
        alert("You busted! Dealer wins.");
      } else if (isDealerBust) {
        alert("Dealer busted! You win!");
      } else if (isBlackjack) {
        alert("Blackjack! You win!");
      } else {
        // Compare points to determine winner
        if (playerPoints > dealerPoints) {
          alert("You win!");
        } else if (playerPoints < dealerPoints) {
          alert("Dealer wins!");
        } else {
          alert("Push!");
        }
      }
    }
  }, [gameState]);
  

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
    if (tokenInstance && wallet && blackjackAddress) {
      try {
        console.log("Minting tokens...");
        const player = await wallet.getAddress();
        const mintTx = await tokenInstance.methods.mint_to_private(player, 1000).send().wait();
        const mintPubTx = await tokenInstance.methods.mint_public(player, 1000).send().wait();
        console.log("Minted 1000 tokens to player:", mintTx);
        console.log("Minted 1000 tokens to player:", mintPubTx);

        const sendContractpriv = await tokenInstance.methods.transfer(AztecAddress.fromString(blackjackAddress), 200).send().wait();
        console.log("Sent 200 tokens to blackjack contract:", sendContractpriv);
        const sendContractpub = await tokenInstance.methods.transfer_public(player, AztecAddress.fromString(blackjackAddress), 200, 0).send().wait();
        console.log("Sent 200 tokens to blackjack contract:", sendContractpub);
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

  // const dealCards = () => {
  //   if (bet <= 0 || contractPublicBalance === null || contractPublicBalance < bet) return;

  //   setPlayerHand([getRandomCard(), getRandomCard()]);
  //   setDealerHand([getRandomCard(), { ...getRandomCard(), hidden: true }]);
  //   setGameState("playing");
  // };

  const dealCards = async () => {
    if (bet <= 0 || contractPublicBalance === null || contractPublicBalance < bet) return;
  
    try {
      console.log("Dealing cards...");
      if (!blackjackInstance) return;
      const dealTx = await blackjackInstance.methods
        .begin_game()
        .send()
        .wait();
  
      console.log("Dealt cards:", dealTx);
  
      // Fetch player and dealer hands
      await updateHands();
  
      setGameState("playing");
    } catch (err) {
      console.error("Error dealing cards:", err);
    }
  };
  

  // const hit = () => {
  //   setPlayerHand([...playerHand, getRandomCard()]);
  // };
  const hit = async () => {
    try {
      if (!blackjackInstance) return;
      console.log("Player hits...");
      const hitTx = await blackjackInstance.methods
        .player_hit()
        .send()
        .wait();
  
      console.log("Player hit:", hitTx);
  
      await updateHands();
    } catch (err) {
      console.error("Error hitting:", err);
    }
  };
  

  // const stand = () => {
  //   setDealerHand(dealerHand.map((card) => ({ ...card, hidden: false })));
  //   setGameState("ended");
  // };
  const stand = async () => {
    try {
      if (!blackjackInstance) return;
      console.log("Player stands...");
      const standTx = await blackjackInstance.methods
        .player_stand()
        .send()
        .wait();
  
      console.log("Player stand:", standTx);
  
      await updateHands();
  
      setGameState("ended");
    } catch (err) {
      console.error("Error standing:", err);
    }
  };

  function processHandData(handRaw: CardData[]): ProcessedCard[] {
    // Filter out cards where both rank and suit are zero
    const filteredHand = handRaw.filter(
      (card: CardData) => !(card.rank === 0n && card.suit === 0n)
    );
  
    const processedHand = filteredHand.map((card: CardData) => {
      const rankNumber = Number(card.rank);
      const suitNumber = Number(card.suit);
      const rank = rankSymbols[rankNumber];
      const suit = suitSymbols[suitNumber];
      return {
        value: rank,
        suit: suit,
        hidden: false,
      };
    });
  
    return processedHand;
  }
  
  
  

  const updateHands = async () => {
    if (!blackjackInstance || !wallet) return;
  
    try {
      const player = await wallet.getAddress();
  
      // Get player's points
      const playerPointsValue = await blackjackInstance.methods
        .player_points(player)
        .simulate();
      setPlayerPoints(Number(playerPointsValue));
  
      // Get dealer's points
      const dealerPointsValue = await blackjackInstance.methods
        .dealer_points()
        .simulate();
      setDealerPoints(Number(dealerPointsValue));
  
      // Get player's bust status
      const isPlayerBustValue = await blackjackInstance.methods
        .is_player_bust_view()
        .simulate();
      setIsPlayerBust(isPlayerBustValue);
  
      // Get dealer's bust status
      const isDealerBustValue = await blackjackInstance.methods
        .is_dealer_bust_view()
        .simulate();
      setIsDealerBust(isDealerBustValue);
  
      // Get if blackjack
      const isBlackjackValue = await blackjackInstance.methods
        .is_blackjack_view()
        .simulate();
      setIsBlackjack(isBlackjackValue);
  
      // Fetch player's hand
      const playerHandRaw: CardData[] = await blackjackInstance.methods
        .player_hand(player)
        .simulate();
      const playerHandProcessed = processHandData(playerHandRaw);
      setPlayerHand(playerHandProcessed);
  
      // Fetch dealer's hand
      const dealerHandRaw: CardData[] = await blackjackInstance.methods
        .dealer_hand()
        .simulate();
      const dealerHandProcessed = processHandData(dealerHandRaw);
  
      // Hide dealer's first card if the game is in 'playing' state
      if (gameState === "playing" && dealerHandProcessed.length > 0) {
        dealerHandProcessed[0].hidden = true;
      }
      setDealerHand(dealerHandProcessed);
  
      // Handle game state transitions
      if (isPlayerBustValue || isDealerBustValue || isBlackjackValue) {
        setGameState("ended");
      }
    } catch (err) {
      console.error("Error updating hands:", err);
    }
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
          : "bg-white text-black"
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
