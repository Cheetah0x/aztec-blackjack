import {
  Fr,
  createPXEClient,
  deriveMasterIncomingViewingSecretKey,
} from "@aztec/aztec.js";
import { BlackJackContractArtifact } from "./circuits/src/artifacts/BlackJack";
import { AccountManager } from "@aztec/aztec.js/account";
import { SingleKeyAccountContract } from "@aztec/accounts/single_key";

export class PublicEnv {
  pxe;

  constructor(private pxeURL: string) {
    this.pxe = createPXEClient(this.pxeURL);
  }

  async createNewWallet() {
    console.log("Starting wallet creation...");
    const secretKey = Fr.random();
    console.log("Generated secret key:", secretKey.toString());

    const encryptionPrivateKey =
      deriveMasterIncomingViewingSecretKey(secretKey);
    console.log("Derived encryption private key:", encryptionPrivateKey);

    const accountContract = new SingleKeyAccountContract(encryptionPrivateKey);
    console.log("Created account contract for the wallet.");

    const account = new AccountManager(this.pxe, secretKey, accountContract);
    console.log("Initialized AccountManager.");

    const wallet = await account.register();
    console.log(
      `Wallet registration completed. Wallet address: ${await wallet.getAddress()}`
    );

    return { wallet, privateKey: secretKey.toString() };
  }
}

export const deployerEnv = new PublicEnv(
  process.env.PXE_URL || "http://localhost:8080"
);

const IGNORE_FUNCTIONS = [
  "constructor",
  "compute_note_hash_and_optionally_a_nullifier",
];
export const filteredInterface = BlackJackContractArtifact.functions.filter(
  (f) => !IGNORE_FUNCTIONS.includes(f.name)
);
