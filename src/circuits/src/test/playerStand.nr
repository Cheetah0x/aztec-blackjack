use crate::BlackJack;
use crate::notes::CardNote::{Card, CardNote, Deck};
use crate::test::utilsPriv::setupPriv;
use dep::std::println;
use dep::token::Token;

#[test]
unconstrained fn playerStand() {
    //happy path
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    env.impersonate(player);

    //make a bet
    println("playerStand 1");
    let bet_amount = 10;
    BlackJack::at(blackjack_contract).make_bet(bet_amount, token_address).call(&mut env.private());
    env.advance_block_by(1);

    //begin the game
    BlackJack::at(blackjack_contract).begin_game().call(&mut env.private());

    env.advance_block_by(1);

    println("playerStand 4");
    BlackJack::at(blackjack_contract).player_stand().call(&mut env.private());

    println("playerStand 5");
    env.advance_block_by(1);

    //reset the game
    BlackJack::at(blackjack_contract).reset_game().call(&mut env.private());
    //checkpoint 6
}

#[test(should_fail)]
unconstrained fn player_stand_no_bet() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //begin the game
    BlackJack::at(blackjack_contract).begin_game().call(&mut env.private());

    //player stand
    BlackJack::at(blackjack_contract).player_stand().call(&mut env.private());
}

