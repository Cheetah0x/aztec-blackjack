use crate::BlackJack;
use crate::notes::CardNote::{Card, CardNote, Deck};
use crate::test::utilsPriv::{setupPriv, add_card_note_player, add_card_note_dealer, check_bet};
use dep::aztec::note::note_viewer_options::NoteViewerOptions;
use dep::std::println;
use dep::token::Token;

#[test]
unconstrained fn player_hit() {
    //happy path
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //bet
    env.impersonate(player);
    BlackJack::at(blackjack_contract).make_bet(10, token_address).call(&mut env.private());
    env.advance_block_by(1);
    //begin game
    env.impersonate(player);
    BlackJack::at(blackjack_contract).begin_game().call(&mut env.private());
    // player hit
    BlackJack::at(blackjack_contract).player_hit(0).call(&mut env.private());

    // check player has 3 cards
    env.impersonate(blackjack_contract);
    let unconstrained_context = env.unkonstrained();
    let storage = BlackJack::Storage::init(unconstrained_context);
    let player_hand = storage.player_hand.at(player);
    let player_cards = player_hand.view_notes(NoteViewerOptions::new());
    assert(player_cards.len() == 3, "Player does not have 3 cards in their hand");
}

#[test(should_fail)]
unconstrained fn player_hit_one_card() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //bet
    env.impersonate(player);
    BlackJack::at(blackjack_contract).make_bet(10, token_address).call(&mut env.private());
    env.advance_block_by(1);
    //add card player
    add_card_note_player(env, blackjack_contract, player, 1, 0);
    //add card dealer
    add_card_note_dealer(env, blackjack_contract, player, 1, 0);

    //player hit
    env.impersonate(player);
    BlackJack::at(blackjack_contract).player_hit(0).call(&mut env.private());
}

#[test(should_fail)]
unconstrained fn player_hit_no_cards() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //bet
    env.impersonate(player);
    BlackJack::at(blackjack_contract).make_bet(10, token_address).call(&mut env.private());
    env.advance_block_by(1);

    //player hit
    env.impersonate(player);
    BlackJack::at(blackjack_contract).player_hit(0).call(&mut env.private());
}

#[test(should_fail)]
unconstrained fn player_hit_no_bet() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //begin game
    env.impersonate(player);
    BlackJack::at(blackjack_contract).begin_game().call(&mut env.private());

    //player hit
    env.impersonate(player);
    BlackJack::at(blackjack_contract).player_hit(0).call(&mut env.private());
}

#[test(should_fail)]
unconstrained fn player_hit_dealer_no_card() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //bet
    env.impersonate(player);
    BlackJack::at(blackjack_contract).make_bet(10, token_address).call(&mut env.private());
    env.advance_block_by(1);
    //add player card
    add_card_note_player(env, blackjack_contract, player, 1, 0);
    add_card_note_player(env, blackjack_contract, player, 1, 0);

    //player hit
    env.impersonate(player);
    BlackJack::at(blackjack_contract).player_hit(0).call(&mut env.private());
}

#[test(should_fail)]
unconstrained fn player_hit_dealer_two_cards() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //bet
    env.impersonate(player);
    BlackJack::at(blackjack_contract).make_bet(10, token_address).call(&mut env.private());
    env.advance_block_by(1);

    //begin game
    env.impersonate(player);
    BlackJack::at(blackjack_contract).begin_game().call(&mut env.private());

    //add dealer card
    add_card_note_dealer(env, blackjack_contract, player, 5, 0);

    //player hit
    env.impersonate(player);
    BlackJack::at(blackjack_contract).player_hit(0).call(&mut env.private());
}

#[test]
unconstrained fn player_hit_double_downed() {
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //bet
    env.impersonate(player);
    BlackJack::at(blackjack_contract).make_bet(10, token_address).call(&mut env.private());
    env.advance_block_by(1);

    add_card_note_player(env, blackjack_contract, player, 4, 0);
    add_card_note_dealer(env, blackjack_contract, player, 1, 0);
    add_card_note_player(env, blackjack_contract, player, 5, 0);

    //double down
    env.impersonate(player);
    BlackJack::at(blackjack_contract).double_down().call(&mut env.private());

    //player hit
    env.impersonate(player);
    BlackJack::at(blackjack_contract).player_hit(0).call(&mut env.private());
}

