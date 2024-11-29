use crate::notes::CardNote::{Card, CardNote, Deck};
use dep::address_note::address_note::AddressNote;
use dep::aztec::{
    context::{PrivateContext, PublicContext},
    encrypted_logs::encrypted_note_emission::{
        encode_and_encrypt_note, encode_and_encrypt_note_unconstrained,
    }, keys::getters::get_public_keys,
    macros::{functions::{initializer, internal, private, public, view}, storage::storage},
    oracle::random::random,
    prelude::{
        AztecAddress, Map, NoteGetterOptions, PrivateImmutable, PrivateMutable, PrivateSet,
        PublicImmutable, PublicMutable,
    },
};
use dep::aztec::oracle::debug_log::{debug_log, debug_log_format};
use dep::value_note::value_note::ValueNote;

//drawing a card helper
//then implement olehs way of doing this.
fn draw_card(
    player: AztecAddress,
    location: PrivateSet<CardNote, &mut PrivateContext>,
    context: &mut PrivateContext,
) {
    let player_keys = get_public_keys(player);
    let random_value = unsafe { random() };
    let value_bytes: [u8; 32] = random_value.to_le_bytes();
    let rank = (((value_bytes[0] as u64) + (value_bytes[1] as u64) * 256) % 13) + 1;

    let suit = (((value_bytes[2] as u64) + (value_bytes[3] as u64) * 256) % 4) + 1;

    // Convert to u8 first, then check the value
    let rank_u64 = (rank as u64);

    let card_value = if rank_u64 > 10 { 10 } else { rank_u64 };
    assert(card_value <= 10, "Card value is greater than 10");

    let card: Card = Card { rank: card_value, suit: suit };

    let mut card_note = CardNote::new(card, player);
    location.insert(&mut card_note).emit(encode_and_encrypt_note(
        context,
        player_keys.ovpk_m,
        player,
        player,
    ));
}

//helper to fetch the card notes
fn card_points(location: PrivateSet<CardNote, &mut PrivateContext>) -> u64 {
    let options = NoteGetterOptions::new();
    let cards = location.get_notes(options);
    let mut points = 0;
    let mut aces = 0;

    for i in 0..cards.max_len() {
        if i < cards.len() {
            let note = cards.get_unchecked(i);
            let card = note.card;
            let rank_value = if card.rank > 10 { 10 } else { card.rank };
            if rank_value == 1 {
                aces += 1;
                points += 11; // Assume Ace is high initially
            } else {
                points += rank_value;
            }
        }
    }

    // Adjust for Aces if points exceed 21
    if points > 21 & aces > 0 {
        points -= 10; // Make Ace low
        aces -= 1;
    }

    points as u64
}

fn draw_until_seventeen(
    dealer_points: u64,
    player: AztecAddress,
    context: &mut PrivateContext,
    location: PrivateSet<CardNote, &mut PrivateContext>,
) -> u64 {
    let mut new_dealer_points = dealer_points;
    for _ in 0..2 {
        //loop not working, so just do it manually, 4 times should be enough for now.
        //not even working manually
        if new_dealer_points < 17 {
            // Draw a card
            draw_card(player, location, context);
            // Recalculate dealer points
            new_dealer_points = card_points(location);
        }
    }
    // // could make this card points more efficient to only get the last note, instead of all
    new_dealer_points as u64
}

fn payout_win(
    player: AztecAddress,
    win: bool,
    blackjack: bool,
    context: &mut PrivateContext,
    location: PrivateSet<ValueNote, &mut PrivateContext>,
) {
    //have the win in the contract logic
    //if the player wins, payout 2x the bet
    let player_keys = get_public_keys(player);
    let options = NoteGetterOptions::new();
    let player_bets: BoundedVec<ValueNote, 16> = location.get_notes(options);
    let mut bets = 0;
    for i in 0..player_bets.max_len() {
        if i < player_bets.len() {
            let note = player_bets.get_unchecked(i);
            bets += note.value;
        }
    }
    let payout_amount = if blackjack {
        bets * 3 / 2
    } else if win {
        bets * 2
    } else {
        //this will be if win is false, but it is a push
        bets
    };

    let mut payout_note = ValueNote::new(payout_amount, player);
    location.insert(&mut payout_note).emit(encode_and_encrypt_note(
        context,
        player_keys.ovpk_m,
        player,
        player,
    ));
}

fn is_blackjack(player: AztecAddress, location: PrivateSet<CardNote, &mut PrivateContext>) -> bool {
    //check if the cards are 11 and 10
    let options = NoteGetterOptions::new();
    let cards = location.get_notes(options);
    let mut blackjack = false;
    let mut aces = 0;
    let mut face_cards = 0;
    for i in 0..cards.max_len() {
        if i < cards.len() {
            let note = cards.get_unchecked(i);
            let rank = note.card.rank;
            if rank == 11 {
                aces += 1;
            } else if rank == 10 {
                face_cards += 1;
            }
        }
    }

    if (aces == 1) & (face_cards == 1) {
        blackjack = true;
    }

    blackjack
}
