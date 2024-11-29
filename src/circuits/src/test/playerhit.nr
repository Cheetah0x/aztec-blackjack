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
