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

        //Validate bet amount against minumum and maximum limits
        assert(bet as u64 >= MIN_BET, "Bet must be greater than 10");
        assert(bet as u64 <= MAX_BET, "Bet must be less than 100");

        //get the player balance, assert that the player has enough balance
        // let player_balance = Token::balance_of_private(player);
        // assert(player_balance as u64 >= bet as u64, "Player does not have enough balance");
        //ensure the call is authenticated
        // assert_current_call_valid_authwit(&mut context, player);
        //transfer the token to the contract from the player
        // Token::at(token).transfer_in_private(player, contract_address, bet, 0).call(&mut context);
        //get the players keys
        let player_keys = get_public_keys(player);

        //add the token address to storage
        let mut token_note = AddressNote::new(token, player);
        storage.token.at(player).initialize(&mut token_note).emit(encode_and_encrypt_note(
            &mut context,
            player_keys.ovpk_m,
            player,
            player,
        ));

        //add the bet to storage
        let mut bet_note = ValueNote::new(bet, player);
        storage.bet.at(player).initialize(&mut bet_note).emit(encode_and_encrypt_note(
            &mut context,
            player_keys.ovpk_m,
            player,
            player,
        ));
    }

    #[private]
    fn place_insurance_bet() {
        let player = context.msg_sender();
        let contract_address = context.this_address();

        //check that the game is in progress
        let game_state = storage.game_state.at(player).get_current_value() as u8;
        assert(game_state == 1, "Game is not in progress");
        //get the token address and bet
        //these should fail if the bet has not been made
        let token = storage.token.at(player).get_note().note.address;
        let bet = storage.bet.at(player).get_note().note.value as u64;
        let insurance_bet = (bet / 2) as Field;

        let options = NoteGetterOptions::new();
        let location = storage.dealer_hand.at(player);
        let dealer_cards: BoundedVec<CardNote, 16> = location.get_notes(options);
        assert(dealer_cards.len() == 1, "Dealer does not have 1 card in their hand");
        let first_card = dealer_cards.get_unchecked(0);
        assert(first_card.card.rank == 1, "Dealer does not have an ace");

        let player_keys = get_public_keys(player);
        let mut insurance_note = ValueNote::new(insurance_bet, player);

        //Prevent multiple insurance bets, this is done with initialization
        storage.insurance.at(player).initialize(&mut insurance_note).emit(encode_and_encrypt_note(
            &mut context,
            player_keys.ovpk_m,
            player,
            player,
        ));
        // Token::at(token).transfer(contract_address, insurance_bet).call(&mut context);
    }

    //TODO:check the game is not already in progress
    //TODO: Race conditions, prevent player from calling this multiple times before finishing the game
    //TODO: Could emit events that the game has started
    #[private]
    fn begin_game() {
        //add logic that a game can only be started if the player has made a bet
        //1. will need to read the cards from the deck that are being used.
        //there is the limitation of only being able to fetch 16 at a time. This is a constraint we will have the mention
        //Other option is to have another storage/ loop for this to store the other cards in another vec.
        //2. will do this by fetching the notes of the cards and populating an array.
        //check if a bet has been made
        let player = context.msg_sender();
        let bet = storage.bet.at(player).get_note().note.value as u64;
        assert(bet > 0, "No bet made");
        let contract_address = context.this_address();
        let location = storage.player_hand.at(player);
        // let options = NoteGetterOptions::new();
        // let used_cards: BoundedVec<CardNote, 16> = storage.card_deck_used.get_notes(options);
        //3. Will need to draw the cards, can do this using random atm, 2 for the player, one for the dealer and add them to the hands.
        for i in 0..2 {
            draw_card(player, location, &mut context);
        }

        //check if it is blackjack
        let is_blackjack = is_blackjack(player, location);
        if is_blackjack {
            BlackJack::at(contract_address).blackjack(true).enqueue(&mut context);
        }
        //for the dealer card
        draw_card(player, storage.dealer_hand.at(player), &mut context);
        //initiate game state, now active, could be an event, skipping for now
        let state = 1;
        BlackJack::at(contract_address).game_state(state).enqueue(&mut context);
    }

    //logic for double down
    #[private]
    fn double_down() {
        let player = context.msg_sender();
        let contract_address = context.this_address();
        let player_keys = get_public_keys(player);
        let player_points = card_points(storage.player_hand.at(player));

        //check that the player has not already doubled down
        let double_downed = storage.double_down.at(player).get_current_value();
        assert(double_downed == false, "Player has already doubled down");

        if (player_points < 9) {
            assert(false, "Player can only double down on 9,10 or 11");
        }
        if (player_points > 11) {
            assert(false, "Player can only double down on 9,10 or 11");
        }

        //fetch the token address
        let token = storage.token.at(player).get_note().note.address;

        let slot = storage.bet.at(player).get_storage_slot();

        // let bet = storage.bet.at(player).get_note().note.value;
        let (bet_note, note_hash_for_read_request): (ValueNote, Field) =
            get_note(&mut context, slot);
        let bet_value = bet_note.value as u64;
        //then bet this again
        let mut new_bet_note = ValueNote::new((bet_value * 2) as Field, player);
        destroy_note_unsafe(&mut context, bet_note, note_hash_for_read_request);
        create_note(&mut context, slot, &mut new_bet_note).emit(encode_and_encrypt_note(
            &mut context,
            player_keys.ovpk_m,
            player,
            player,
        ));

        // //transfer the token
        // Token::at(token).transfer(player, bet).call(&mut context);
        //will need to think about this from a security standpoint, need to only update the balance if the transfer is successful
        //maybe have it in a loop so that the note only gets added if the transfer is successful
        //so the player has doubled the bet, now they continue the game as normal, put can only hit one more time
        BlackJack::at(contract_address).update_double_down(true).enqueue(&mut context);

        //draw a card
        draw_card(player, storage.player_hand.at(player), &mut context);

        //update the game state to reflect the double down
        BlackJack::at(contract_address).update_double_down(true).enqueue(&mut context);
    }

    //split
    #[private]
    fn split() {
        let player = context.msg_sender();
        let contract_address = context.this_address();

        //ensure the player has not already split
        let has_already_split = storage.has_split.at(player).get_current_value();
        assert(has_already_split == false, "Player has already split");

        //retrieve the player hand
        let player_hand_location = storage.player_hand.at(player);
        let player_hand_notes = player_hand_location.get_notes(NoteGetterOptions::new());
        assert(player_hand_notes.len() == 2, "Player does not have 2 cards in their hand");

        //check the two cards are of the same rank
        let first_card_rank = player_hand_notes.get_unchecked(0).card.rank as u64;
        let second_card = player_hand_notes.get_unchecked(1);
        let second_card_rank = second_card.card.rank as u64;
        assert(first_card_rank == second_card_rank, "Cards are not of the same rank");

        //new hand for split
        let split_hand_location = storage.split_hand.at(player);
        let player_keys = get_public_keys(player);

        //create the split hand
        let mut split_card_note = CardNote::new(second_card.card, player);
        split_hand_location.insert(&mut split_card_note).emit(encode_and_encrypt_note(
            &mut context,
            player_keys.ovpk_m,
            player,
            player,
        ));

        //remove the second card from the player hand
        let second_card_note_hash = compute_note_hash_for_read_request(second_card);
        destroy_note_unsafe(&mut context, second_card, second_card_note_hash);

        //Duplicate the original bet
        let bet = storage.bet.at(player).get_note().note.value as u64;

        //transfer the additional bet amount from the player to the contract
        let token = storage.token.at(player).get_note().note.address;
        //authwit
        // Token::at(token).transfer_in_private(player, contract_address, bet as Field, 0).call(
        //     &mut context,
        // );
        //then add the new bet to storage
        let mut split_bet_note = ValueNote::new(bet as Field, player);
        storage.split_bet.at(player).initialize(&mut split_bet_note).emit(encode_and_encrypt_note(
            &mut context,
            player_keys.ovpk_m,
            player,
            player,
        ));

        //update the split flag
        BlackJack::at(contract_address).has_split(true).enqueue(&mut context);
    }

    //TODO: check that the player has not doubled down, urgent
    //TODO: ensure the player is allowed to hit,( not doubled down)
    //TODO: event emission??
    #[private]
    fn player_hit(hand: u64) {
        //read the cards that have been used, will not do this for now.
        //get the player cards
        let player = context.msg_sender();
        let contract_address = context.this_address();
        let mut location = storage.player_hand.at(player);

        //check that the player has not doubled down
        let double_downed = storage.double_down.at(player).get_current_value();
        assert(double_downed == false, "Player has already doubled down");

        if hand == 1 {
            location = storage.split_hand.at(player);
        }

        //check that the player has cards in hand, do not need to check if the bet has been made
        //they can only have cards in their hand if that have already made a bet and started the game
        let player_cards = location.get_notes(NoteGetterOptions::new());
        if hand == 0 {
            assert(player_cards.len() >= 1, "Player does not have at least 1 card in their hand");
        }

        //make sure dealer has card
        let dealer_cards = storage.dealer_hand.at(player).get_notes(NoteGetterOptions::new());
        assert(dealer_cards.len() == 1, "Dealer does not have 1 card in their hand");

        draw_card(player, location, &mut context);

        let points = card_points(location);

        let mut bust = false;
        if points > 21 {
            bust = true;
            BlackJack::at(contract_address).is_player_bust(bust).enqueue(&mut context);
        }
    }

    //TODO: reset the game state after the game ends, instead of calling the reset function. would be nice if this was separate, but may have to be included
    //TODO: Race conditions, prevent player from calling this multiple times before finishing the game
    //TODO: make sure dealer hands are private until they need to be shown.
    #[private]
    fn player_stand() {
        //1.Get the player and contract addresses
        let player = context.msg_sender();
        let contract_address = context.this_address();

        //check that the game is in progress
        let game_state = storage.game_state.at(player).get_current_value() as u8;
        // assert(game_state == 1, "Game is not in progress");
        //2. Check the player has at least 2 cards in their hand
        let player_hand = storage.player_hand.at(player);
        let player_cards = player_hand.get_notes(NoteGetterOptions::new());
        assert(player_cards.len() >= 2, "Player does not have 2 cards in their hand");

        //check that the player has not split
        let has_split = storage.has_split.at(player).get_current_value();
        let mut split_points: u64 = 0;

        if has_split {
            let split_hand = storage.split_hand.at(player);
            let split_cards = split_hand.get_notes(NoteGetterOptions::new());
            assert(split_cards.len() >= 2, "Player does not have 2 cards in their split hand");

            split_points = card_points(split_hand);
        }

        //3. Check the dealer has 1 card in their hand
        let dealer_cards = storage.dealer_hand.at(player).get_notes(NoteGetterOptions::new());
        assert(dealer_cards.len() == 1, "Dealer does not have 1 card in their hand");

        //4. Check if bet notes exist before accessing, will need a bet anyway for the payout, this is being used somewhere
        // let bet = storage.bet.at(player).get_note().note.value as u64;
        // assert(bet > 0, "No bet notes found");
        // // 5. Get the token address, for the transfer later
        // let token = storage.token.at(player).get_note().note.address;
        //Get the current points for the dealer and the player
        let player_points = card_points(player_hand);

        //get split bet
        let mut split_bet = 0;
        if has_split {
            // split_bet = storage.split_bet.at(player).get_note().note.value;
        }

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
        // // Determine win conditions
        let player_bust = player_points > 21;
        let split_bust = split_points > 21;
        // Add this line to check for blackjack
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
        // Handle split hand payout if it exists
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
        //need to add assertions
        //dealer cards at least 2, this should be enough, the player stand will have to have been made, can only reset if the game has ended
        let player = context.msg_sender();

        //assert game state is 2
        let game_state = storage.game_state.at(player).get_current_value() as u8;
        // assert(game_state == 2, "Game is not in progress");
        let dealer_cards = storage.dealer_hand.at(player).get_notes(NoteGetterOptions::new());
        assert(dealer_cards.len() >= 2, "Dealer does not have 2 cards in their hand");

        // Remove all cards from player's hand
        //need to also remove the token note
        let options = NoteGetterOptions::new();

        let player_location = storage.player_hand.at(player);
        player_location.pop_notes(options);

        // Remove all cards from dealer's hand
        let dealer_location = storage.dealer_hand.at(player);
        dealer_location.pop_notes(options);

        //remove the split hand
        let split_hand_location = storage.split_hand.at(player);
        split_hand_location.pop_notes(options);

        //remove the bet, should work
        // let slot = storage.bet.at(player).get_storage_slot();
        // let player_keys = get_public_keys(player);
        // let (bet_note, note_hash_for_read_request): (ValueNote, Field) =
        //     get_note(&mut context, slot);
        // destroy_note_unsafe(&mut context, bet_note, note_hash_for_read_request);
        // create_note(&mut context, slot, &mut ValueNote::new(0, player)).emit(
        //     encode_and_encrypt_note(&mut context, player_keys.ovpk_m, player, player),
        // );
        //there needs a be a better option just to destroy the note
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

