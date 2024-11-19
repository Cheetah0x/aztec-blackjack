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

mod helpers;
mod test;
mod notes;

use dep::aztec::macros::aztec;

#[aztec]
contract BlackJack {

    use crate::helpers::CardHelpersPrivate::{card_points, draw_card, draw_until_seventeen};
    use crate::notes::CardNote::{Card, CardNote, Deck};
    use dep::address_note::address_note::AddressNote;
    use dep::aztec::{
        context::{PrivateContext, PublicContext},
        encrypted_logs::encrypted_note_emission::encode_and_encrypt_note,
        keys::getters::get_public_keys,
        macros::{functions::{initializer, internal, private, public, view}, storage::storage},
        oracle::random::random,
        prelude::{
            AztecAddress, Map, NoteGetterOptions, PrivateImmutable, PrivateMutable, PrivateSet,
            PublicImmutable, PublicMutable,
        },
    };
    use dep::token::Token;
    use dep::value_note::value_note::ValueNote;

    //will have the deck in there but wont use tbh
    #[storage]
    struct Storage<Context> {
        player_address: PrivateMutable<AddressNote, Context>,
        card_deck_used: PrivateSet<CardNote, Context>,
        player_hand: Map<AztecAddress, PrivateSet<CardNote, Context>, Context>,
        dealer_hand: PrivateSet<CardNote, Context>,
        player_bust: PublicMutable<bool, Context>, //should probs map this to the player address
        dealer_bust: PublicMutable<bool, Context>,
        bets: Map<AztecAddress, PrivateSet<ValueNote, Context>, Context>,
        insurance: Map<AztecAddress, PrivateSet<ValueNote, Context>, Context>,
    }

    #[initializer]
    #[private]
    fn constructor(player_address: AztecAddress) {
        let player_keys = get_public_keys(player_address);
        let mut player_note = AddressNote::new(player_address, player_address);
        storage.player_address.initialize(&mut player_note).emit(encode_and_encrypt_note(
            &mut context,
            player_keys.ovpk_m,
            player_address,
            player_address,
        ));
    }

    #[private]
    #[view]
    fn player_points(player: AztecAddress) -> u8 {
        let location = storage.player_hand.at(player);
        let points = card_points(location);
        points as u8
    }

    #[private]
    #[view]
    fn dealer_points() -> u8 {
        let location = storage.dealer_hand;
        let points = card_points(location);
        points as u8
    }

    #[public]
    #[view]
    fn is_player_bust_view() -> bool {
        storage.player_bust.read()
    }

    #[public]
    #[view]
    fn is_dealer_bust_view() -> bool {
        storage.dealer_bust.read()
    }

    //at the start of the game, the player will need to make a bet
    //the user will have to send the funds to the contract
    #[private]
    fn make_bet(bet: Field, token: AztecAddress) {
        let player = context.msg_sender();
        let contract_address = context.this_address();

        let player_keys = get_public_keys(player);
        let mut bet_note = ValueNote::new(bet, player);

        //will need to think about this from a security standpoint, need to only update the balance if the transfer is successful
        //maybe have it in a loop so that the note only gets added if the transfer is successful
        storage.bets.at(player).insert(&mut bet_note).emit(encode_and_encrypt_note(
            &mut context,
            player_keys.ovpk_m,
            player,
            player,
        ));

        Token::at(token).transfer(contract_address, bet).call(&mut context);
    }

    //insurance that the user can take out if the dealer has an ace on the first card
    #[private]
    fn place_insurance_bet(insurance_bet: Field, token: AztecAddress) {
        let player = context.msg_sender();
        let contract_address = context.this_address();

        let options = NoteGetterOptions::new();
        let dealer_cards: BoundedVec<CardNote, 16> = storage.dealer_hand.get_notes(options);
        let first_card = dealer_cards.get_unchecked(0);
        assert(first_card.card.rank == 1, "Dealer does not have an ace");

        let player_keys = get_public_keys(player);
        let mut insurance_note = ValueNote::new(insurance_bet, player);
        storage.insurance.at(player).insert(&mut insurance_note).emit(encode_and_encrypt_note(
            &mut context,
            player_keys.ovpk_m,
            player,
            player,
        ));

        Token::at(token).transfer(contract_address, insurance_bet).call(&mut context);
    }

    #[private]
    fn begin_game(player: AztecAddress) {
        //add logic that a game can only be started if the player has made a bet
        //1. will need to read the cards from the deck that are being used.
        //there is the limitation of only being able to fetch 16 at a time. This is a constraint we will have the mention
        //Other option is to have another storage/ loop for this to store the other cards in another vec.
        //2. will do this by fetching the notes of the cards and populating an array.
        let options = NoteGetterOptions::new();
        let used_cards: BoundedVec<CardNote, 16> = storage.card_deck_used.get_notes(options);

        //3. Will need to draw the cards, can do this using random atm, 2 for the player, one for the dealer and add them to the hands.
        for i in 0..2 {
            draw_card(player, storage.player_hand.at(player), &mut context);
        }

        //for the dealer card
        draw_card(player, storage.dealer_hand, &mut context);
    }

    #[private]
    fn player_hit(player: AztecAddress) {
        //read the cards that have been used, will not do this for now.
        //get the player cards
        let points = card_points(storage.player_hand.at(player));
        //can have the bust state internal here, will have to update it at somepoint
        let mut bust = false;
        if points > 21 {
            bust = true;
            BlackJack::at(context.this_address()).is_player_bust(bust).enqueue(&mut context);
        }

        if bust == false {
            //draw a new card
            draw_card(player, storage.player_hand.at(player), &mut context);
        }

        //get the new points
        let points = card_points(storage.player_hand.at(player));

        //can have the bust state internal here, will have to update it at somepoint
        let mut bust = false;
        if points > 21 {
            bust = true;
            BlackJack::at(context.this_address()).is_player_bust(true).enqueue(&mut context);
        }
    }

    //now i need to add the logic for the player standing and what happens with the dealer.
    #[private]
    fn player_stand(player: AztecAddress) -> bool {
        //time for the dealer to play
        //fetch the dealer hand
        let dealer_points = card_points(storage.dealer_hand);

        //get the players points
        let player_points = card_points(storage.player_hand.at(player));

        //now the dealer plays until he is bust or he beats the player
        let location = storage.dealer_hand;
        let dealer_points2 =
            draw_until_seventeen(dealer_points as u8, player, &mut context, location);

        let mut bust = false;
        if dealer_points2 > 21 {
            bust = true;
            BlackJack::at(context.this_address()).is_dealer_bust(bust).enqueue(&mut context);
        }

        //check if the dealer has beaten the player
        let mut win = false;
        if dealer_points2 > player_points as u8 & dealer_points2 as u8 <= 21 {
            win = false;
        } else {
            win = true;
        }
        //need to add the logic for a push ie, the points are the same, add the helper function for win
        win
        //add the logic to pay out the player if they win
    }

    //logic for double down
    #[private]
    fn double_down(token: AztecAddress) {
        let player = context.msg_sender();
        let contract_address = context.this_address();
        let player_keys = get_public_keys(player);
        let location = storage.player_hand.at(player);
        let player_points = card_points(location);
        if (player_points < 9) {
            assert( false, "Player can only double down on 9,10 or 11");
        }
        if (player_points > 11) {
            assert(false, "Player can only double down on 9,10 or 11");
        }
        //need to figure out how to split the hand

        //get the original bet amount, this will be the last note the player can decrpypt
        let mut options = NoteGetterOptions::new();
        options
            .set_limit(1);
        let bet_note = storage.bets.at(player).get_notes(options);
        let note = bet_note.get_unchecked(1);
        let bet = note.value;

        //then bet this again
        let mut bet_note = ValueNote::new(bet, player);

        //will need to think about this from a security standpoint, need to only update the balance if the transfer is successful
        //maybe have it in a loop so that the note only gets added if the transfer is successful
        storage.bets.at(player).insert(&mut bet_note).emit(encode_and_encrypt_note(
            &mut context,
            player_keys.ovpk_m,
            player,
            player,
        ));

        Token::at(token).transfer(contract_address, bet).call(&mut context);
        //so the player has doubled the bet, now they continue the game as normal

    }

    #[public]
    fn is_player_bust(bust: bool) {
        storage.player_bust.write(bust)
    }

    #[public]
    fn is_dealer_bust(bust: bool) {
        storage.dealer_bust.write(bust)
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
