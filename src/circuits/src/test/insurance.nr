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
unconstrained fn insurance() {
    //happy path
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //make a bet
    env.impersonate(player);
    BlackJack::at(blackjack_contract).make_bet(10, token_address).call(&mut env.private());

    env.advance_block_by(1);
    //include the ace in the dealers hand
    add_card_note_dealer(env, blackjack_contract, player, 1, 0);

    //player buys insurance
    BlackJack::at(blackjack_contract).place_insurance_bet().call(&mut env.private());

    //check that the insurance bet was made
    env.impersonate(blackjack_contract);
    let unconstrained_context = env.unkonstrained();
    let storage = BlackJack::Storage::init(unconstrained_context);
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
    // docs:end:txe_test_add_note
}
