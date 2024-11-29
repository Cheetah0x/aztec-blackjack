use crate::BlackJack;
use crate::notes::CardNote::{Card, CardNote, Deck};
use crate::test::utilsPriv::{setupPriv, tokenSetup};
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
unconstrained fn player_hit() {
    //happy path
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //bet
    env.impersonate(player);
    BlackJack::at(blackjack_contract).make_bet(10, token_address).call(&mut env.private());
    env.advance_block_by(1);
    //begin game
    env.impersonate(player);
    BlackJack::at(blackjack_contract).begin_game().call(&mut env.private());
    // player hit
    BlackJack::at(blackjack_contract).player_hit().call(&mut env.private());

    // check player has 3 cards
    env.impersonate(blackjack_contract);
    let unconstrained_context = env.unkonstrained();
    let storage = BlackJack::Storage::init(unconstrained_context);
    let player_hand = storage.player_hand.at(player);
    let player_cards = player_hand.view_notes(NoteViewerOptions::new());
    assert(player_cards.len() == 3, "Player does not have 3 cards in their hand");
}

#[test(should_fail)]
unconstrained fn player_hit_one_card() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //bet
    env.impersonate(player);
    BlackJack::at(blackjack_contract).make_bet(10, token_address).call(&mut env.private());
    env.advance_block_by(1);
    //add card player
    add_card_note_player(env, blackjack_contract, player, 1, 0);
    //add card dealer
    add_card_note_dealer(env, blackjack_contract, player, 1, 0);

    //player hit
    env.impersonate(player);
    BlackJack::at(blackjack_contract).player_hit().call(&mut env.private());
}

#[test(should_fail)]
unconstrained fn player_hit_no_cards() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //bet
    env.impersonate(player);
    BlackJack::at(blackjack_contract).make_bet(10, token_address).call(&mut env.private());
    env.advance_block_by(1);

    //player hit
    env.impersonate(player);
    BlackJack::at(blackjack_contract).player_hit().call(&mut env.private());
}

#[test(should_fail)]
unconstrained fn player_hit_no_bet() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //begin game
    env.impersonate(player);
    BlackJack::at(blackjack_contract).begin_game().call(&mut env.private());

    //player hit
    env.impersonate(player);
    BlackJack::at(blackjack_contract).player_hit().call(&mut env.private());
}

#[test(should_fail)]
unconstrained fn player_hit_dealer_no_card() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //bet
    env.impersonate(player);
    BlackJack::at(blackjack_contract).make_bet(10, token_address).call(&mut env.private());
    env.advance_block_by(1);
    //add player card
    add_card_note_player(env, blackjack_contract, player, 1, 0);
    add_card_note_player(env, blackjack_contract, player, 1, 0);

    //player hit
    env.impersonate(player);
    BlackJack::at(blackjack_contract).player_hit().call(&mut env.private());
}

#[test(should_fail)]
unconstrained fn player_hit_dealer_two_cards() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //bet
    env.impersonate(player);
    BlackJack::at(blackjack_contract).make_bet(10, token_address).call(&mut env.private());
    env.advance_block_by(1);

    //begin game
    env.impersonate(player);
    BlackJack::at(blackjack_contract).begin_game().call(&mut env.private());

    //add dealer card
    add_card_note_dealer(env, blackjack_contract, player, 5, 0);

    //player hit
    env.impersonate(player);
    BlackJack::at(blackjack_contract).player_hit().call(&mut env.private());
}

#[test]
unconstrained fn player_hit_double_downed() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //bet
    env.impersonate(player);
    BlackJack::at(blackjack_contract).make_bet(10, token_address).call(&mut env.private());
    env.advance_block_by(1);

    add_card_note_player(env, blackjack_contract, player, 4, 0);
    add_card_note_dealer(env, blackjack_contract, player, 1, 0);
    add_card_note_player(env, blackjack_contract, player, 5, 0);

    //double down
    env.impersonate(player);
    BlackJack::at(blackjack_contract).double_down().call(&mut env.private());

    //player hit
    env.impersonate(player);
    BlackJack::at(blackjack_contract).player_hit().call(&mut env.private());
}

pub unconstrained fn add_card_note_player(
    env: &mut TestEnvironment,
    blackjack_address: AztecAddress,
    player: AztecAddress,
    rank: u64,
    note_randomness: Field,
) {
    // docs:start:txe_test_add_note
    let player_card_slot =
        derive_storage_slot_in_map(BlackJack::storage_layout().player_hand.slot, player);

    env.add_note(
        &mut CardNote {
            card: Card { rank: rank, suit: 0 },
            randomness: note_randomness,
            owner: player,
            header: NoteHeader::empty(),
        },
        player_card_slot,
        blackjack_address,
    );
}

pub unconstrained fn add_card_note_dealer(
    env: &mut TestEnvironment,
    blackjack_address: AztecAddress,
    player: AztecAddress,
    rank: u64,
    note_randomness: Field,
) {
    // docs:start:txe_test_add_note
    let dealer_card_slot =
        derive_storage_slot_in_map(BlackJack::storage_layout().dealer_hand.slot, player);

    env.add_note(
        &mut CardNote {
            card: Card { rank: rank, suit: 0 },
            randomness: note_randomness,
            owner: player,
            header: NoteHeader::empty(),
        },
        dealer_card_slot,
        blackjack_address,
    );
}
