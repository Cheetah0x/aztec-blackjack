use crate::BlackJack;
use crate::notes::CardNote::{Card, CardNote, Deck};
use crate::test::utilsPriv::{
    setupPriv, tokenSetup, add_card_note_dealer, check_bet, check_split_bet,
};
use dep::address_note::address_note::AddressNote;
use dep::aztec::note::note_getter::view_notes;
use dep::aztec::note::note_viewer_options::NoteViewerOptions;
use dep::aztec::{
    oracle::{
        execution::{get_block_number, get_contract_address}, random::random, storage::storage_read,
    }, prelude::{AztecAddress, NoteHeader},
    protocol_types::storage::map::derive_storage_slot_in_map,
    test::helpers::{cheatcodes, test_environment::TestEnvironment},
};
use dep::std::println;
use dep::token::Token;
use dep::uint_note::uint_note::UintNote;
use std::test::OracleMock;

#[test]
unconstrained fn insurance() {
    //happy path
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //make a bet
    println("checkpoint 1");
    env.impersonate(player);
    BlackJack::at(blackjack_contract).make_bet(10, token_address).call(&mut env.private());
    println("checkpoint 2");

    //this should work, just dont know how to use the cheat code properly
    // //begin game
    // env.impersonate(player);
    // BlackJack::at(blackjack_contract).begin_game().call(&mut env.private());
    // //set game state to active
    env.impersonate(blackjack_contract);
    game_state(env, blackjack_contract, player, 1);
    env.advance_block_by(10);
    //include the ace in the dealers hand
    add_card_note_dealer(env, blackjack_contract, player, 1, 0);

    env.impersonate(blackjack_contract);
    let unconstrained_context = env.unkonstrained();
    let storage = BlackJack::Storage::init(unconstrained_context);
    let game_state = storage.game_state.at(player).get_current_value() as u64;
    println(f"game state: {game_state}");

    //player buys insurance
    env.impersonate(player);
    BlackJack::at(blackjack_contract).place_insurance_bet().call(&mut env.private());

    //check that the insurance bet was made
    env.impersonate(blackjack_contract);
    let insurance_bet = storage.insurance.at(player).view_note().value as u64;
    assert(insurance_bet == 5, "Insurance bet is not half of the original bet");
}

#[test(should_fail)]
unconstrained fn insurance_fails_if_no_ace() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //make a bet
    env.impersonate(player);
    BlackJack::at(blackjack_contract).make_bet(10, token_address).call(&mut env.private());

    //include a non-ace card in the dealers hand
    add_card_note_dealer(env, blackjack_contract, player, 2, 0);

    //check that the insurance bet fails
    BlackJack::at(blackjack_contract).place_insurance_bet().call(&mut env.private());
}

#[test(should_fail)]
unconstrained fn insurance_no_bet() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //player buys insurance
    BlackJack::at(blackjack_contract).place_insurance_bet().call(&mut env.private());
}

#[test(should_fail)]
unconstrained fn insurance_ace_no_bet() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //include a ace card in the dealers hand
    add_card_note_dealer(env, blackjack_contract, player, 1, 0);

    //player buys insurance
    BlackJack::at(blackjack_contract).place_insurance_bet().call(&mut env.private());
}

#[test(should_fail)]
unconstrained fn insurance_multiple_dealer_cards() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //include multiple cards in the dealers hand
    add_card_note_dealer(env, blackjack_contract, player, 1, 0);
    add_card_note_dealer(env, blackjack_contract, player, 2, 0);

    //player makes bet
    env.impersonate(player);
    BlackJack::at(blackjack_contract).make_bet(10, token_address).call(&mut env.private());

    //player buys insurance
    BlackJack::at(blackjack_contract).place_insurance_bet().call(&mut env.private());
}

#[test(should_fail)]
unconstrained fn insurance_multiple_dealer_cards_ace_2() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //make a bet
    env.impersonate(player);
    BlackJack::at(blackjack_contract).make_bet(10, token_address).call(&mut env.private());

    //include multiple cards in the dealers hand
    add_card_note_dealer(env, blackjack_contract, player, 2, 0);

    add_card_note_dealer(env, blackjack_contract, player, 1, 0);

    //player buys insurance
    BlackJack::at(blackjack_contract).place_insurance_bet().call(&mut env.private());
}

pub unconstrained fn game_state(
    env: &mut TestEnvironment,
    blackjack_address: AztecAddress,
    player: AztecAddress,
    state: Field,
) {
    env.impersonate(blackjack_address);
    let unconstrained_context = env.unkonstrained();
    let storage = BlackJack::Storage::init(unconstrained_context);
    // let game_state_slot =
    //     derive_storage_slot_in_map(BlackJack::storage_layout().game_state.slot, player);
    let game_state_slot = BlackJack::storage_layout().game_state.slot;
    println(f"game state slot: {game_state_slot}");
    let game_slot = derive_storage_slot_in_map(game_state_slot, player);
    println(f"game slot: {game_slot}");
    //should be 12
    // Print values before writing
    println(f"State value: {state}");

    cheatcodes::direct_storage_write(blackjack_address, game_state_slot, [state, 0]);

    env.advance_block_by(1);

    // Verify the write by reading the value
    let current_state = storage.game_state.at(player).get_current_value();
    println(f"State after write: {current_state}");
}

