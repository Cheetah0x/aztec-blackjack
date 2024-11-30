mod helpers;
mod test;
mod notes;

use dep::aztec::macros::aztec;

#[aztec]
contract BlackJack {

    use crate::helpers::CardHelpersPrivate::{
        card_points, draw_card, draw_until_seventeen, is_blackjack,
    };
    use crate::notes::CardNote::{Card, CardNote, Deck};
    use crate::notes::ValueNote::ValueNote;
    use dep::address_note::address_note::AddressNote;
    use dep::authwit::auth::{
        assert_current_call_valid_authwit, assert_current_call_valid_authwit_public,
        compute_authwit_message_hash_from_call, set_authorized,
    };
    use dep::aztec::{
        context::{PrivateContext, PublicContext, UnconstrainedContext},
        encrypted_logs::encrypted_note_emission::{
            encode_and_encrypt_note, encode_and_encrypt_note_unconstrained,
        }, keys::getters::get_public_keys,
        macros::{functions::{initializer, internal, private, public, view}, storage::storage},
        note::lifecycle::destroy_note, oracle::random::random,
        prelude::{
            AztecAddress, FunctionSelector, Map, NoteGetterOptions, PrivateImmutable,
            PrivateMutable, PrivateSet, PublicImmutable, PublicMutable, SharedMutable,
        },
        note::{
            lifecycle::{create_note, destroy_note_unsafe}, note_emission::NoteEmission,
            note_getter::{get_note, view_notes}, note_interface::{NoteInterface, NullifiableNote},
            utils::compute_note_hash_for_read_request,
        }, state_vars::storage::Storage::get_storage_slot,
    };
    use dep::aztec::oracle::debug_log::{debug_log, debug_log_format};
    use dep::token::Token;
    // use dep::value_note::value_note::ValueNote;
    use aztec::note::note_viewer_options::NoteViewerOptions;

    global ZERO_ADDRESS: AztecAddress = AztecAddress::from_field(
        0x0000000000000000000000000000000000000000000000000000000000000000,
    );
    global CHANGE_AUTHORIZED_DELAY_BLOCKS: u32 = 1;
    global MIN_BET: u64 = 10;
    global MAX_BET: u64 = 100;

    //this is the version where we are not using the card deck. Have the assumptions laid out in the spec
    #[storage]
    struct Storage<Context> {
        player_hand: Map<AztecAddress, PrivateSet<CardNote, Context>, Context>,
        split_hand: Map<AztecAddress, PrivateSet<CardNote, Context>, Context>,
        dealer_hand: Map<AztecAddress, PrivateSet<CardNote, Context>, Context>,
        player_bust: Map<AztecAddress, SharedMutable<bool, CHANGE_AUTHORIZED_DELAY_BLOCKS, Context>, Context>, //should probs map this to the player address
        dealer_bust: Map<AztecAddress, SharedMutable<bool, CHANGE_AUTHORIZED_DELAY_BLOCKS, Context>, Context>,
        blackjack: Map<AztecAddress, SharedMutable<bool, CHANGE_AUTHORIZED_DELAY_BLOCKS, Context>, Context>,
        bet: Map<AztecAddress, PrivateMutable<ValueNote, Context>, Context>,
        split_bet: Map<AztecAddress, PrivateMutable<ValueNote, Context>, Context>,
        insurance: Map<AztecAddress, PrivateMutable<ValueNote, Context>, Context>,
        token: Map<AztecAddress, PrivateMutable<AddressNote, Context>, Context>,
        has_split: Map<AztecAddress, SharedMutable<bool, CHANGE_AUTHORIZED_DELAY_BLOCKS, Context>, Context>,
        double_down: Map<AztecAddress, SharedMutable<bool, CHANGE_AUTHORIZED_DELAY_BLOCKS, Context>, Context>,
        game_state: Map<AztecAddress, SharedMutable<Field, CHANGE_AUTHORIZED_DELAY_BLOCKS, Context>, Context>, //try without this for now
    }

    #[initializer]
    #[private]
    fn constructor() {}

    #[private]
    #[view]
    fn get_bet() -> u64 {
        let player = context.msg_sender();
        let bet = storage.bet.at(player).get_note().note.value as u64;
        bet
    }

    #[private]
    #[view]
    fn get_token() -> AztecAddress {
        let player = context.msg_sender();
        let token = storage.token.at(player).get_note().note.address;
        token
    }

    #[private]
    #[view]
    fn player_points() -> u8 {
        let player = context.msg_sender();
        let points = get_player_points(player);
        points as u8
    }

    #[private]
    #[view]
    fn split_points() -> u8 {
        let player = context.msg_sender();
        let points = get_split_points(player);
        points as u8
    }

    #[private]
    #[view]
    fn player_hand() -> [Card; 8] {
        let player = context.msg_sender();
        let location = storage.player_hand.at(player);
        let cards_vec = location.get_notes(NoteGetterOptions::new());
        let mut cards_array = [Card { rank: 0, suit: 0 }; 8];

        for i in 0..cards_vec.max_len() {
            if i < cards_vec.len() {
                let card = cards_vec.get_unchecked(i);
                cards_array[i] = card.card;
            }
        }

        cards_array
    }

    #[private]
    #[view]
    fn get_split_hand() -> [Card; 8] {
        let player = context.msg_sender();
        let location = storage.split_hand.at(player);
        let cards_vec = location.get_notes(NoteGetterOptions::new());
        let mut cards_array = [Card { rank: 0, suit: 0 }; 8];

        for i in 0..cards_vec.max_len() {
            if i < cards_vec.len() {
                let card = cards_vec.get_unchecked(i);
                cards_array[i] = card.card;
            }
        }

        cards_array
    }

    #[private]
    #[view]
    fn dealer_hand() -> [Card; 8] {
        let player_address = context.msg_sender();
        let location = storage.dealer_hand.at(player_address);
        let cards_vec = location.get_notes(NoteGetterOptions::new());
        let mut cards_array = [Card { rank: 0, suit: 0 }; 8];

        for i in 0..cards_vec.max_len() {
            if i < cards_vec.len() {
                let card = cards_vec.get_unchecked(i);
                cards_array[i] = card.card;
            }
        }

        cards_array
    }

    #[private]
    #[view]
    fn dealer_points() -> u8 {
        let player_address = context.msg_sender();
        let points = get_dealer_points(player_address);
        points as u8
    }

    #[public]
    #[view]
    fn is_player_bust_view() -> bool {
        let player = context.msg_sender();
        storage.player_bust.at(player).get_current_value()
    }

    #[public]
    #[view]
    fn is_dealer_bust_view() -> bool {
        let player = context.msg_sender();
        storage.dealer_bust.at(player).get_current_value()
    }

    #[public]
    #[view]
    fn is_blackjack_view() -> bool {
        let player = context.msg_sender();
        storage.blackjack.at(player).get_current_value()
    }

    #[public]
    #[view]
    fn contract_address() -> AztecAddress {
        context.this_address()
    }

    //TODO: currently a bug with calling other contract functionality
    #[private]
    fn make_bet(bet: Field, token: AztecAddress) {
        let player = context.msg_sender();
        let contract_address = context.this_address();

        // CHECKS (validate state and inputs)
        // 1. Input validation
        assert(bet as u64 >= MIN_BET, "Bet must be greater than 10");
        assert(bet as u64 <= MAX_BET, "Bet must be less than 100");
        assert(token != ZERO_ADDRESS, "Invalid token address");

        // EFFECTS (modify state)
        let player_keys = get_public_keys(player);

        // 1. Store token address
        let mut token_note = AddressNote::new(token, player);
        storage.token.at(player).initialize(&mut token_note).emit(encode_and_encrypt_note(
            &mut context,
            player_keys.ovpk_m,
            player,
            player,
        ));

        // 2. Store bet amount
        let mut bet_note = ValueNote::new(bet, player);
        storage.bet.at(player).initialize(&mut bet_note).emit(encode_and_encrypt_note(
            &mut context,
            player_keys.ovpk_m,
            player,
            player,
        ));
        // INTERACTIONS (external calls)
        // 1. Authenticate transfer (commented out for now)
        // assert_current_call_valid_authwit(&mut context, player);
        // 2. Transfer tokens (commented out for now)
        // Token::at(token).transfer_in_private(player, contract_address, bet, 0)
        //     .call(&mut context);
    }

    #[private]
    fn place_insurance_bet() {
        let player = context.msg_sender();
        let contract_address = context.this_address();

        // CHECKS (validate state and inputs)
        // 1. Game state validation
        let game_state = storage.game_state.at(player).get_current_value() as u8;
        assert(game_state == 1, "Game is not in progress");

        // 2. Bet validation
        let bet = storage.bet.at(player).get_note().note.value as u64;
        assert(bet > 0, "No existing bet found");
        let insurance_bet = (bet / 2) as Field;

        // 3. Dealer card validation
        let options = NoteGetterOptions::new();
        let location = storage.dealer_hand.at(player);
        let dealer_cards = location.get_notes(options);
        assert(dealer_cards.len() == 1, "Dealer does not have 1 card in their hand");
        let first_card = dealer_cards.get_unchecked(0);
        assert(first_card.card.rank == 1, "Dealer does not have an ace");

        // EFFECTS (modify state)
        // Can't initialize twice so protects from double insurance
        let player_keys = get_public_keys(player);
        let mut insurance_note = ValueNote::new(insurance_bet, player);
        storage.insurance.at(player).initialize(&mut insurance_note).emit(encode_and_encrypt_note(
            &mut context,
            player_keys.ovpk_m,
            player,
            player,
        ));
        // INTERACTIONS (external calls)
        // let token = storage.token.at(player).get_note().note.address;
        // Token::at(token).transfer(contract_address, insurance_bet).call(&mut context);
    }

    //TODO:check the game is not already in progress
    //TODO: Race conditions, prevent player from calling this multiple times before finishing the game
    //TODO: Could emit events that the game has started
    #[private]
    fn begin_game() {
        let player = context.msg_sender();
        let contract_address = context.this_address();

        // CHECKS (validate state and inputs)
        // 1. Verify bet exists
        let bet = storage.bet.at(player).get_note().note.value as u64;
        assert(bet > 0, "No bet made");

        // 2. Verify game isn't already in progress
        let game_state = storage.game_state.at(player).get_current_value() as u8;
        assert(game_state == 0, "Game already in progress");

        // 3. Verify player doesn't already have cards
        let player_hand = storage.player_hand.at(player).get_notes(NoteGetterOptions::new());
        assert(player_hand.len() == 0, "Player already has cards");

        // EFFECTS (modify state)
        let location = storage.player_hand.at(player);

        // 1. Draw initial cards
        for i in 0..2 {
            draw_card(player, location, &mut context);
        }

        // 2. Check for blackjack
        let is_blackjack = is_blackjack(player, location);
        if is_blackjack {
            BlackJack::at(contract_address).blackjack(true).enqueue(&mut context);
        }

        // 3. Draw dealer card
        draw_card(player, storage.dealer_hand.at(player), &mut context);

        // 4. Update game state
        BlackJack::at(contract_address).game_state(1).enqueue(&mut context);
    }

    //logic for double down
    #[private]
    fn double_down() {
        let player = context.msg_sender();
        let contract_address = context.this_address();

        // CHECKS (validate state and inputs)
        // 1. Game state checks
        // let game_state = storage.game_state.at(player).get_current_value() as u8;
        // assert(game_state == 1, "Game not in progress");
        // 2. Double down eligibility checks
        let double_downed = storage.double_down.at(player).get_current_value();
        assert(!double_downed, "Already doubled down");

        // 3. Points validation
        let player_points = card_points(storage.player_hand.at(player));
        assert(player_points >= 9 & player_points <= 11, "Can only double down on 9,10 or 11");

        // 4. Bet validation
        let slot = storage.bet.at(player).get_storage_slot();
        let (bet_note, note_hash_for_read_request): (ValueNote, Field) =
            get_note(&mut context, slot);
        let bet_value = bet_note.value as u64;
        assert(bet_value > 0, "No existing bet found");

        // EFFECTS (modify state)
        // 1. Update bet amount
        let player_keys = get_public_keys(player);
        let mut new_bet_note = ValueNote::new((bet_value * 2) as Field, player);
        destroy_note_unsafe(&mut context, bet_note, note_hash_for_read_request);
        create_note(&mut context, slot, &mut new_bet_note).emit(encode_and_encrypt_note(
            &mut context,
            player_keys.ovpk_m,
            player,
            player,
        ));

        // 2. Draw additional card
        draw_card(player, storage.player_hand.at(player), &mut context);

        // 3. Update double down status (only once)
        BlackJack::at(contract_address).update_double_down(true).enqueue(&mut context);
        // INTERACTIONS (external calls)
        // let token = storage.token.at(player).get_note().note.address;
        // Token::at(token).transfer_in_private(player, contract_address, bet_value as Field, 0).call(&mut context);
    }

    //split
    #[private]
    fn split() {
        let player = context.msg_sender();
        let contract_address = context.this_address();

        // CHECKS (validate state and inputs)
        // 1. Game state checks
        // let game_state = storage.game_state.at(player).get_current_value() as u8;
        // assert(game_state == 1, "Game not in progress");
        // 2. Split eligibility checks
        let has_already_split = storage.has_split.at(player).get_current_value();
        assert(!has_already_split, "Player has already split");

        //retrieve the player hand
        let player_hand_location = storage.player_hand.at(player);
        let player_hand_notes = player_hand_location.get_notes(NoteGetterOptions::new());
        assert(player_hand_notes.len() == 2, "Player does not have 2 cards in their hand");

        // 4. Card rank check
        let first_card_rank = player_hand_notes.get_unchecked(0).card.rank as u64;
        let second_card = player_hand_notes.get_unchecked(1);
        let second_card_rank = second_card.card.rank as u64;
        assert(first_card_rank == second_card_rank, "Cards are not of the same rank");

        // 5. Bet validation
        let bet = storage.bet.at(player).get_note().note.value as u64;
        assert(bet > 0, "No existing bet found");

        // EFFECTS (modify state)
        let player_keys = get_public_keys(player);
        let split_hand_location = storage.split_hand.at(player);

        // 1. Create split hand
        let mut split_card_note = CardNote::new(second_card.card, player);
        split_hand_location.insert(&mut split_card_note).emit(encode_and_encrypt_note(
            &mut context,
            player_keys.ovpk_m,
            player,
            player,
        ));

        // 2. Remove card from original hand
        let second_card_note_hash = compute_note_hash_for_read_request(second_card);
        destroy_note_unsafe(&mut context, second_card, second_card_note_hash);

        // 3. Create split bet note
        let mut split_bet_note = ValueNote::new(bet as Field, player);
        storage.split_bet.at(player).initialize(&mut split_bet_note).emit(encode_and_encrypt_note(
            &mut context,
            player_keys.ovpk_m,
            player,
            player,
        ));

        // 4. Update split status]
        BlackJack::at(contract_address).has_split(true).enqueue(&mut context);
        // INTERACTIONS (external calls)
        //TODO: get authwit
        // let token = storage.token.at(player).get_note().note.address;
        // Token::at(token).transfer_in_private(player, contract_address, bet as Field, 0).call(
        //     &mut context,
        // );
    }

    //TODO: check that the player has not doubled down, urgent
    //TODO: ensure the player is allowed to hit,( not doubled down)
    //TODO: event emission??
    #[private]
    fn player_hit(hand: u64) {
        let player = context.msg_sender();
        let contract_address = context.this_address();

        // CHECKS (validate state and inputs)
        // 1. Input validation
        assert((hand == 0) | (hand == 1), "Invalid hand parameter");

        // 2. Game state validation
        // let game_state = storage.game_state.at(player).get_current_value() as u8;
        // assert(game_state == 1, "Game not in progress");
        // 3. Double down validation
        let double_downed = storage.double_down.at(player).get_current_value();
        assert(!double_downed, "Player has already doubled down");

        // 4. Hand validation
        let has_split = storage.has_split.at(player).get_current_value();
        let mut location = storage.player_hand.at(player);
        if hand == 1 {
            assert(has_split, "Cannot hit on split hand when not split");
            location = storage.split_hand.at(player);
        }

        // 5. Card count validation
        let player_cards = location.get_notes(NoteGetterOptions::new());
        if (hand == 0) & !has_split {
            assert(player_cards.len() >= 2, "Player does not have at least 2 cards in their hand");
        } else if hand == 1 {
            assert(player_cards.len() >= 1, "Player does not have at least 1 card in split hand");
        }

        // 6. Dealer validation
        let dealer_cards = storage.dealer_hand.at(player).get_notes(NoteGetterOptions::new());
        assert(dealer_cards.len() == 1, "Dealer does not have 1 card in their hand");

        // EFFECTS (modify state)
        // 1. Draw new card
        draw_card(player, location, &mut context);

        // 2. Check for bust
        let points = card_points(location);
        if points > 21 {
            // INTERACTIONS (external calls)
            BlackJack::at(contract_address).is_player_bust(true).enqueue(&mut context);
        }
    }

    //TODO: reset the game state after the game ends, instead of calling the reset function. would be nice if this was separate, but may have to be included
    //TODO: Race conditions, prevent player from calling this multiple times before finishing the game
    //TODO: make sure dealer hands are private until they need to be shown.
    #[private]
    fn player_stand() {
        let player = context.msg_sender();
        let contract_address = context.this_address();

        // CHECKS (validate state and inputs)
        // 1. Game state validation
        // let game_state = storage.game_state.at(player).get_current_value() as u8;
        // assert(game_state == 1, "Game is not in progress");
        // 2. Hand validation
        let player_hand = storage.player_hand.at(player);
        let player_cards = player_hand.get_notes(NoteGetterOptions::new());
        assert(player_cards.len() >= 2, "Player does not have 2 cards in their hand");

        // 3. Split hand validation
        let has_split = storage.has_split.at(player).get_current_value();
        let mut split_points: u64 = 0;
        if has_split {
            let split_hand = storage.split_hand.at(player);
            let split_cards = split_hand.get_notes(NoteGetterOptions::new());
            assert(split_cards.len() >= 2, "Player does not have 2 cards in their split hand");
            split_points = card_points(split_hand);
        }

        // 4. Dealer validation
        let dealer_cards = storage.dealer_hand.at(player).get_notes(NoteGetterOptions::new());
        assert(dealer_cards.len() == 1, "Dealer does not have 1 card in their hand");

        // 5. Bet validation
        // let bet = storage.bet.at(player).get_note().note.value as u64;
        // assert(bet > 0, "No bet notes found");
        // EFFECTS (modify state)
        // 1. Calculate points
        let player_points = card_points(player_hand);

        // 2. Draw dealer cards
        draw_card(player, storage.dealer_hand.at(player), &mut context);
        let mut dealer_points = card_points(storage.dealer_hand.at(player));

        // draw_until_seventeen(dealer_points, player, &mut context, storage.dealer_hand.at(player));
        //ok this dead ass worked once, try again, failed the second time, why is it failing
        if dealer_points < 17 {
            draw_card(player, storage.dealer_hand.at(player), &mut context);
            dealer_points = card_points(storage.dealer_hand.at(player));
        }
        // if dealer_points < 17 {
        //     draw_card(player, storage.dealer_hand.at(player), &mut context);
        //     dealer_points = card_points(storage.dealer_hand.at(player));
        // }
        //working with the one if statement, sometimes works with two, just super inconsistent
        //dealer bust
        let dealer_bust = dealer_points > 21;
        if dealer_bust {
            BlackJack::at(contract_address).is_dealer_bust(true).enqueue(&mut context);
        }

        // 4. Calculate win conditions
        let player_bust = player_points > 21;
        let split_bust = split_points > 21;
        let player_blackjack = storage.blackjack.at(player).get_current_value();
        let split_blackjack = has_split & is_blackjack(player, storage.split_hand.at(player));

        let player_wins_main = !player_bust & (player_points > dealer_points | dealer_bust);
        let player_ties_main = !player_bust & (player_points == dealer_points);
        let player_wins_split =
            has_split & !split_bust & (split_points > dealer_points | dealer_bust);
        let player_ties_split = has_split & !split_bust & (split_points == dealer_points);
        let win = player_wins_main | player_wins_split;
        let win_both = player_wins_main & player_wins_split;

        // Get bet amounts and token info
        // let bet = storage.bet.at(player).get_note().note.value;
        // let split_bet = storage.split_bet.at(player).get_note().note.value;
        // let token = storage.token.at(player).get_note().note.address;
        let player_keys = get_public_keys(player);
        // // Handle main hand payout
        if player_wins_main {
            if player_blackjack {
                // Blackjack pays 3:2
                // let blackjack_payout = (bet * 3) / 2;
                // Token::at(token).transfer_in_private(contract_address, player, blackjack_payout, 0).call(&mut context);
            } else {
                // Regular win pays 1:1
                // Token::at(token).transfer_in_private(contract_address, player, bet * 2, 0).call(&mut context);
            }
        } else if player_ties_main {
            // Return original bet on tie
            // Token::at(token).transfer_in_private(contract_address, player, bet, 0).call(&mut context);
        }

        // Handle split payouts if applicable
        if has_split {
            let split_bet = storage.split_bet.at(player).get_note().note.value;
            if player_wins_split {
                if split_blackjack {
                    // Blackjack pays 3:2
                    let split_blackjack_payout = (split_bet * 3) / 2;
                    // Token::at(token).transfer_in_private(contract_address, player, split_blackjack_payout, 0).call(&mut context);
                } else {
                    // Regular win pays 1:1
                    // Token::at(token).transfer_in_private(contract_address, player, split_bet * 2, 0).call(&mut context);
                }
            } else if player_ties_split {
                // Return original split bet on tie
                // Token::at(token).transfer_in_private(contract_address, player, split_bet, 0).call(&mut context);
            }
        }
        if win_both {
            //double payout
            // Token::at(token).transfer_in_private(contract_address, player, (bet + split_bet) * 2, 0).call(&mut context);
        }
        // Update game state
        // Game is now ended
        BlackJack::at(contract_address).game_state(2).enqueue(&mut context);
    }

    #[private]
    fn reset_game() {
        let player = context.msg_sender();
        let contract_address = context.this_address();

        // CHECKS (validate state and inputs)
        // 1. Game state validation
        // let game_state = storage.game_state.at(player).get_current_value() as u8;
        // assert(game_state == 2, "Game must be finished before resetting");
        // 2. Dealer hand validation
        let dealer_cards = storage.dealer_hand.at(player).get_notes(NoteGetterOptions::new());
        assert(dealer_cards.len() >= 2, "Dealer must have at least 2 cards");

        // EFFECTS (modify state)
        let options = NoteGetterOptions::new();

        // 1. Clear all hands
        storage.player_hand.at(player).pop_notes(options);
        storage.dealer_hand.at(player).pop_notes(options);
        storage.split_hand.at(player).pop_notes(options);

        // 2. Clear bet notes
        // TODO: Implement bet note clearing once note destruction is supported
        // let slot = storage.bet.at(player).get_storage_slot();
        // let player_keys = get_public_keys(player);
        // let (bet_note, note_hash_for_read_request): (ValueNote, Field) =
        //     get_note(&mut context, slot);
        // destroy_note_unsafe(&mut context, bet_note, note_hash_for_read_request);
        // create_note(&mut context, slot, &mut ValueNote::new(0, player)).emit(
        //     encode_and_encrypt_note(&mut context, player_keys.ovpk_m, player, player),
        // );
        // Reset game state flags
        let contract_address = context.this_address();
        BlackJack::at(contract_address).is_player_bust(false).enqueue(&mut context);
        BlackJack::at(contract_address).is_dealer_bust(false).enqueue(&mut context);
        BlackJack::at(contract_address).blackjack(false).enqueue(&mut context);
        BlackJack::at(contract_address).game_state(0).enqueue(&mut context);
        BlackJack::at(contract_address).has_split(false).enqueue(&mut context);
    }

    #[public]
    #[internal]
    fn game_state(state: Field) {
        let player = context.msg_sender();
        storage.game_state.at(player).schedule_value_change(state);
    }

    #[public]
    #[internal]
    fn has_split(has_split: bool) {
        let player = context.msg_sender();
        storage.has_split.at(player).schedule_value_change(has_split);
    }

    #[public]
    #[internal]
    fn update_double_down(has_double_downed: bool) {
        let player = context.msg_sender();
        storage.double_down.at(player).schedule_value_change(has_double_downed);
    }

    #[public]
    #[internal]
    fn is_player_bust(bust: bool) {
        let player = context.msg_sender();
        storage.player_bust.at(player).schedule_value_change(bust)
    }

    #[public]
    #[internal]
    fn is_dealer_bust(bust: bool) {
        let player = context.msg_sender();
        storage.dealer_bust.at(player).schedule_value_change(bust)
    }

    #[public]
    #[internal]
    fn blackjack(blackjack: bool) {
        let player = context.msg_sender();
        storage.blackjack.at(player).schedule_value_change(blackjack)
    }

    #[internal]
    unconstrained fn get_player_points(player: AztecAddress) -> pub u64 {
        let options = NoteViewerOptions::new();
        let location = storage.player_hand.at(player);
        let cards = location.view_notes(options);
        let mut points = 0;
        let mut aces = 0;

        for i in 0..cards.max_len() {
            if i < cards.len() {
                let note = cards.get_unchecked(i);
                let card = note.card;
                let rank_value = if card.rank > 10 { 10 } else { card.rank };
                if rank_value == 1 {
                    aces += 1;
                    points += 11; // Assume Ace is high initially
                } else {
                    points += rank_value;
                }
            }
        }

        // Adjust for Aces if points exceed 21
        if points > 21 & aces > 0 {
            points -= 10; // Make Ace low
            aces -= 1;
        }

        points as u64
    }

    #[internal]
    unconstrained fn get_dealer_points(player: AztecAddress) -> pub u64 {
        let options = NoteViewerOptions::new();
        let location = storage.dealer_hand.at(player);
        let cards = location.view_notes(options);
        let mut points = 0;
        let mut aces = 0;

        for i in 0..cards.max_len() {
            if i < cards.len() {
                let note = cards.get_unchecked(i);
                let card = note.card;
                let rank_value = if card.rank > 10 { 10 } else { card.rank };
                if rank_value == 1 {
                    aces += 1;
                    points += 11; // Assume Ace is high initially
                } else {
                    points += rank_value;
                }
            }
        }

        // Adjust for Aces if points exceed 21
        if points > 21 & aces > 0 {
            points -= 10; // Make Ace low
            aces -= 1;
        }

        points as u64
    }

    #[internal]
    unconstrained fn get_split_points(player: AztecAddress) -> pub u64 {
        let options: NoteViewerOptions<CardNote, 4> = NoteViewerOptions::new();
        let location: PrivateSet<CardNote, UnconstrainedContext> = storage.split_hand.at(player);
        let cards = location.view_notes(options);
        let mut points = 0;
        let mut aces = 0;
        for i in 0..cards.max_len() {
            if i < cards.len() {
                let note = cards.get_unchecked(i);
                let card = note.card;
                let rank_value = if card.rank > 10 { 10 } else { card.rank };
                if rank_value == 1 {
                    aces += 1;
                    points += 11; // Assume Ace is high initially
                } else {
                    points += rank_value;
                }
            }
        }
        // Adjust for Aces if points exceed 21
        if points > 21 & aces > 0 {
            points -= 10; // Make Ace low
            aces -= 1;
        }

        points as u64
    }
}

//Potential Issues
//TODO: Ensure all game state is reset and pruged.
//TODO: Prevent resetting of the game while it is in progress, need to add tests for this.
//TODO: event that the game has been reset

//this should be ok for now, need to do a check so the player can only stand if the have not lost.

//Things to do:
//1. Add the logic for the player to double down and split.
//will not add the split for now.
//2. Add the logic for the dealer to win.
//3. Add the logic for the player to win.
//4. Add the logic for the insurance.

//need to add the logic for betting, the contract till count as an escrow and will
//accept a standard ERC20 on aztec
//will need to integrate the token in the contract

//add the ole token for the payments next.

//need to get the authwit for this
// let selector = FunctionSelector::from_signature("transfer(Field,Field)");
// let message_hash = compute_authwit_message_hash_from_call(
//     token,
//     token,
//     context.chain_id(),
//     context.version(),
//     selector,
//     [contract_address.to_field(), bet],
// );

// set_authorized(&mut context, message_hash, true);

//something to do with the randomness now.

//TODO: need to update so u can stand for the separate hands.

