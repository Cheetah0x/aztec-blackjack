import React, { useEffect } from "react";
import { Button } from "../components/ui/button";
import Popup from "../components/layouts/Popup";
import { deployerEnv } from "../config"; // Adjust path to your config
import { AccountWallet } from "@aztec/aztec.js";

interface ConnectAccountPopupProps {
  isOpen: boolean;
  onClose: () => void;
  onWalletGenerated: (wallet: AccountWallet) => void;
}

const ConnectAccountPopup: React.FC<ConnectAccountPopupProps> = ({
  isOpen,
  onClose,
  onWalletGenerated,
}) => {
  useEffect(() => {
    const createAztecWallet = async () => {
      try {
        console.log("Creating a new Aztec wallet...");
        const { wallet } = await deployerEnv.createNewWallet();
        console.log("New wallet created:", wallet);
        if (onWalletGenerated) {
          onWalletGenerated(wallet);
        }
        onClose(); // Close the popup after wallet creation
      } catch (e) {
        console.error("Error creating wallet:", e);
        // Handle error as needed
      }
    };

    if (isOpen) {
      createAztecWallet();
    }
  }, [isOpen, onClose, onWalletGenerated]);

  return (
    <Popup isOpen={isOpen} onClose={onClose}>
      <h2 className="text-2xl font-bold font-mono mb-4">Creating Aztec Account...</h2>
      <p>Please wait while we set up your account.</p>
    </Popup>
  );
};

export default ConnectAccountPopup;




// import React, { useState, useCallback } from "react";
// import { WalletClient } from "viem";

// import { Button } from "../components/ui/button";
// import { Input } from "../components/ui/input";
// import Popup from "../components/layouts/Popup";

// import { useAztecAccount } from "../contexts/AztecAccountContext";
// import { connectMetaMask } from "../hooks/useEVMAccount";
// import { deployerEnv } from "../config"; // Adjust path to your PublicEnv class
// import { AccountWallet } from "@aztec/aztec.js";

// interface ConnectAccountPopupProps {
//   isOpen: boolean;
//   onClose: () => void;
//   onSecretGenerated: (secret: string) => void;
//   onWalletGenerated: (wallet: AccountWallet) => void;
// }

// const ConnectAccountPopup: React.FC<ConnectAccountPopupProps> = ({
//   isOpen,
//   onClose,
//   onSecretGenerated,
//   onWalletGenerated,
// }) => {
//   const { isConnected, connect, setEvmAccount, evmAccount } = useAztecAccount();
//   const [evmWalletClient, setEvmWalletClient] = useState<WalletClient | null>(
//     null
//   );
//   const [isLoadingConnect, setIsLoadingConnect] = useState(false);
//   const [isLoadingSignMessage, setIsLoadingSignMessage] = useState(false);
//   const [isLoadingWallet, setIsLoadingWallet] = useState(false);
//   const [messageToSign, setMessageToSign] = useState("");
//   const [error, setError] = useState<string | null>(null);
//   const [privateKey, setPrivateKey] = useState<string | null>(null);

//   const handleContinue = async () => {
//     console.log("Continuing with connected MetaMask account:", evmAccount);
//     if (onWalletGenerated && evmAccount) {
//       const wallet = await deployerEnv.createNewWallet();
//       onWalletGenerated(wallet.wallet);
//     }
//     onClose();
//   };


//   const handleCreateWallet = async () => {
//     setIsLoadingWallet(true);
//     console.log("Creating a new Aztec wallet...");
//     try {
//       const { wallet, privateKey } = await deployerEnv.createNewWallet();
//       console.log("New wallet created:", wallet);
//       setPrivateKey(privateKey);
//       console.log("Private key:", privateKey);
  
//       if (onWalletGenerated) {
//         onWalletGenerated(wallet);
//       }
//     } catch (e) {
//       console.error("Error creating wallet:", e);
//       setError("Failed to create Aztec wallet. Please try again.");
//     } finally {
//       setIsLoadingWallet(false);
//     }
//   };
  
//   // const handleConnectMetaMask = useCallback(async () => {
//   //   setIsLoadingConnect(true);
//   //   console.log("Connecting to MetaMask...");
//   //   try {
//   //     const { walletClient, account } = await connectMetaMask();
//   //     console.log("MetaMask connected. Wallet client:", walletClient);
//   //     console.log("Connected account:", account);
  
//   //     if (walletClient && account) {
//   //       setEvmWalletClient(walletClient);
//   //       setEvmAccount(account);
//   //       connect();
//   //     }
//   //   } catch (e) {
//   //     console.error("Error connecting to MetaMask:", e);
//   //     setError(
//   //       "Error connecting to MetaMask. Please make sure it's installed and unlocked."
//   //     );
//   //   } finally {
//   //     setIsLoadingConnect(false);
//   //   }
//   // }, [connect, setEvmAccount]);
  
  

//   const handleSignMessage = useCallback(async () => {
//     if (!evmWalletClient || !evmAccount || !messageToSign.trim()) return;

//     setIsLoadingSignMessage(true);
//     setError(null);

//     try {
//       const signed = await evmWalletClient.signMessage({
//         account: evmAccount,
//         message: messageToSign,
//       });

//       onSecretGenerated(signed);
//       onClose();
//     } catch (e) {
//       console.error("Error signing message", e);
//       setError("Error signing message. Please try again.");
//     } finally {
//       setIsLoadingSignMessage(false);
//     }
//   }, [evmWalletClient, evmAccount, messageToSign, onSecretGenerated, onClose]);

//   return (
//     <Popup isOpen={isOpen} onClose={onClose}>
//       <h2 className="text-2xl font-bold font-mono mb-4">Create an Aztec Account</h2>
//       {!isConnected ? (
//         <>
//           <p className="mb-4">
//             Connect your MetaMask wallet to proceed with creating or using an Aztec account.
//           </p>
//           <Button
//             onClick={handleConnectMetaMask}
//             disabled={isLoadingConnect}
//             className="w-full bg-[#4d4d4d] hover:bg-[#666666] text-[#f2f2f2] font-bold font-mono py-2 px-4 rounded-md"
//           >
//             {isLoadingConnect ? "Connecting..." : "Connect MetaMask"}
//           </Button>
//         </>
//       ) : (
//         <>
//           <p className="mb-4">You're connected to MetaMask. Choose an option below:</p>
//           <Button
//             onClick={handleCreateWallet}
//             disabled={isLoadingWallet}
//             className="w-full bg-[#4d4d4d] hover:bg-[#666666] text-[#f2f2f2] font-bold font-mono py-2 px-4 rounded-md"
//           >
//             {isLoadingWallet ? "Creating Wallet..." : "Create Aztec Wallet"}
//           </Button>
//           <Button
//             onClick={handleContinue}
//             className="w-full mt-4 bg-[#4d4d4d] hover:bg-[#666666] text-[#f2f2f2] font-bold font-mono py-2 px-4 rounded-md"
//           >
//             Continue with MetaMask
//           </Button>
//         </>
//       )}
//       {error && <p className="mt-4 text-red-500">{error}</p>}
//     </Popup>
//   );
// };


// export default ConnectAccountPopup;
