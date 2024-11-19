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
use dep::token::Token;


pub unconstrained fn setupPriv() -> (&mut TestEnvironment, AztecAddress, AztecAddress) {
    let mut env = TestEnvironment::new();
    let player = env.create_account();
    env.impersonate(player);

    let initializer = BlackJack::interface().constructor(player);
    let blackjack_deploy = env.deploy_self("BlackJack").with_private_initializer(initializer);

    (&mut env, player, blackjack_deploy.to_address())
}

pub unconstrained fn tokenSetup(
    env: &mut TestEnvironment,
    blackjack_address: AztecAddress,
    player: AztecAddress
    ) -> AztecAddress {

    env.impersonate(player);

    println(f"deploying contract");
    //deploy the token contract
    let initializer_call_interface = Token::interface().constructor(
        player,
        "TestToken0000000000000000000000",
        "TT00000000000000000000000000000",
        18,
    );

    let token_contract = env.deploy_self("Token").with_public_void_initializer(initializer_call_interface);
    println(f"contract deployed");
    let token_contract_address = token_contract.to_address();
    println(f"token address mint {token_contract_address}");
    env.advance_block_by(1);

    //now need to mint to the player
    let mint_amount = 1000;
    println(f"minting to player");
    //failing here
    env.impersonate(player);
    Token::at(token_contract_address).mint_to_private(player, mint_amount).call(&mut env.private());
    println(f"minted to player");

    (token_contract_address)
}

#[test]
unconstrained fn playerStorage() {
    let (mut env, player, blackjack_contract) = setupPriv();

    env.impersonate(blackjack_contract);

    let unconstrained_context = env.unkonstrained();

    let storage = BlackJack::Storage::init(unconstrained_context);

    let player_storage: AddressNote = storage.player_address.view_note();

    let player_address = player_storage.address;

    assert(player_address == player, "Player address does not match");
}

#[test]
unconstrained fn beginGame() {
    let (mut env, player, blackjack_contract) = setupPriv();

    env.impersonate(player);

    let begin_game = BlackJack::at(blackjack_contract).begin_game(player).call(&mut env.private());

    println(f"Begin game: {begin_game}");

    //get the card from storage
    env.impersonate(blackjack_contract);
    let unconstrained_context = env.unkonstrained();
    let storage = BlackJack::Storage::init(unconstrained_context);
    let options = NoteViewerOptions::new();

    //for the player hand
    let cards: BoundedVec<CardNote, 10> = storage.player_hand.at(player).view_notes(options);
    let mut player_cards = Vec::new();
    let mut card_count = 0;

    for i in 0..cards.len() {
        let card_used = cards.get_unchecked(i);
        let card_note_dets = card_used.card;
        player_cards.push(card_note_dets);
        card_count += 1;
    }

    //for the dealer hand
    let cards: BoundedVec<CardNote, 10> = storage.dealer_hand.view_notes(options);
    let mut dealer_cards = Vec::new();

    for i in 0..cards.len() {
        let card_used = cards.get_unchecked(i);
        let card_note_dets = card_used.card;
        dealer_cards.push(card_note_dets);
        card_count += 1;
    }

    println(f"Player cards: {player_cards}");
    println(f"Dealer cards: {dealer_cards}");
    println(f"Card count: {card_count}");

    //check the points of the dealer and the player
    let player_points =
        BlackJack::at(blackjack_contract).player_points(player).view(&mut env.private());
    let dealer_points = BlackJack::at(blackjack_contract).dealer_points().view(&mut env.private());

    println(f"Player points: {player_points}");
    println(f"Dealer points: {dealer_points}");

    //now need to hit
    env.impersonate(player);
    let hit = BlackJack::at(blackjack_contract).player_hit(player).call(&mut env.private());

    env.advance_block_by(1);

    //read the player hand again
    // After hitting, re-fetch the player's hand
    env.impersonate(blackjack_contract);
    let cards: BoundedVec<CardNote, 10> = storage.player_hand.at(player).view_notes(options);
    let mut player_cards2 = Vec::new();
    let mut card_count = 0;

    for i in 0..cards.len() {
        let card_used = cards.get_unchecked(i);
        let card_note_dets = card_used.card;
        player_cards2.push(card_note_dets);
        card_count += 1;
    }

    // Print the updated player cards
    println(f"Updated Player cards: {player_cards2}");

    //check what these add to
    let player_points =
        BlackJack::at(blackjack_contract).player_points(player).view(&mut env.private());

    println(f"Player points: {player_points}");

    //now check if bust, have to read from storage
    env.advance_block_by(1);
    env.impersonate(blackjack_contract);
    let is_bust = BlackJack::at(blackjack_contract).is_player_bust_view().view(&mut env.public());
    println(f"Is bust: {is_bust}");

    //add the test for when the player stands
    env.impersonate(player);
    let win = BlackJack::at(blackjack_contract).player_stand(player).call(&mut env.private());
    println(f"Win: {win}");
    //get the dealer cards
    env.impersonate(blackjack_contract);
    let deal_cards2: BoundedVec<CardNote, 10> = storage.dealer_hand.view_notes(options);
    let mut dealer_cards2 = Vec::new();
    let mut dealer_card_count = 0;

    for i in 0..cards.len() {
        let card_used = deal_cards2.get_unchecked(i);
        let card_note_dets = card_used.card;
        dealer_cards2.push(card_note_dets);
        dealer_card_count += 1;
    }
    println(f"Dealer card2s: {dealer_cards2}");
    println(f"dealer card count 2 {dealer_card_count}");

    env.impersonate(player);
    //get the dealer points
    let dealerpoints2 = BlackJack::at(blackjack_contract).dealer_points().view(&mut env.private());
    println(f"dealerPoints2 {dealerpoints2}");

    //see if the dealer is bust or not
    let dealer_bust =
        BlackJack::at(blackjack_contract).is_dealer_bust_view().view(&mut env.public());
    println(f"dealer bust {dealer_bust}");
}

//next i need to add the player hit function.

//isolated test to make sure the value does not go above 10 for the rank
#[test]
unconstrained fn cardValue() {
    for _ in 0..10 {
        let random_one = unsafe { random() };
        let value_bytes: [u8; 32] = random_one.to_le_bytes();
        let rank = (((value_bytes[0] as u32) + (value_bytes[1] as u32) * 256) % 13) + 1;
        let suit = ((value_bytes[2] as u32) + (value_bytes[3] as u32) * 256) % 4;

        let mut card_value = if rank > 10 { 10 } else { rank };

        assert(card_value <= 10, "Card value is greater than 10");
        // println(f"Card value: {card_value}");
    }
}
