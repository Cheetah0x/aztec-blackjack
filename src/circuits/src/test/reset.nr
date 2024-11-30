use crate::BlackJack;
use crate::notes::CardNote::{Card, CardNote, Deck};
use crate::test::utilsPriv::setupPriv;
use dep::std::println;
use dep::token::Token;

#[test]
unconstrained fn reset() {
    //happy path
    let (mut env, player, blackjack_contract, token_address) = setupPriv();

    //player makes a bet
    env.impersonate(player);
    BlackJack::at(blackjack_contract).make_bet(10, token_address).call(&mut env.private());
    env.advance_block_by(1);

    //begin the game
    env.impersonate(player);
    BlackJack::at(blackjack_contract).begin_game().call(&mut env.private());
    env.advance_block_by(1);

    //player stands
    env.impersonate(player);
    BlackJack::at(blackjack_contract).player_stand().call(&mut env.private());
    env.advance_block_by(1);
    //reset the game
    env.impersonate(player);
    BlackJack::at(blackjack_contract).reset_game().call(&mut env.private());
    env.advance_block_by(1);
    //check that the game state is 0
    env.impersonate(blackjack_contract);
    let unconstrained_context = env.unkonstrained();
    let storage = BlackJack::Storage::init(unconstrained_context);
    let game_state = storage.game_state.at(player).get_current_value() as u8;
    println(f"Game state: {game_state}");
    assert(game_state == 0, "Game is not in progress");
    //player_bust
    let player_bust =
        BlackJack::at(blackjack_contract).is_player_bust_view().view(&mut env.public());
    println(f"Player bust: {player_bust}");
    assert(player_bust == false, "Player is bust");
    //dealer_bust
    let dealer_bust =
        BlackJack::at(blackjack_contract).is_dealer_bust_view().view(&mut env.public());
    println(f"Dealer bust: {dealer_bust}");
    assert(dealer_bust == false, "Dealer is bust");
    //blackjack
    let blackjack = BlackJack::at(blackjack_contract).is_blackjack_view().view(&mut env.public());
    println(f"Blackjack: {blackjack}");
    assert(blackjack == false, "Blackjack is not in progress");
    //bet
    let bet = storage.bet.at(player).view_note().value as u64;
    println(f"Bet: {bet}");
    // assert(bet == 0, "Bet is not 0");
    //token
    let token = storage.token.at(player).view_note().address;
    println(f"Token: {token}");
    assert(token == token_address, "Token is not correct");
}
