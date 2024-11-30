use crate::BlackJack;
use crate::notes::CardNote::{Card, CardNote, Deck};
use crate::test::utilsPriv::{
    setupPriv, tokenSetup, check_bet, check_private_balance, mint_private, add_token_note,
};
use dep::aztec::oracle::random::random;
use dep::std::println;
use dep::token::Token;

#[test]
unconstrained fn beginGame() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();
    tokenSetup(env, blackjack_contract, token_address, player);

    env.impersonate(player);

    println("checkpoint 1");

    //make a bet
    let bet_amount = 10;
    BlackJack::at(blackjack_contract).make_bet(bet_amount, token_address).call(&mut env.private());

    env.advance_block_by(1);

    //check the bet is correct
    env.impersonate(player);
    env.advance_block_by(1);
    let begin_game = BlackJack::at(blackjack_contract).begin_game().call(&mut env.private());

    println(f"Begin game: {begin_game}");
    //fetch the player hand
    let player_hand = BlackJack::at(blackjack_contract).player_hand().view(&mut env.private());

    let dealer_hand = BlackJack::at(blackjack_contract).dealer_hand().view(&mut env.private());

    println("checkpoint 2");

    println(f"Player cards: {player_hand}");
    println(f"Dealer cards: {dealer_hand}");

    //check the points of the dealer and the player
    env.impersonate(player);
    let player_points = BlackJack::at(blackjack_contract).player_points().view(&mut env.private());
    let dealer_points = BlackJack::at(blackjack_contract).dealer_points().view(&mut env.private());

    println(f"Player points: {player_points}");
    println(f"Dealer points: {dealer_points}");

    println("checkpoint 3");

    //now need to hit
    env.advance_block_by(1);
    env.impersonate(player);
    BlackJack::at(blackjack_contract).player_hit(0).call(&mut env.private());

    println("checkpoint 4");

    env.advance_block_by(1);

    //read the player hand again
    // After hitting, re-fetch the player's hand
    let player_hand2 = BlackJack::at(blackjack_contract).player_hand().view(&mut env.private());
    println(f"Updated Player cards: {player_hand2}");

    println("checkpoint 5");
    env.advance_block_by(1);

    //check what these add to
    env.impersonate(player);
    let player_points = BlackJack::at(blackjack_contract).player_points().view(&mut env.private());
    println(f"Player points: {player_points}");

    println("checkpoint 6");

    //now check if bust, have to read from storage
    env.advance_block_by(1);
    let is_bust = BlackJack::at(blackjack_contract).is_player_bust_view().view(&mut env.public());
    println(f"Is bust: {is_bust}");

    println("checkpoint 7");

    env.advance_block_by(1);
    println("checkpoint 8");

    println("checkpoint 9");
    //add the test for when the player stands
    env.advance_block_by(1);
    env.impersonate(player);
    let win = BlackJack::at(blackjack_contract).player_stand().call(&mut env.private());
    println(f"Win: {win}");

    println("checkpoint 10");

    let dealer_hand2 = BlackJack::at(blackjack_contract).dealer_hand().view(&mut env.private());
    println(f"Dealer cards2: {dealer_hand2}");

    println("checkpoint 11");

    env.impersonate(player);
    //get the dealer points
    let dealerpoints2 = BlackJack::at(blackjack_contract).dealer_points().view(&mut env.private());
    println(f"dealerPoints2 {dealerpoints2}");

    println("checkpoint 12");

    //see if the dealer is bust or not
    let dealer_bust =
        BlackJack::at(blackjack_contract).is_dealer_bust_view().view(&mut env.public());
    println(f"dealer bust {dealer_bust}");

    println("checkpoint 13");

    //reset the game
    //this should now be done in the player stand
    BlackJack::at(blackjack_contract).reset_game().call(&mut env.private());

    println("checkpoint 14");

    //check the player hand is empty
    env.impersonate(blackjack_contract);
    let player_hand3 = BlackJack::at(blackjack_contract).player_hand().view(&mut env.private());
    println(f"Player hand after reset: {player_hand3}");
    assert(
        player_hand3
            == [
                Card { rank: 0, suit: 0 },
                Card { rank: 0, suit: 0 },
                Card { rank: 0, suit: 0 },
                Card { rank: 0, suit: 0 },
                Card { rank: 0, suit: 0 },
                Card { rank: 0, suit: 0 },
                Card { rank: 0, suit: 0 },
                Card { rank: 0, suit: 0 },
            ],
        "Player hand is not empty",
    );

    println("checkpoint 15");

    //check the dealer hand is empty
    env.impersonate(blackjack_contract);
    let dealer_hand3 = BlackJack::at(blackjack_contract).dealer_hand().view(&mut env.private());
    println(f"Dealer hand after reset: {dealer_hand3}");
    assert(
        dealer_hand3
            == [
                Card { rank: 0, suit: 0 },
                Card { rank: 0, suit: 0 },
                Card { rank: 0, suit: 0 },
                Card { rank: 0, suit: 0 },
                Card { rank: 0, suit: 0 },
                Card { rank: 0, suit: 0 },
                Card { rank: 0, suit: 0 },
                Card { rank: 0, suit: 0 },
            ],
        "Dealer hand is not empty",
    );

    println("checkpoint 16");
}

//next i need to add the player hit function.

//isolated test to make sure the value does not go above 10 for the rank
#[test]
unconstrained fn cardValue() {
    for _ in 0..10 {
        let random_one = unsafe { random() };
        let value_bytes: [u8; 32] = random_one.to_le_bytes();
        let rank = (((value_bytes[0] as u64) + (value_bytes[1] as u64) * 256) % 13) + 1;
        let suit = (((value_bytes[2] as u64) + (value_bytes[3] as u64) * 256) % 4) + 1;

        let rank_u64 = (rank as u64);
        let card_value = if rank_u64 > 10 { 10 } else { rank_u64 };

        let card: Card = Card { rank: card_value, suit: suit };

        assert(card_value <= 10, "Card value is greater than 10");
        println(f"Card value: {card}");
    }
}

// #[test]
// unconstrained fn doubleDown() {
//     let (mut env, player, blackjack_contract, token_address) = setupPriv();

//     env.impersonate(player);

//     //will need to add a two card notes to the storage to simulate this environment.
//     //also need t0 get the token logic working properly for this to work.
// }

//get the card from storage
// env.impersonate(blackjack_contract);
// let unconstrained_context = env.unkonstrained();
// let storage = BlackJack::Storage::init(unconstrained_context);
// let options = NoteViewerOptions::new();
// //for the player hand
// let cards: BoundedVec<CardNote, 10> = storage.player_hand.at(player).view_notes(options);
// let mut player_cards = Vec::new();
// let mut card_count = 0;
// for i in 0..cards.len() {
//     let card_used = cards.get_unchecked(i);
//     let card_note_dets = card_used.card;
//     player_cards.push(card_note_dets);
//     card_count += 1;
//     println(f"Player card rank: {card_note_dets.rank}");
//     assert(card_note_dets.rank <= 10, "Player card rank is greater than 10");
// }
