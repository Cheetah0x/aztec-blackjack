import {
  AccountWallet,
  CompleteAddress,
  createDebugLogger,
  Contract,
  PXE,
  DebugLogger,
  AztecAddress,
  ContractInstanceWithAddress,
} from "@aztec/aztec.js";
import {
  BlackJackContractArtifact,
  BlackJackContract,
} from "../blackjack/src/artifacts/BlackJack";
import { setupSandbox, createAccount } from "./utils";

describe("BlackJack", () => {
  let pxe: PXE;
  let playerWallet: AccountWallet;
  let player: AztecAddress;
  let blackjackContract: Contract;
  let playerInstance: BlackJackContract;
  let blackJackAddress: AztecAddress;

  beforeAll(async () => {
    pxe = await setupSandbox();
    playerWallet = await createAccount(pxe);
    player = playerWallet.getAddress();

    blackjackContract = await Contract.deploy(
      playerWallet,
      BlackJackContractArtifact,
      [player],
      "constructor"
    )
      .send()
      .deployed();

    blackJackAddress = blackjackContract.address;
    console.log("Blackjack contract deployed at", blackjackContract.address);

    //playerinstance
    playerInstance = await BlackJackContract.at(blackJackAddress, playerWallet);
    console.log("Player instance created at");
  }, 30000);

  it("should play a game", async () => {
    // const result = await playerInstance.methods.play_game(player);
    // console.log("Game result:", result);

    const gameState = await playerInstance.methods
      .begin_game(player)
      .send()
      .wait();
    console.log("Game state:", gameState);

    const dealerHand = await playerInstance.methods.dealer_hand().simulate();
    console.log("Dealer hand:", dealerHand);

    const playerHand = await playerInstance.methods
      .player_hand(player)
      .simulate();
    console.log("Player hand:", playerHand);
  });

  afterAll(async () => {
    if (pxe) {
    }
  });
});
