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
    let blackjack_deploy = env.deploy_self("BlackJack").with_public_void_initializer(initializer);
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
