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

mod helpers;
mod test;

use dep::aztec::macros::aztec;

#[aztec]
contract BlackJack {

    use crate::helpers::CardHelpersPublic::CardHelpersPublic::{
        Card, check_bust, dealer_play, Deck, determine_winner_helper, draw_card, Hand, hand_points,
        new_hand, player_hit_helper, start_game,
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

    #[private]
    #[initializer]
    fn constructor(player: AztecAddress) {
        // let mut deck = Deck::new(); // Start with an empty deck
        // storage.card_deck.write(deck);
    }

    //this is just because the constructor is private
    #[public]
    fn initialize_deck() {
        let deck_seed = 30;
        let mut deck = Deck::new(deck_seed); // Start with an empty deck
        storage.card_deck.write(deck);
    }

    #[public]
    #[view]
    fn dealer_hand() -> Hand {
        storage.dealer_hand.read()
    }

    #[public]
    #[view]
    fn player_hand(player: AztecAddress) -> Hand {
        storage.player_hands.at(player).read()
    }

    #[public]
    #[view]
    fn view_deck() -> Deck {
        storage.card_deck.read()
    }

    #[public]
    #[view]
    fn determine_winner(player: AztecAddress) -> u8 {
        let mut player_hand = storage.player_hands.at(player).read();
        let mut dealer_hand = storage.dealer_hand.read();

        let outcome: u8 = determine_winner_helper(&mut player_hand, &mut dealer_hand);

        outcome
    }

    #[public]
    #[view]
    fn view_player_points(player: AztecAddress) -> u8 {
        let mut player_hand = storage.player_hands.at(player).read();

        let player_points = hand_points(&mut player_hand);

        player_points
    }

    #[public]
    #[view]
    fn view_dealer_points() -> u8 {
        let mut dealer_hand = storage.dealer_hand.read();

        let dealer_points = hand_points(&mut dealer_hand);

        dealer_points
    }

    #[public]
    fn begin_game(player: AztecAddress) {
        //read existing
        let mut deck = storage.card_deck.read();

        let mut player_hand = new_hand();
        let mut dealer_hand = new_hand();

        // Draw cards and update deck with returned values
        let (player_hand, dealer_hand, deck) =
            start_game(&mut deck, &mut player_hand, &mut dealer_hand);

        //store the deck
        storage.card_deck.write(deck);
        //store the hands
        storage.player_hands.at(player).write(player_hand);
        storage.dealer_hand.write(dealer_hand);
    }

    #[public]
    fn player_hit(player: AztecAddress) {
        let mut deck = storage.card_deck.read();
        let mut player_hand = storage.player_hands.at(player).read();

        let bust = player_hit_helper(&mut deck, &mut player_hand);
        player_hand.bust = bust;

        // Write the updated hand and deck back to storage
        storage.player_hands.at(player).write(player_hand);
        storage.card_deck.write(deck);
    }

    #[public]
    fn player_stand(player: AztecAddress) {
        // Proceed to dealer's turn
        let mut deck = storage.card_deck.read();
        let mut dealer_hand = storage.dealer_hand.read();

        dealer_play(&mut deck, &mut dealer_hand);

        storage.dealer_hand.write(dealer_hand);
        storage.card_deck.write(deck);
    }

    #[public]
    fn player_double_down(player: AztecAddress) {
        let mut deck = storage.card_deck.read();
        let mut player_hand = storage.player_hands.at(player).read();
        let mut dealer_hand = storage.dealer_hand.read();

        // Ensure player can only double down on 9, 10, or 11
        let player_points = hand_points(&mut player_hand);
        if player_points < 9 {
            if player_points > 11 {
                assert(false, "Player can only double down on 9, 10, or 11");
            }
        }

        // Double the bet (implement bet logic separately)
        // Take exactly one more card
        player_hand.cards.push(draw_card(&mut deck));

        // Update the player's hand in storage
        storage.player_hands.at(player).write(player_hand);

        // Proceed to dealer's turn
        dealer_play(&mut deck, &mut dealer_hand);

        storage.dealer_hand.write(dealer_hand);
        storage.card_deck.write(deck);
    }

}
