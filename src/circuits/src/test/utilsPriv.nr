use crate::BlackJack;
use crate::notes::CardNote::{Card, CardNote, Deck};
use dep::address_note::address_note::AddressNote;
use dep::aztec::note::note_getter::view_notes;
use dep::aztec::note::note_viewer_options::NoteViewerOptions;
use dep::aztec::{
    oracle::{
        execution::{get_block_number, get_contract_address},
        random::random,
        storage::storage_read,
    },
    prelude::{AztecAddress, NoteHeader},
    protocol_types::storage::map::derive_storage_slot_in_map,
    test::helpers::{cheatcodes, test_environment::TestEnvironment},
};
use dep::std::println;
use dep::token::Token;
use dep::uint_note::uint_note::UintNote;
use dep::value_note::value_note::ValueNote;
use std::test::OracleMock;

pub unconstrained fn setupPriv() -> (&mut TestEnvironment, AztecAddress, AztecAddress, AztecAddress) {
    let mut env = TestEnvironment::new();
    let player = env.create_account();
    env.impersonate(player);

    let initializer = BlackJack::interface().constructor();
    let blackjack_deploy = env.deploy_self("BlackJack").with_private_initializer(initializer);
    let blackjack_address = blackjack_deploy.to_address();

    //setup the token here
    env.impersonate(player);
    let initializer_call_interface = Token::interface().constructor(
        player,
        "TestToken0000000000000000000000",
        "TT00000000000000000000000000000",
        18,
    );

    let token_contract =
        env.deploy_self("Token").with_public_void_initializer(initializer_call_interface);
    println(f"contract deployed");
    let token_address = token_contract.to_address();
    println(f"token address {token_address}");

    (&mut env, player, blackjack_address, token_address)
}

pub unconstrained fn tokenSetup(
    env: &mut TestEnvironment,
    blackjack_address: AztecAddress,
    player: AztecAddress,
) -> AztecAddress {
    env.impersonate(player);
    println(f"setup player {player}");

    println(f"deploying contract");
    //deploy the token contract
    let initializer_call_interface = Token::interface().constructor(
        player,
        "TestToken0000000000000000000000",
        "TT00000000000000000000000000000",
        18,
    );

    let token_contract =
        env.deploy_self("Token").with_public_void_initializer(initializer_call_interface);
    println(f"contract deployed");
    let token_contract_address = token_contract.to_address();
    println(f"token address mint {token_contract_address}");
    env.advance_block_by(1);

    //now need to mint to the player
    let mint_amount = 1000;
    println(f"minting to player");
    //failing here
    env.impersonate(player);
    // Token::at(token_contract_address).mint_to_private(player, mint_amount).call(&mut env.private());
    println(f"minted to player");

    (token_contract_address)
}

