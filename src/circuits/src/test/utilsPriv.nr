use crate::BlackJack;
use crate::notes::CardNote::{Card, CardNote, Deck};
use dep::address_note::address_note::AddressNote;
use dep::aztec::note::note_getter::view_notes;
use dep::aztec::note::note_viewer_options::NoteViewerOptions;
use dep::aztec::{
    oracle::{
        execution::{get_block_number, get_contract_address}, random::random, storage::storage_read,
    }, prelude::{AztecAddress, NoteHeader},
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
    token_address: AztecAddress,
    player: AztecAddress,
) {
    env.impersonate(player);

    //now need to mint to the player
    let mint_amount = 1000;
    println(f"minting to player");
    //failing here
    env.impersonate(player);

    mint_to_private(env, token_address, player, mint_amount);

    let player_balance = check_private_balance(token_address, player, mint_amount);
    println(f"player balance: {player_balance}");
}

pub unconstrained fn check_private_balance(
    token_contract_address: AztecAddress,
    address: AztecAddress,
    address_amount: Field,
) {
    let current_contract_address = get_contract_address();
    cheatcodes::set_contract_address(token_contract_address);
    // Direct call to unconstrained
    let balance_of_private = Token::balance_of_private(address);
    let balance = balance_of_private as u64;
    // assert(balance_of_private == address_amount, "Private balance is not correct");
    println(f"Private balance: {balance}");
    cheatcodes::set_contract_address(current_contract_address);
}

pub unconstrained fn mint_to_private(
    env: &mut TestEnvironment,
    token_contract_address: AztecAddress,
    recipient: AztecAddress,
    amount: Field,
) {
    let note_randomness = random();
    let _ = OracleMock::mock("getRandomField").returns(note_randomness);

    let from = recipient; // we are setting from to recipient because of TODO(#9887)
    Token::at(token_contract_address).mint_to_private(from, recipient, amount).call(
        &mut env.private(),
    );

    add_token_note(
        env,
        token_contract_address,
        recipient,
        amount,
        note_randomness,
    );
}

pub unconstrained fn add_token_note(
    env: &mut TestEnvironment,
    token_contract_address: AztecAddress,
    owner: AztecAddress,
    amount: Field,
    note_randomness: Field,
) {
    // docs:start:txe_test_add_note
    let balances_owner_slot =
        derive_storage_slot_in_map(Token::storage_layout().balances.slot, owner);

    env.add_note(
        &mut UintNote {
            value: U128::from_integer(amount),
            owner: owner,
            randomness: note_randomness,
            header: NoteHeader::empty(),
        },
        balances_owner_slot,
        token_contract_address,
    );
    // docs:end:txe_test_add_note
}

