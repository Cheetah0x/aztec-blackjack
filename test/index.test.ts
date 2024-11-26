import {
  AccountWallet,
  CompleteAddress,
  createDebugLogger,
  Contract,
  PXE,
  DebugLogger,
  AztecAddress,
  ContractInstanceWithAddress,
  computeAuthWitMessageHash,
  computeInnerAuthWitHash,
} from "@aztec/aztec.js";
import {
  BlackJackContractArtifact,
  BlackJackContract,
} from "../src/circuits/src/artifacts/BlackJack";
import {
  TokenContractArtifact,
  TokenContract,
} from "../src/circuits/src/artifacts/Token";
import { setupSandbox, createAccount, retryWithDelay } from "./utils";

describe("BlackJack Priv", () => {
  let pxe: PXE;
  let playerWallet: AccountWallet;
  let player: AztecAddress;
  let blackjackContract: Contract;
  let playerBlackJackInstance: BlackJackContract;
  let blackJackAddress: AztecAddress;
  let tokenContract: Contract;
  let tokenAddress: AztecAddress;
  let playerTokenInstance: TokenContract;
  let blackJackTokenInstance: TokenContract;

  beforeAll(async () => {
    pxe = await setupSandbox();
    playerWallet = await createAccount(pxe);
    player = playerWallet.getAddress();

    blackjackContract = await Contract.deploy(
      playerWallet,
      BlackJackContractArtifact,
      [],
      "constructor"
    )
      .send()
      .deployed();

    blackJackAddress = blackjackContract.address;
    console.log("Blackjack contract deployed at", blackJackAddress);

    //player instance
    playerBlackJackInstance = await BlackJackContract.at(
      blackJackAddress,
      playerWallet
    );
    console.log("Player instance created at");

    //now deploy the token contract
    tokenContract = await Contract.deploy(
      playerWallet,
      TokenContractArtifact,
      [
        player,
        "TestToken0000000000000000000000",
        "TT00000000000000000000000000000",
        18,
      ],
      "constructor"
    )
      .send()
      .deployed();

    tokenAddress = tokenContract.address;
    console.log("Token contract deployed at", tokenAddress);

    //player token instance
    playerTokenInstance = await TokenContract.at(tokenAddress, playerWallet);
    console.log("Player token instance created at");

    //need to leave this to later.
    //also need to figure out how to send token to contract.
    // const blackJackWallet = await
    // blackJackTokenInstance = await TokenContract.at(
    //   tokenAddress,
    //   blackJackAddress
    // );
    console.log("Blackjack token instance created at");
  }, 30000);

  //--------------------------CHECKING TOKEN CONTRACT WORKING-------------------

  // it("check the admin of the token", async () => {
  //   //see if it can fetch the admin
  //   const admin = await playerTokenInstance.methods.get_admin().simulate();
  //   expect(admin).toEqual(player);
  // });

  it("mint to the player", async () => {
    const mintpriv = await playerTokenInstance.methods
      .mint_to_private(player, 1000)
      .send()
      .wait();
    console.log("Minted to the player", mintpriv);

    const mintpub = await playerTokenInstance.methods
      .mint_public(player, 500)
      .send()
      .wait();
    console.log("Minted to the player", mintpub);

    const balancepriv = await playerTokenInstance.methods
      .balance_of_private(player)
      .simulate();
    console.log("Balance of the player", balancepriv);
    expect(balancepriv).toEqual(1000n);

    const balancepub = await playerTokenInstance.methods
      .balance_of_public(player)
      .simulate();
    console.log("Balance of the player", balancepub);
    expect(balancepub).toEqual(500n);
  });

  it("sends some token to blackjack contract", async () => {
    //sending some to the contract so it can pay out bets

    const sendContractpriv = await playerTokenInstance.methods
      .transfer(blackJackAddress, 200)
      .send()
      .wait();
    console.log("Sent to the contract", sendContractpriv);
    console.log("tokenaddress", tokenAddress);
    console.log("playerAddress", player);

    const sendContractpub = await playerTokenInstance.methods
      .transfer_public(player, blackJackAddress, 200, 0)
      .send()
      .wait();
    console.log("Sent to the contract", sendContractpub);

    //private balance is unconstrained, anyone can see it??
    // const contractBalance = await playerTokenInstance.methods
    //   .balance_of_private(blackJackAddress)
    //   .simulate();
    // console.log("Contract balance", contractBalance);
    // expect(contractBalance).toEqual(200n);

    //can assume that the private transfer worked too.

    //public balance of the contract
    const contractBalancePub = await playerTokenInstance.methods
      .balance_of_public(blackJackAddress)
      .simulate();
    console.log("Contract balance", contractBalancePub);

    expect(contractBalancePub).toEqual(200n);
  });

  //this does not work
  // it("send tokens to the player", async () => {
  //   await playerBlackJackInstance.methods
  //     .send_tokens_to_player(tokenAddress)
  //     .send()
  //     .wait();

  //   const balance = await playerTokenInstance.methods
  //     .balance_of_private(player)
  //     .simulate();
  //   console.log("Balance of the player", balance);
  // });

  //--------------------------CHECKING BLACKJACK CONTRACT WORKING-------------------

  //see if we can make a bet
  it("make a bet", async () => {
    const tokenAddressCheck = await playerBlackJackInstance.methods
      .contract_address()
      .simulate();
    console.log("contractaddress", tokenAddressCheck);

    //hopefully this helps to fix that issue
    // const action = playerTokenInstance.methods
    //   .transfer_from(player, tokenAddress, 100, 0)
    //   .request();

    // const authWitness = await playerWallet.createAuthWit({
    //   caller: blackJackAddress,
    //   action,
    // });

    // await playerWallet.addAuthWitness(authWitness);
    // // await pxe.addAuthWitness(authWitness);

    //none of the authwit stuff here is working, will somehow have to constrain the function to only take
    //place if a bet is made. not sure how this can be checked atm.

    const bet = await playerBlackJackInstance.methods
      .make_bet(100, tokenAddress)
      .send()
      .wait();
    console.log("Bet made", bet);
  });

  //-----------------------------WITHOUT MAKING BET----------------------
  it("beigns the game", async () => {
    await playerBlackJackInstance.methods.begin_game().send().wait();

    //check the cards in the deck
    let player_cards = await playerBlackJackInstance.methods
      .player_points()
      .simulate();

    const dealer_cards = await playerBlackJackInstance.methods
      .dealer_points()
      .simulate();

    console.log("Player cards", player_cards);
    console.log("Dealer cards", dealer_cards);

    //get the hands
    const player_hand = await playerBlackJackInstance.methods
      .player_hand()
      .simulate();
    console.log("Player hand", player_hand);

    const dealer_hand = await playerBlackJackInstance.methods
      .dealer_hand()
      .simulate();
    console.log("Dealer hand", dealer_hand);
  });

  it("check if blackjack", async () => {
    const blackjack = await playerBlackJackInstance.methods
      .is_blackjack_view()
      .simulate();
    console.log("Is blackjack?", blackjack);
  });

  it("player hits", async () => {
    // while (player_cards > 16) {
    await playerBlackJackInstance.methods.player_hit().send().wait();

    let player_cards = await playerBlackJackInstance.methods
      .player_points()
      .simulate();
    console.log("Player cards", player_cards);

    //check if the player has bust
    const is_bust = await playerBlackJackInstance.methods
      .is_player_bust_view()
      .simulate();
    console.log("Is the player bust?", is_bust);

    //get the hands
    const player_hand = await playerBlackJackInstance.methods
      .player_hand()
      .simulate();
    console.log("Player hand", player_hand);

    const dealer_hand = await playerBlackJackInstance.methods
      .dealer_hand()
      .simulate();
    console.log("Dealer hand", dealer_hand);
    // }
  });

  it("player stands", async () => {
    //now stand
    // await retryWithDelay(async () => {
    const receipt = await playerBlackJackInstance.methods.player_stand().send();
    console.log(receipt);
    // });

    //check the totals
    const player_total = await playerBlackJackInstance.methods
      .player_points()
      .simulate();
    console.log("Player total", player_total);

    const dealer_total = await playerBlackJackInstance.methods
      .dealer_points()
      .simulate();
    console.log("Dealer total", dealer_total);

    //get the hands
    const player_hand = await playerBlackJackInstance.methods
      .player_hand()
      .simulate();
    console.log("Player hand", player_hand);

    const dealer_hand = await playerBlackJackInstance.methods
      .dealer_hand()
      .simulate();
    console.log("Dealer hand", dealer_hand);
  }, 100000);

  it("reset the game", async () => {
    await playerBlackJackInstance.methods.reset_game().send().wait();

    //check the player hand is empty
    const player_hand = await playerBlackJackInstance.methods
      .player_hand()
      .simulate();
    console.log("Player hand", player_hand);

    const dealer_hand = await playerBlackJackInstance.methods
      .dealer_hand()
      .simulate();
    console.log("Dealer hand", dealer_hand);

    expect(player_hand && dealer_hand).toEqual([
      { rank: 0n, suit: 0n },
      { rank: 0n, suit: 0n },
      { rank: 0n, suit: 0n },
      { rank: 0n, suit: 0n },
      { rank: 0n, suit: 0n },
      { rank: 0n, suit: 0n },
      { rank: 0n, suit: 0n },
      { rank: 0n, suit: 0n },
    ]);
  });
});
