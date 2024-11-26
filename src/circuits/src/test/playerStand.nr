use crate::BlackJack;
use crate::notes::CardNote::{Card, CardNote, Deck};
use crate::test::utilsPriv::setupPriv;
use dep::address_note::address_note::AddressNote;
use dep::aztec::note::note_getter::view_notes;
use dep::aztec::note::note_viewer_options::NoteViewerOptions;
use dep::aztec::{
    oracle::{
        execution::{get_block_number, get_contract_address},
        random::random,
        storage::storage_read,
    },
    prelude::{AztecAddress, NoteHeader},
    protocol_types::storage::map::derive_storage_slot_in_map,
    test::helpers::{cheatcodes, test_environment::TestEnvironment},
};
use dep::std::println;
use dep::token::Token;
use dep::uint_note::uint_note::UintNote;
use std::test::OracleMock;

#[test]
unconstrained fn playerStand() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    env.impersonate(player);

    //make a bet
    println("playerStand 1");
    let bet_amount = 10;
    BlackJack::at(blackjack_contract).make_bet(bet_amount, token_address).call(&mut env.private());

    println("playerStand 2");
    env.advance_block_by(1);
    //check the bet is correct
    // let bet = BlackJack::at(blackjack_contract).get_bet().view(&mut env.private());
    // assert(bet.to_field() == bet_amount);
    println("playerStand 3");
    env.advance_block_by(1);

    //begin the game
    BlackJack::at(blackjack_contract).begin_game().call(&mut env.private());

    println("playerStand 4");
    BlackJack::at(blackjack_contract).player_stand().call(&mut env.private());

    println("playerStand 5");

    //reset the game
    BlackJack::at(blackjack_contract).reset_game().call(&mut env.private());
    //checkpoint 6
}

