use crate::BlackJack;
use crate::notes::CardNote::{Card, CardNote, Deck};
use crate::test::utilsPriv::{setupPriv, tokenSetup, add_card_note_player, check_bet};
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
unconstrained fn doubledown_11() {
    //happy path
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    env.advance_block_by(1);
    //make a bet
    env.impersonate(player);
    BlackJack::at(blackjack_contract).make_bet(10, token_address).call(&mut env.private());

    //add a card to the player hand
    add_card_note_player(env, blackjack_contract, player, 5, 0);
    env.advance_block_by(1);
    add_card_note_player(env, blackjack_contract, player, 6, 0);
    env.advance_block_by(1);

    //double down
    env.impersonate(player);
    BlackJack::at(blackjack_contract).double_down().call(&mut env.private());

    env.advance_block_by(1);
    //check the bet
    check_bet(env, blackjack_contract, player, 20);
}

#[test]
unconstrained fn double_down_10() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //make a bet
    env.impersonate(player);
    BlackJack::at(blackjack_contract).make_bet(10, token_address).call(&mut env.private());
    //add a card to the player hand
    add_card_note_player(env, blackjack_contract, player, 4, 0);
    env.advance_block_by(1);
    add_card_note_player(env, blackjack_contract, player, 6, 0);
    env.advance_block_by(1);

    //double down
    env.impersonate(player);
    BlackJack::at(blackjack_contract).double_down().call(&mut env.private());

    env.advance_block_by(1);

    //check the bet
    check_bet(env, blackjack_contract, player, 20);
}

#[test]
unconstrained fn double_down_9() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //make a bet
    env.impersonate(player);
    BlackJack::at(blackjack_contract).make_bet(10, token_address).call(&mut env.private());

    //add a card to the player hand
    add_card_note_player(env, blackjack_contract, player, 3, 0);
    env.advance_block_by(1);
    add_card_note_player(env, blackjack_contract, player, 6, 0);
    env.advance_block_by(1);

    //double down
    env.impersonate(player);
    BlackJack::at(blackjack_contract).double_down().call(&mut env.private());

    env.advance_block_by(1);

    //check the bet
    check_bet(env, blackjack_contract, player, 20);
}

#[test(should_fail)]
unconstrained fn double_down_fail() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //make a bet
    env.impersonate(player);
    BlackJack::at(blackjack_contract).make_bet(10, token_address).call(&mut env.private());

    //add a card to the player hand
    add_card_note_player(env, blackjack_contract, player, 2, 0);
    env.advance_block_by(1);
    add_card_note_player(env, blackjack_contract, player, 3, 0);
    env.advance_block_by(1);

    //double down
    env.impersonate(player);
    BlackJack::at(blackjack_contract).double_down().call(&mut env.private());
}

#[test(should_fail)]
unconstrained fn double_down_fail_no_bet() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //add a card to the player hand
    add_card_note_player(env, blackjack_contract, player, 5, 0);
    env.advance_block_by(1);
    add_card_note_player(env, blackjack_contract, player, 5, 0);
    env.advance_block_by(1);

    //double down
    env.impersonate(player);
    BlackJack::at(blackjack_contract).double_down().call(&mut env.private());
}

#[test(should_fail)]
unconstrained fn double_down_fail_double_downed() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    env.advance_block_by(1);
    //make a bet
    env.impersonate(player);
    BlackJack::at(blackjack_contract).make_bet(10, token_address).call(&mut env.private());

    //add a card to the player hand
    add_card_note_player(env, blackjack_contract, player, 5, 0);
    env.advance_block_by(1);
    add_card_note_player(env, blackjack_contract, player, 6, 0);
    env.advance_block_by(1);

    //double down
    env.impersonate(player);
    BlackJack::at(blackjack_contract).double_down().call(&mut env.private());

    env.advance_block_by(1);
    //check the bet
    check_bet(env, blackjack_contract, player, 20);

    //double down again
    env.impersonate(player);
    BlackJack::at(blackjack_contract).double_down().call(&mut env.private());
}

