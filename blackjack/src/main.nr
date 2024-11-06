//functionality that i need:

//make it super simple to start similar to kits

// Player hits/stands to beat dealer's hand by getting as close to 21 as possible.

// Dealer must hit on and up to 16 and stand on 17.

// Player can only double down on 9, 10, or 11.

// Player can either double down or split, player cannot split then double down and vice versa.

// Player cannot split then split again or double down more than once.

// Player who splits Aces can receive only one more additional card on a hand.

// Player can get insurance if dealer might have a BlackJack.

// Aces are high unless card total is already greater than 11.

// Blackjack payout is 3:2.

// No surrender.

//some finds here
//i had to use my own serialisation and deserialisation for the deck, default ones were not working



mod CardNote;
mod test;

use dep::aztec::macros::aztec;

#[aztec]
contract BlackJack {

    use crate::CardNote::CardNote::{
        Card, check_bust, Deck, draw_card, generate_deck, Hand, hand_points, new_hand,
    };
    use dep::aztec::{
        context::PublicContext,
        macros::{functions::{initializer, private, public, view}, storage::storage},
        prelude::{AztecAddress, Map, PrivateMutable, PublicImmutable, PublicMutable},
    };

    #[storage]
    struct Storage<Context> {
        card_deck: PublicMutable<Deck, Context>,
        player_hands: Map<AztecAddress, PublicMutable<Hand, Context>, Context>,
        dealer_hand: PublicMutable<Hand, Context>,
    }

    #[public]
    #[initializer]
    fn constructor(player: AztecAddress) {
        let mut deck: Deck = generate_deck();
        storage.card_deck.write(deck);
    }

    #[public]
    #[view]
    fn dealer_hand() -> Hand {
        storage.dealer_hand.read()
    }

    #[public]
    #[view]
    fn view_deck() -> Deck {
        storage.card_deck.read()
    }

    #[public]
    fn dealer_cards() -> Hand {{
        let mut dealer_hand: Hand = new_hand();
        dealer_hand.cards[0] = draw_card(storage.card_deck.read(), 0);
        dealer_hand.cards[1] = draw_card(storage.card_deck.read(), 1);
        storage.dealer_hand.write(dealer_hand);
        dealer_hand
    }}

    // #[public]
    // fn play_game(player: AztecAddress) -> bool {
    //     // Initialize deck if not already initialized
    //     let mut deck = storage.card_deck.read();

    //     // Initialize hands
    //     let mut player_hand: Hand = new_hand();
    //     let mut dealer_hand: Hand = new_hand();
    //     let mut current_index = 0;

    //     // Draw initial cards for player and dealer
    //     player_hand.cards[0] = draw_card(deck, current_index);
    //     current_index += 1;
    //     player_hand.cards[1] = draw_card(deck, current_index);
    //     current_index += 1;
    //     player_hand.card_count = 2;

    //     dealer_hand.cards[0] = draw_card(deck, current_index);
    //     current_index += 1;
    //     dealer_hand.cards[1] = draw_card(deck, current_index);
    //     current_index += 1;
    //     dealer_hand.card_count = 2;

    //     // Update storage
    //     storage.player_hands.at(player).write(player_hand);
    //     storage.dealer_hand.write(dealer_hand);

    //     let player_points = hand_points(player_hand);
    //     let dealer_points = hand_points(dealer_hand);

    //     if (player_points as u8 > dealer_points as u8) & !check_bust(player_hand) {
    //         // Player wins
    //         true
    //     } else {
    //         // Dealer wins
    //         false
    //     }
    // }

}
