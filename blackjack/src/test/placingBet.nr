use crate::BlackJack;
use crate::notes::CardNote::{Card, CardNote, Deck};
use dep::address_note::address_note::AddressNote;
use dep::aztec::note::note_getter::view_notes;
use dep::aztec::note::note_viewer_options::NoteViewerOptions;
use dep::aztec::{
    oracle::random::random,
    prelude::AztecAddress,
    test::helpers::{cheatcodes, test_environment::TestEnvironment},
};
use dep::std::println;
use crate::test::utilsPriv::{setupPriv, tokenSetup};
use dep::token::Token;
use dep::uint_note::uint_note::UintNote;



//in the real world we will assume that the token is already deployed,
//here we will have to deploy it first

// #[test]
// unconstrained fn placingBet() {
//     let (mut env, player, blackjack_contract) = setupPriv();

//     println(f"player {player}");
//     println(f"blackjack_contract {blackjack_contract}");

//     //need to deploy the token first
//     let token_address = tokenSetup(env, player, blackjack_contract);
//     println(f"token address: {token_address}" );

//     // // check the users balance of the token
//     // env.impersonate(token_address);
//     // let unconstrained_context = env.unkonstrained();
//     // let storage = Token::Storage::init(unconstrained_context);
//     // let balance = storage.balances.at(player).balance_of();

//     // println(f"balance: {balance}");

//     // //will do it the hardway
   

//     // println(f"balance: {balance}");

//     // //now we can make the bet
//     // env.impersonate(player);
//     // BlackJack::at(blackjack_contract).make_bet(10, token_address).call(&mut env.private());
//     // println("bet made");

//     env.advance_block_by(1);

//     //get the balance of the contract
// }


//TODO:: ISSUE, the current token contract is too big for the tests, this is the error that i get
//something about the max size being 3000, and it is like 3500