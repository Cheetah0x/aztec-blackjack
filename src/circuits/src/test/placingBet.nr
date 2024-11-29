use crate::BlackJack;
use crate::notes::CardNote::{Card, CardNote, Deck};
use dep::address_note::address_note::AddressNote;
use dep::aztec::note::note_getter::view_notes;
use dep::aztec::note::note_viewer_options::NoteViewerOptions;
use dep::aztec::{
    oracle::random::random, prelude::{AztecAddress, NoteHeader},
    protocol_types::storage::map::derive_storage_slot_in_map,
    test::helpers::{cheatcodes, test_environment::TestEnvironment},
};
use dep::std::println;
// use crate::test::utilsPriv::{setupPriv, tokenSetup};
use crate::test::utilsPriv::setupPriv;
use dep::token::Token;
use dep::uint_note::uint_note::UintNote;
use std::test::OracleMock;

//test the minting tokens and stuff
#[test]
unconstrained fn mintingTokens() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    let note_randomness = random();
    let _ = OracleMock::mock("getRandomField").returns(note_randomness);
    let amount = 1000;

    // Token::at(token_address).mint_to_private(player, amount).call(&mut env.private());
    let balances_owner_slot =
        derive_storage_slot_in_map(Token::storage_layout().balances.slot, player);

    env.add_note(
        &mut UintNote {
            value: U128::from_integer(amount),
            owner: player,
            randomness: note_randomness,
            header: NoteHeader::empty(),
        },
        balances_owner_slot,
        token_address,
    );

    env.advance_block_by(1);

    let balance_field = Token::balance_of_private(player);
    let balance = balance_field as u64;
    println(f"balance: {balance}");
    //not sure why this is not working tbh, may just go for the aztecjs testing now.
}

//in the real world we will assume that the token is already deployed,
//here we will have to deploy it first

#[test]
unconstrained fn placingBet() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    println(f"player {player}");
    println(f"blackjack_contract {blackjack_contract}");

    // check the users balance of the token
    env.impersonate(token_address);
    let unconstrained_context = env.unkonstrained();
    let storage = Token::Storage::init(unconstrained_context);
    let balance = storage.balances.at(player).balance_of();
    println(f"balance: {balance}");
    //will do it the hardway
    println(f"balance: {balance}");
    //now we can make the bet
    env.impersonate(player);
    BlackJack::at(blackjack_contract).make_bet(10, token_address).call(&mut env.private());

    //begin the game
    BlackJack::at(blackjack_contract).begin_game().call(&mut env.private());
    // println("bet made");
    env.advance_block_by(1);
    //get the balance of the contract
}

#[test]
unconstrained fn fetchbet() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //make a bet
    env.impersonate(player);
    BlackJack::at(blackjack_contract).make_bet(10, token_address).call(&mut env.private());

    env.advance_block_by(1);

    let bet = BlackJack::at(blackjack_contract).get_bet().view(&mut env.private());
    println(f"bet: {bet}");

    assert(bet == 10, "Bet is not 10");
}

// TODO:: ISSUE, the current token contract is too big for the tests, this is the error that i get
// something about the max size being 3000, and it is like 3500

#[test(should_fail)]
unconstrained fn multipleBets() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //make a bet
    env.impersonate(player);
    BlackJack::at(blackjack_contract).make_bet(10, token_address).call(&mut env.private());

    env.advance_block_by(1);

    //make another bet
    BlackJack::at(blackjack_contract).make_bet(10, token_address).call(&mut env.private());

    env.advance_block_by(1);
}

#[test(should_fail)]
unconstrained fn betTooLow() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //make a bet
    env.impersonate(player);
    BlackJack::at(blackjack_contract).make_bet(5, token_address).call(&mut env.private());

    env.advance_block_by(1);
}

#[test(should_fail)]
unconstrained fn betTooHigh() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //make a bet
    env.impersonate(player);
    BlackJack::at(blackjack_contract).make_bet(101, token_address).call(&mut env.private());

    env.advance_block_by(1);
}

#[test(should_fail)]
unconstrained fn bet_start_bet() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //make a bet
    env.impersonate(player);
    BlackJack::at(blackjack_contract).make_bet(10, token_address).call(&mut env.private());

    env.advance_block_by(1);

    //begin the game
    BlackJack::at(blackjack_contract).begin_game().call(&mut env.private());

    env.advance_block_by(1);

    //make another bet
    env.impersonate(player);
    BlackJack::at(blackjack_contract).make_bet(10, token_address).call(&mut env.private());

    env.advance_block_by(1);
}

//bet with another token when bet is already made
#[test(should_fail)]
unconstrained fn bet_other_token() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //make a bet
    env.impersonate(player);
    BlackJack::at(blackjack_contract).make_bet(10, token_address).call(&mut env.private());

    env.advance_block_by(1);

    //make another bet with another token
    //deploy another token
    let initializer_call_interface = Token::interface().constructor(
        player,
        "TestToken0000000000000000000001",
        "TT00000000000000000000000000001",
        18,
    );

    let token_contract_2 =
        env.deploy_self("Token").with_public_void_initializer(initializer_call_interface);
    let token_address_2 = token_contract_2.to_address();

    //make a bet with the new token
    env.impersonate(player);
    BlackJack::at(blackjack_contract).make_bet(10, token_address_2).call(&mut env.private());
}
