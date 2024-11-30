use crate::BlackJack;
use crate::notes::CardNote::{Card, CardNote, Deck};
use crate::test::utilsPriv::{
    setupPriv, check_bet, check_split_bet, add_card_note_player, add_card_note_dealer,
};
use dep::std::println;
use dep::token::Token;

#[test]
unconstrained fn split() {
    //happy path
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //make a bet
    env.impersonate(player);
    BlackJack::at(blackjack_contract).make_bet(10, token_address).call(&mut env.private());
    env.advance_block_by(1);

    add_card_note_player(env, blackjack_contract, player, 1, 0);
    add_card_note_player(env, blackjack_contract, player, 1, 0);
    env.advance_block_by(1);

    //check player has 2 cards
    let player_hand = BlackJack::at(blackjack_contract).player_hand().view(&mut env.private());
    println(f"Player hand: {player_hand}");

    //split
    env.impersonate(player);
    BlackJack::at(blackjack_contract).split().call(&mut env.private());

    //check split hand
    let split_hand = BlackJack::at(blackjack_contract).get_split_hand().view(&mut env.private());
    println(f"Split hand: {split_hand}");
    env.advance_block_by(2);

    //check that the split flag is set
    env.impersonate(player);
    let unconstrained_context = env.unkonstrained();
    let storage = BlackJack::Storage::init(unconstrained_context);
    let has_split = storage.has_split.at(player).get_current_value();
    println(f"Has split: {has_split}");

    env.advance_block_by(2);

    //player hand should now have 1 card
    let player_hand = BlackJack::at(blackjack_contract).player_hand().view(&mut env.private());
    println(f"Player hand: {player_hand}");

    //check that the bet is doubled
    check_bet(env, blackjack_contract, player, 10);
    check_split_bet(env, blackjack_contract, player, 10);

    //add dealer card
    add_card_note_dealer(env, blackjack_contract, player, 1, 0);

    //hit
    env.impersonate(player);
    BlackJack::at(blackjack_contract).player_hit(0).call(&mut env.private());

    //hit split hand
    env.impersonate(player);
    BlackJack::at(blackjack_contract).player_hit(1).call(&mut env.private());

    //get the hands, shared mutable flags should be triggered, it is not
    let player_hand = BlackJack::at(blackjack_contract).player_hand().view(&mut env.private());
    let split_hand = BlackJack::at(blackjack_contract).get_split_hand().view(&mut env.private());

    println(f"Player hand: {player_hand}");
    println(f"Split hand: {split_hand}");

    //stand
    env.impersonate(player);
    BlackJack::at(blackjack_contract).player_stand().call(&mut env.private());
}

#[test]
unconstrained fn split_double_down() {
    //happy path
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //make a bet
    env.impersonate(player);
    BlackJack::at(blackjack_contract).make_bet(10, token_address).call(&mut env.private());
    env.advance_block_by(1);

    add_card_note_player(env, blackjack_contract, player, 10, 0);
    add_card_note_player(env, blackjack_contract, player, 10, 0);
    env.advance_block_by(1);

    //split
    env.impersonate(player);
    BlackJack::at(blackjack_contract).split().call(&mut env.private());
    env.advance_block_by(1);

    //does not work as reading the bet storage too much
    //double down
    env.impersonate(player);
    BlackJack::at(blackjack_contract).double_down().call(&mut env.private());
}

#[test(should_fail)]
unconstrained fn split_fail() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //make a bet
    env.impersonate(player);
    BlackJack::at(blackjack_contract).make_bet(10, token_address).call(&mut env.private());
    env.advance_block_by(1);

    add_card_note_player(env, blackjack_contract, player, 1, 0);
    add_card_note_player(env, blackjack_contract, player, 2, 0);
    env.advance_block_by(1);

    //split
    env.impersonate(player);
    BlackJack::at(blackjack_contract).split().call(&mut env.private());
}

#[test(should_fail)]
unconstrained fn split_fail_no_bet() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    add_card_note_player(env, blackjack_contract, player, 1, 0);
    add_card_note_player(env, blackjack_contract, player, 1, 0);
    env.advance_block_by(1);

    //split
    env.impersonate(player);
    BlackJack::at(blackjack_contract).split().call(&mut env.private());
}

//the sharedmutable flags im using do not seem to be getting triggered
