//going to test here to make sure that you have to have made a bet before you can do anything,
//feel like i will need a game in progress storage to be able to make sure that the person can reset the game

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

#[test(should_fail)]
unconstrained fn noBet_begin_game() {
    //can the player start the game without making a bet? this will be yes for now since the transfer does not work, but can add it in
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    BlackJack::at(blackjack_contract).begin_game().call(&mut env.private());
}

#[test(should_fail)]
unconstrained fn noBet_player_hit() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    BlackJack::at(blackjack_contract).player_hit().call(&mut env.private());
}
#[test(should_fail)]
unconstrained fn no_begin_player_hit() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //make a bet
    env.impersonate(player);
    BlackJack::at(blackjack_contract).make_bet(100, token_address).call(&mut env.private());

    BlackJack::at(blackjack_contract).player_hit().call(&mut env.private());
}
#[test(should_fail)]
unconstrained fn player_can_only_stand_is_begin_game() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //make a bet
    env.impersonate(player);
    BlackJack::at(blackjack_contract).make_bet(100, token_address).call(&mut env.private());

    BlackJack::at(blackjack_contract).player_stand().call(&mut env.private());
}
