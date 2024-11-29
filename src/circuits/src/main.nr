//functionality that i need:

//make it super simple to start similar to kits

// Player hits/stands to beat dealer's hand by getting as close to 21 as possible.

// Dealer must hit on and up to 16 and stand on 17.

// Player can only double down on 9, 10, or 11.

// Player can either double down or split, player cannot split then double down and vice versa.

// Player cannot split then split again or double down more than once.

// Player who splits Aces can receive only one more additional card on a hand.

// Player can get insurance if dealer might have a BlackJack.

// Aces are high unless card total is already greater than 11.

// Blackjack payout is 3:2.

// No surrender.

//time to add some privacy
//what actually needs to be private here?
//the view functions are unconstrained reads, this means that the notes do not have to be replaced and stuff

//TODO: add the logic for the player to split

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
    use dep::address_note::address_note::AddressNote;
    use dep::authwit::auth::{
        assert_current_call_valid_authwit, assert_current_call_valid_authwit_public,
        compute_authwit_message_hash_from_call, set_authorized,
    };
    use dep::aztec::{
        context::{PrivateContext, PublicContext},
        encrypted_logs::encrypted_note_emission::{
            encode_and_encrypt_note, encode_and_encrypt_note_unconstrained,
        }, keys::getters::get_public_keys,
        macros::{functions::{initializer, internal, private, public, view}, storage::storage},
        note::lifecycle::destroy_note, oracle::random::random,
        prelude::{
            AztecAddress, FunctionSelector, Map, NoteGetterOptions, PrivateImmutable,
            PrivateMutable, PrivateSet, PublicImmutable, PublicMutable,
        },
    };
    use dep::aztec::oracle::debug_log::{debug_log, debug_log_format};
    use dep::token::Token;
    use dep::value_note::value_note::ValueNote;
    use aztec::note::note_viewer_options::NoteViewerOptions;

    global ZERO_ADDRESS: AztecAddress = AztecAddress::from_field(
        0x0000000000000000000000000000000000000000000000000000000000000000,
    );

    //this is the version where we are not using the card deck. Have the assumptions laid out in the spec
    #[storage]
    struct Storage<Context> {
        player_hand: Map<AztecAddress, PrivateSet<CardNote, Context>, Context>,
        dealer_hand: Map<AztecAddress, PrivateSet<CardNote, Context>, Context>,
        player_bust: Map<AztecAddress, PublicMutable<bool, Context>, Context>, //should probs map this to the player address
        dealer_bust: Map<AztecAddress, PublicMutable<bool, Context>, Context>,
        blackjack: Map<AztecAddress, PublicMutable<bool, Context>, Context>,
        bet: Map<AztecAddress, PrivateMutable<ValueNote, Context>, Context>,
        insurance: Map<AztecAddress, PrivateMutable<ValueNote, Context>, Context>,
        token: Map<AztecAddress, PrivateMutable<AddressNote, Context>, Context>,
        winner: Map<AztecAddress, PublicMutable<AztecAddress, Context>, Context>,
        double_down: Map<AztecAddress, PublicMutable<bool, Context>, Context>,
        split: Map<AztecAddress, PublicMutable<bool, Context>, Context>,
    }
    //TODO: need to add double down and split to storage

    #[initializer]
    #[private]
    fn constructor() {}

    //do not make these unconstrained
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
        storage.player_bust.at(player).read()
    }

    #[public]
    #[view]
    fn is_dealer_bust_view() -> bool {
        let player = context.msg_sender();
        storage.dealer_bust.at(player).read()
    }

    #[public]
    #[view]
    fn is_blackjack_view() -> bool {
        let player = context.msg_sender();
        storage.blackjack.at(player).read()
    }

    #[public]
    #[view]
    fn contract_address() -> AztecAddress {
        context.this_address()
    }

    //at the start of the game, the player will need to make a bet
    //the user will have to send the funds to the contract
    //TODO: implement the token transfer once bug is patched
    //TODO: also cannot check the private balance at the minute, whatever they are doing in the token contract
    //TODO: Authwit?
    //TODO: protect against reentrancy
    //TODO: make sure the bet is less than the balance of the player
    //TODO: make sure there are not multiple bets, can only make one bet, privateMutable
    //TODO: ensure that the player has enough balance to make the bet
    #[private]
    fn make_bet(bet: Field, token: AztecAddress) {
        let player = context.msg_sender();
        let contract_address = context.this_address();

        //10 minumum bet
        //100 maximum bet
        assert(bet as u64 >= 10, "Bet must be greater than 10");
        assert(bet as u64 <= 100, "Bet must be less than 100");

        //get the player balance
        //this needs to be done but i dont understand why it is not working
        // let player_balance = Token::balance_of_private(player);
        // assert(player_balance as u64 >= bet as u64, "Player does not have enough balance");
        let player_keys = get_public_keys(player);
        let mut bet_note = ValueNote::new(bet, player);

        // add the tokenaddress to storage
        let mut token_note = AddressNote::new(token, player);
        storage.token.at(player).initialize(&mut token_note).emit(encode_and_encrypt_note(
            &mut context,
            player_keys.ovpk_m,
            player,
            player,
        ));
        // Ensure the call is authenticated
        // assert_current_call_valid_authwit(&mut context, player);
        // Token::at(token).transfer_from(player, contract_address, bet, 0).call(&mut context);
        //only update the note if the transfer is successful
        //maybe have it in a loop so that the note only gets added if the transfer is successful
        //this should protect against making a new bet if the note is already created
        storage.bet.at(player).initialize(&mut bet_note).emit(encode_and_encrypt_note(
            &mut context,
            player_keys.ovpk_m,
            player,
            player,
        ));
    }

    //insurance that the user can take out if the dealer has an ace on the first card
    //TODO: insurance bet should be half of the original bet.
    //TODO: verifify the player has suffucient balance to take out the insurance bet. ie, the transfer goes through first
    //TODO: protect against reentrancy, still need to think about this, emitting events?
    #[private]
    fn place_insurance_bet() {
        let player = context.msg_sender();
        let contract_address = context.this_address();

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
    //TODO: Validate that the hands are properly initialized before starting
    //TODO: include the flags to ensure that the game is already in progress
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
    }

    //logic for double down
    //TODO: token can be fetched from storage
    //TODO: Implement the token transfer
    //TODO: player has to stand after this
    //TODO: prevent multiple double downs
    //TODO: update game state to reflect the double down
    //TODO: protect against reentrancy and unauthorized calls
    #[private]
    fn double_down(token: AztecAddress) {
        let player = context.msg_sender();
        let contract_address = context.this_address();
        let player_keys = get_public_keys(player);
        let player_points = card_points(storage.player_hand.at(player));
        if (player_points < 9) {
            assert(false, "Player can only double down on 9,10 or 11");
        }
        if (player_points > 11) {
            assert(false, "Player can only double down on 9,10 or 11");
        }
        //need to figure out how to split the hand
        //get the original bet amount, this will be the last note the player can decrpypt
        let bet = storage.bet.at(player).get_note().note.value;
        //then bet this again
        let mut bet_note = ValueNote::new(bet * 2, player);

        //will need to think about this from a security standpoint, need to only update the balance if the transfer is successful
        //maybe have it in a loop so that the note only gets added if the transfer is successful
        storage.bet.at(player).replace(&mut bet_note).emit(encode_and_encrypt_note(
            &mut context,
            player_keys.ovpk_m,
            player,
            player,
        ));
        //so the player has doubled the bet, now they continue the game as normal
    }

    //TODO: Implement the split function

    //TODO: the assertion of 2 cards prevents multiple hits, will need to change this, 2 or more cards
    //TODO: ensure the player is allowed to hit,( has not standed or doubled down)
    //TODO: event emission??
    #[private]
    fn player_hit() {
        //read the cards that have been used, will not do this for now.
        //get the player cards
        let player = context.msg_sender();
        let contract_address = context.this_address();

        //check that the player has cards in hand, do not need to check if the bet has been made
        //they can only have cards in their hand if that have already made a bet and started the game
        let player_hand = storage.player_hand.at(player);
        let player_cards = player_hand.get_notes(NoteGetterOptions::new());
        assert(player_cards.len() == 2, "Player does not have 2 cards in their hand");

        let points = card_points(player_hand);
        //can have the bust state internal here, will have to update it at somepoint
        let mut bust = false;
        if points > 21 {
            bust = true;
            BlackJack::at(contract_address).is_player_bust(bust).enqueue(&mut context);
        }

        if bust == false {
            //draw a new card
            draw_card(player, storage.player_hand.at(player), &mut context);
        }

        //get the new points
        let points = card_points(player_hand);

        //can have the bust state internal here, will have to update it at somepoint
        let mut bust = false;
        if points > 21 {
            bust = true;
            BlackJack::at(contract_address).is_player_bust(true).enqueue(&mut context);
        }
    }

    //now i need to add the logic for the player standing and what happens with the dealer.
    //TODO: return bet for a tie
    //TODO: reset the game state after the game ends, instead of calling the reset function. would be nice if this was separate, but may have to be included
    //TODO: Race conditions, prevent player from calling this multiple times before finishing the game
    //TODO: make sure dealer hands are private until they need to be shown.
    #[private]
    fn player_stand() -> bool {
        //1.Get the player and contract addresses
        let player = context.msg_sender();
        let contract_address = context.this_address();

        //2. Check the player has at least 2 cards in their hand
        let player_hand = storage.player_hand.at(player);
        let player_cards = player_hand.get_notes(NoteGetterOptions::new());
        assert(player_cards.len() >= 2, "Player does not have 2 cards in their hand");

        //3. Check the dealer has 1 card in their hand
        let dealer_cards = storage.dealer_hand.at(player).get_notes(NoteGetterOptions::new());
        assert(dealer_cards.len() == 1, "Dealer does not have 1 card in their hand");

        //4. Check if bet notes exist before accessing, will need a bet anyway for the payout
        // let bet = storage.bet.at(player).get_note().note.value as u64;
        // assert(bet > 0, "No bet notes found");
        // 5. Get the token address, for the transfer later
        // let token = storage.token.at(player).get_note().note.address;
        //Get the current points for the dealer and the player
        let player_points = card_points(player_hand);

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
        let mut bust = false;
        let mut win = false;
        if dealer_points > 21 {
            bust = true;
            BlackJack::at(contract_address).is_dealer_bust(bust).enqueue(&mut context);
        }
        if player_points > 21 {
            win = false;
        } else if dealer_points > player_points & dealer_points <= 21 {
            win = false;
        } else if dealer_points == player_points {
            // Token::at(token).transfer(player, bet).call(&mut context);
            win = false;
        } else {
            // Token::at(token).transfer(player, 2 * bet).call(&mut context);
            win = true;
        }
        let winner = if win { player } else { contract_address };
        BlackJack::at(contract_address).winner(winner).enqueue(&mut context);

        win
    }

    //Potential Issues
    //TODO: Ensure all game state is reset and pruged.
    //TODO: Prevent resetting of the game while it is in progress, need to add tests for this.
    //TODO: event that the game has been reset

    #[private]
    fn reset_game() {
        //need to add assertions
        //dealer cards at least 2, this should be enough, the player stand will have to have been made, can only reset if the game has ended
        let player = context.msg_sender();

        let dealer_cards = storage.dealer_hand.at(player).get_notes(NoteGetterOptions::new());
        assert(dealer_cards.len() >= 2, "Dealer does not have 2 cards in their hand");

        //if the dealer cards are greater than 2 then you should be able to reset
        //i think you could get timing attacks here, will need to add a game state flag,
        //ended, inprogress, waiting
        // Remove all cards from player's hand
        //need to also remove the token note
        let options = NoteGetterOptions::new();

        let player_location = storage.player_hand.at(player);
        player_location.pop_notes(options);

        // Remove all cards from dealer's hand
        let dealer_location = storage.dealer_hand.at(player);
        dealer_location.pop_notes(options);

        //remove the bet
        // let bet_note = storage.bet.at(player).get_note().note;
        // destroy_note(&mut context, bet_note);
        //there needs a be a better option just to destroy the note
        // Reset game state flags
        let contract_address = context.this_address();
        BlackJack::at(contract_address).is_player_bust(false).enqueue(&mut context);
        BlackJack::at(contract_address).is_dealer_bust(false).enqueue(&mut context);
        BlackJack::at(contract_address).blackjack(false).enqueue(&mut context);
        BlackJack::at(contract_address).winner(ZERO_ADDRESS).enqueue(&mut context);
    }

    #[public]
    #[internal]
    fn is_player_bust(bust: bool) {
        let player = context.msg_sender();
        storage.player_bust.at(player).write(bust)
    }

    #[public]
    #[internal]
    fn is_dealer_bust(bust: bool) {
        let player = context.msg_sender();
        storage.dealer_bust.at(player).write(bust)
    }

    #[public]
    #[internal]
    fn blackjack(blackjack: bool) {
        let player = context.msg_sender();
        storage.blackjack.at(player).write(blackjack)
    }

    #[public]
    #[internal]
    fn winner(winner: AztecAddress) {
        let player = context.msg_sender();
        storage.winner.at(player).write(winner)
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
}

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

