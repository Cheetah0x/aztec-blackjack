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
        Card, check_bust, Deck, draw_card, generate_deck, Hand, hand_points, new_hand, start_game,
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
        let mut deck = Deck::new(); // Start with an empty deck
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
    fn begin_game(player: AztecAddress) {
        //read existing deck or create a new one
        let mut deck = if storage.card_deck.read().drawn_cards.len() == 0 {
            Deck::new()
            } else {
                storage.card_deck.read()
            };

        let mut player_hand = new_hand();
        let mut dealer_hand = new_hand();
        start_game(&mut deck, &mut player_hand, &mut dealer_hand);

        //store the deck
        // storage.card_deck.write(deck);

        //store the hands
        storage.player_hands.at(player).write(player_hand);
        storage.dealer_hand.write(dealer_hand);
    }



    // #[public]
    // fn player_hit(player: AztecAddress) {
    //     let mut deck = storage.card_deck.modify();
    //     let mut player_hand = storage.player_hands.at(player).modify();

    //     // Draw a new card
    //     player_hand.cards[player_hand.card_count.to_u32()] = draw_card(deck, deck.drawn_count);
    //     deck.drawn_count += 1;
    //     player_hand.card_count += 1;

    //     // Check if player busts
    //     if check_bust(player_hand) {
    //         // Handle bust (e.g., end game, declare dealer winner)
    //         // Implement game over logic here
    //     }

    //     // Update the player's hand in storage
    //     storage.player_hands.at(player).write(player_hand);
    // }

    // #[public]
    // fn player_stand(player: AztecAddress) {
    //     // Proceed to dealer's turn
    //     dealer_play(player);
    // }

    // #[public]
    // fn dealer_play(player: AztecAddress) {
    // let mut deck = storage.card_deck.modify();
    // let mut dealer_hand = storage.dealer_hand.modify();

    // // Reveal the dealer's hole card
    // dealer_hand.cards[1] = draw_card(deck, deck.drawn_count);
    // deck.drawn_count += 1;
    // dealer_hand.card_count = 2;

    // // Dealer must hit until the hand value is 17 or more
    // while hand_points(dealer_hand).to_u32() < 17 {
    //     dealer_hand.cards[dealer_hand.card_count.to_u32()] = draw_card(deck, deck.drawn_count);
    //     deck.drawn_count += 1;
    //     dealer_hand.card_count += 1;
    // }

    // // Update the dealer's hand in storage
    // storage.dealer_hand.write(dealer_hand);

    // // Determine the outcome
    // determine_winner(player);
    // }

    // fn determine_winner(player: AztecAddress) {
    // let player_hand = storage.player_hands.at(player).read();
    // let dealer_hand = storage.dealer_hand.read();

    // let player_points = hand_points(player_hand).to_u32();
    // let dealer_points = hand_points(dealer_hand).to_u32();

    // let player_bust = check_bust(player_hand);
    // let dealer_bust = check_bust(dealer_hand);

    // let outcome: &str;

    // if player_bust {
    //     outcome = "Player busts. Dealer wins.";
    // } else if dealer_bust {
    //     outcome = "Dealer busts. Player wins!";
    // } else if player_points > dealer_points {
    //     outcome = "Player wins!";
    // } else if dealer_points > player_points {
    //     outcome = "Dealer wins.";
    // } else {
    //     outcome = "Push (tie).";
    // }

    // // Handle payouts and game over logic
    // // Emit event or log outcome
    // // For simplicity, you can store the outcome in storage or emit it using an event
    // }

//     #[public]
//     fn player_double_down(player: AztecAddress) {
//         let mut deck = storage.card_deck.modify();
//         let mut player_hand = storage.player_hands.at(player).modify();

//         // Ensure player can only double down on 9, 10, or 11
//         let player_points = hand_points(player_hand).to_u32();
//         if player_points < 9 || player_points > 11 {
//             // Reject the action
//             // Emit error or revert transaction
//             return;
//         }

//         // Double the bet (implement bet logic separately)
//         // Take exactly one more card
//         player_hand.cards[player_hand.card_count.to_u32()] = draw_card(deck, deck.drawn_count);
//         deck.drawn_count += 1;
//         player_hand.card_count += 1;

//         // Update the player's hand in storage
//         storage.player_hands.at(player).write(player_hand);

//         // Proceed to dealer's turn
//         dealer_play(player);
//     }

//     pub fn hand_points(hand: Hand) -> Field {
//     let mut points = 0;
//     let mut aces = 0;

//     for i in 0..hand.card_count.to_u32() {
//         let card = hand.cards[i];
//         if card.rank == 1 {
//             aces += 1;
//             points += 11; // Assume Ace as 11 initially
//         } else if card.rank >= 10 {
//             points += 10;
//         } else {
//             points += card.rank;
//         }
//     }

//     // Adjust for aces if points exceed 21
//     while points > 21 && aces > 0 {
//         points -= 10; // Convert an Ace from 11 to 1
//         aces -= 1;
//     }

//     points
// }








}
