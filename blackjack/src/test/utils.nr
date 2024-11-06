use crate::BlackJack;
use dep::aztec::{
    prelude::AztecAddress,
    test::helpers::{cheatcodes, test_environment::TestEnvironment},
};
use dep::std::println;

pub unconstrained fn setup() -> (&mut TestEnvironment, AztecAddress, AztecAddress) {
    let mut env = TestEnvironment::new();

    let player = env.create_account();

    env.advance_block_by(1);

    env.impersonate(player);

    let initializer = BlackJack::interface().constructor(player);
    println(f"Initializer: {initializer}");
    let blackjack_deploy = env.deploy_self("BlackJack").with_private_initializer(initializer);
    println("Deployed");
    let blackjack_contract = blackjack_deploy.to_address();

    env.advance_block_by(1);

    println("Contract deployed");

    (&mut env, player, blackjack_contract)
}

#[test]
pub unconstrained fn test_constructor() {
    let (mut env, player, blackjack_contract) = setup();
    assert(!blackjack_contract.is_zero(), "Contract not deployed");
}

#[test]
 unconstrained fn test_begin_game() {
    let (mut env, player, blackjack_contract) = setup();
    env.impersonate(player);
    let begin_game = BlackJack::at(blackjack_contract).begin_game(player).call(&mut env.public());
    println(f"Begin game");

    env.advance_block_by(1);

    //view the deck
    BlackJack::at(blackjack_contract).initialize_deck().call(&mut env.public());
    let deck = BlackJack::at(blackjack_contract).view_deck().view(&mut env.public());

    //get the values from storage
    let dealer_hand = BlackJack::at(blackjack_contract).dealer_hand().view(&mut env.public());
    println(f"Dealer hand fetched");
    let player_hand = BlackJack::at(blackjack_contract).player_hand(player).view(&mut env.public());
    println(f"Player hand fetched");


    assert(dealer_hand.cards.len() == 1, "Dealer hand should have 1 card");
    assert(player_hand.cards.len() == 2, "Player hand should have 2 cards");
    println(f"Dealer hand: {dealer_hand}");
    println(f"Player hand: {player_hand}");
    println(f"Deck: {deck}");
}
