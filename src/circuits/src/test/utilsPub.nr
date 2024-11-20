// use crate::BlackJack;
// use dep::aztec::{
//     prelude::AztecAddress,
//     test::helpers::{cheatcodes, test_environment::TestEnvironment},
// };
// use dep::std::println;

// pub unconstrained fn setup() -> (&mut TestEnvironment, AztecAddress, AztecAddress) {
//     let mut env = TestEnvironment::new();

//     let player = env.create_account();

//     env.advance_block_by(1);

//     env.impersonate(player);

//     let initializer = BlackJack::interface().constructor(player);
//     println(f"Initializer: {initializer}");
//     let blackjack_deploy = env.deploy_self("BlackJack").with_private_initializer(initializer);
//     println("Deployed");
//     let blackjack_contract = blackjack_deploy.to_address();

//     env.advance_block_by(1);

//     println("Contract deployed");

//     (&mut env, player, blackjack_contract)
// }

// #[test]
// pub unconstrained fn test_constructor() {
//     let (mut env, player, blackjack_contract) = setup();
//     assert(!blackjack_contract.is_zero(), "Contract not deployed");
// }

// #[test]
// unconstrained fn test_begin_game() {
//     let (mut env, player, blackjack_contract) = setup();
//     env.impersonate(player);
//     let begin_game = BlackJack::at(blackjack_contract).begin_game(player).call(&mut env.public());
//     println(f"Begin game");

//     env.advance_block_by(1);

//     //view the deck
//     BlackJack::at(blackjack_contract).initialize_deck().call(&mut env.public());
//     let deck = BlackJack::at(blackjack_contract).view_deck().view(&mut env.public());

//     // get the values from storage
//     let dealer_hand = BlackJack::at(blackjack_contract).dealer_hand().view(&mut env.public());
//     println(f"Dealer hand fetched");
//     let player_hand = BlackJack::at(blackjack_contract).player_hand(player).view(&mut env.public());
//     println(f"Player hand fetched");

//     // assert(dealer_hand.cards.len() == 1, "Dealer hand should have 1 card");
//     // assert(player_hand.cards.len() == 2, "Player hand should have 2 cards");
//     println(f"Dealer hand: {dealer_hand}");
//     println(f"Player hand: {player_hand}");
//     println(f"Deck: {deck}");
//     env.advance_block_by(1);
//     //now check the deck
//     let deck_2 = BlackJack::at(blackjack_contract).view_deck().view(&mut env.public());
//     println(f"Deck 2: {deck_2}");

//     //now hit the player
//     BlackJack::at(blackjack_contract).player_hit(player).call(&mut env.public());
//     env.advance_block_by(1);
//     let player_hand_2 =
//         BlackJack::at(blackjack_contract).player_hand(player).view(&mut env.public());
//     println(f"Player hand 2: {player_hand_2}");

//     //let's say that the player stands
//     BlackJack::at(blackjack_contract).player_stand(player).call(&mut env.public());
//     env.advance_block_by(1);
//     let dealer_hand_2 = BlackJack::at(blackjack_contract).dealer_hand().view(&mut env.public());
//     println(f"Dealer hand 2: {dealer_hand_2}");

//     //determine the winner
//     let winner = BlackJack::at(blackjack_contract).determine_winner(player).view(&mut env.public());
//     println(f"Winner: {winner}");
// }

// //test to see if player hit adds one card
// #[test]
// unconstrained fn test_player_hit() {
//     let (mut env, player, blackjack_contract) = setup();
//     env.impersonate(player);
//     BlackJack::at(blackjack_contract).initialize_deck().call(&mut env.public());

//     BlackJack::at(blackjack_contract).begin_game(player).call(&mut env.public());

//     BlackJack::at(blackjack_contract).player_hit(player).call(&mut env.public());
//     env.advance_block_by(1);

//     let player_hand = BlackJack::at(blackjack_contract).player_hand(player).view(&mut env.public());
//     println(f"Player hand test: {player_hand}");

//     let player_points =
//         BlackJack::at(blackjack_contract).view_player_points(player).view(&mut env.public());
//     println(f"Player points test: {player_points}");

//     let dealer_points =
//         BlackJack::at(blackjack_contract).view_dealer_points().view(&mut env.public());
//     println(f"Dealer points test: {dealer_points}");
// }
