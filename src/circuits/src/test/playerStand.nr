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
    let bet_amount = 10;
    BlackJack::at(blackjack_contract).make_bet(bet_amount, token_address).call(&mut env.private());

    //begin the game
    BlackJack::at(blackjack_contract).begin_game().call(&mut env.private());

    BlackJack::at(blackjack_contract).player_stand().call(&mut env.private());
}
