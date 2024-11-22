import {
  AztecAddress,
  createPXEClient,
  deriveMasterIncomingViewingSecretKey,
  Fr,
  GrumpkinScalar,
  PXE,
  Schnorr,
} from "@aztec/aztec.js";
import { SingleKeyAccountContract } from "@aztec/accounts/single_key";
import { AccountManager, AccountWalletWithSecretKey } from "@aztec/aztec.js";

import { waitForPXE } from "@aztec/aztec.js";

export const setupSandbox = async () => {
  const { PXE_URL = "http://localhost:8080" } = process.env;
  const pxe = createPXEClient(PXE_URL);
  await waitForPXE(pxe);
  return pxe;
};

export const createAccount = async (pxe: PXE) => {
  // Generate a new secret key for each wallet
  const secretKey = Fr.random();
  const encryptionPrivateKey = deriveMasterIncomingViewingSecretKey(secretKey);
  const accountContract = new SingleKeyAccountContract(encryptionPrivateKey);

  // Create a new AccountManager instance
  const account = new AccountManager(pxe, secretKey, accountContract);

  // Register the account and get the wallet
  const wallet = await account.register(); // Returns AccountWalletWithSecretKey
  return wallet;
};

export function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
export async function retryWithDelay(
  fn: () => Promise<any>,
  maxRetries: number = 10,
  delayMs: number = 3000
): Promise<any> {
  let attempt = 0;

  // Retry the function until it succeeds or the max number of attempts is reached.
  while (attempt < maxRetries) {
    try {
      return await fn(); // Attempt to execute the function.
    } catch (error) {
      console.log(`Attempt ${attempt + 1} failed. Retrying...`);
      attempt++;
      await delay(delayMs); // Wait before the next attempt.
    }
  }

  // Throw an error if the function failed after max retries.
  throw new Error(`Failed after ${maxRetries} attempts`);
}
