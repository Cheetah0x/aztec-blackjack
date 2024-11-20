import React from "react";
import { useAztecAccount } from "../contexts/AztecAccountContext";
import { AccountWallet } from "@aztec/aztec.js";

interface DeployTokenButtonProps {
    wallet: AccountWallet;
    onTokenDeployed: (tokenAddress: string) => void; 
  }

const DeployTokenButton: React.FC<DeployTokenButtonProps> = ({ wallet, onTokenDeployed }) => {
    const { deployTokenContract, isLoading, error } = useAztecAccount();
  
    const handleDeploy = async () => {
      console.log("Starting token deployment...");
      console.log("Using wallet:", wallet);
  
      try {
        const tokenAddress = await deployTokenContract(wallet);
        onTokenDeployed(tokenAddress?.toString() || "" );
        if (tokenAddress) {
          console.log("Token deployed at:", tokenAddress);
        } else {
          console.error("Token deployment failed.");
        }
      } catch (err) {
        console.error("Error during token deployment:", err);
      }
    };
  
    return (
      <div>
        <button
          onClick={handleDeploy}
          disabled={isLoading}
          className="bg-blue-500 text-white px-4 py-2 rounded"
        >
          {isLoading ? "Deploying..." : "Deploy Token"}
        </button>
        {error && <p className="text-red-500 mt-2">{error}</p>}
      </div>
    );
  };
  

export default DeployTokenButton;
