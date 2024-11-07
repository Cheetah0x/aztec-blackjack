// CardNote.nr
pub mod CardNote {
    use dep::aztec::{
        oracle::random::random,
        prelude::{PublicContext, PublicMutable},
        protocol_types::{
            address::AztecAddress,
            constants::MAX_NOTE_HASH_READ_REQUESTS_PER_CALL,
            traits::{Deserialize, FromField, Serialize, ToField},
        },
    };
    use std::hash::poseidon2;

    global MAX_CARDS_IN_HAND: u32 = 6;
    global BITS_PER_FIELD: u32 = 255;
    global TOTAL_CARDS: u32 = 52;
    global FIELDS_FOR_DECK: u32 = 7;
    global MAX_DRAW_ATTEMPTS: u32 = 5;
    global BITS_PER_BYTE: u32 = 8;
    global NUM_BITMAP_BYTES: u32 = (TOTAL_CARDS + BITS_PER_BYTE - 1) / BITS_PER_BYTE; // 7 bytes

    //-------------------------------CARD-----------------------------------

    #[derive(Serialize)]
    #[derive(Deserialize)]
    pub struct Card {
        pub rank: Field,
        pub suit: Field,
    }

    impl FromField for Card {
        fn from_field(field: Field) -> Card {
            let value_bytes: [u8; 32] = field.to_le_bytes();
            let rank = ((value_bytes[0] as u32) + (value_bytes[1] as u32) * 256) % 14;
            let suit = ((value_bytes[2] as u32) + (value_bytes[3] as u32) * 256) % 4;
            Card { rank: rank as Field, suit: suit as Field }
        }
    }

    impl ToField for Card {
        fn to_field(self) -> Field {
            self.rank as Field + self.suit as Field * 65536
        }
    }

    fn card_id(rank: u8, suit: u8) -> u8 {
        (suit as u8) * 13 + (rank as u8) - 1 // Ranks from 1 to 13
    }

    fn id_to_card(card_id: u8) -> Card {
        let rank = (card_id % 13) + 1;
        let suit = card_id / 13;
        Card { rank: rank as Field, suit: suit as Field }
    }

    //-------------------------------HAND-----------------------------------

    pub struct Hand {
        cards: BoundedVec<Card, MAX_CARDS_IN_HAND>,
        bust: bool,
    }

    impl Serialize<MAX_CARDS_IN_HAND> for Hand {
        fn serialize(self) -> [Field; MAX_CARDS_IN_HAND] {
            let mut fields = [Field::empty(); MAX_CARDS_IN_HAND];
            //only serialize the cards that exist
            for i in 0..self.cards.len() {
                fields[i] = self.cards.get(i).to_field();
            }
            fields
        }
    }

    impl Deserialize<MAX_CARDS_IN_HAND> for Hand {
        fn deserialize(fields: [Field; MAX_CARDS_IN_HAND]) -> Self {
            let mut cards = BoundedVec::new();
            //only deserialize the non empty fields
            for i in 0..fields.len() {
                let field = fields[i];
                if field != Field::empty() {
                    cards.push(Card::from_field(field));
                }
            }
            Hand { cards, bust: false }
        }
    }

    impl ToField for Hand {
        fn to_field(self) -> Field {
            // Serialize the cards array into fields
            let mut card_fields = [Field::empty(); MAX_CARDS_IN_HAND];
            for i in 0..self.cards.len() {
                card_fields[i] = self.cards.get(i).to_field();
            }

            // Hash the serialized data
            poseidon2::Poseidon2::hash(card_fields, MAX_CARDS_IN_HAND)
        }
    }

    pub fn new_hand() -> Hand {
        Hand { cards: BoundedVec::new(), bust: false }
    }

    //-------------------------------DECK-----------------------------------
    pub struct Deck {
        // Bitmask to track used cards
        drawn_cards_bitmap: [u8; NUM_BITMAP_BYTES],
        deck_seed: Field,
        draw_counter: u32,
    }

    impl Serialize<NUM_BITMAP_BYTES + 2> for Deck { // Implement Serialize with explicit size
        fn serialize(self) -> [Field; NUM_BITMAP_BYTES + 2] {
            let mut fields = [Field::empty(); NUM_BITMAP_BYTES + 2];
            // Use first 5 indices for bitmap
            for i in 0..NUM_BITMAP_BYTES {
                fields[i] = self.drawn_cards_bitmap[i] as Field;
            }
            // Use last 2 indices for seed and counter
            fields[NUM_BITMAP_BYTES] = self.deck_seed;
            fields[NUM_BITMAP_BYTES + 1] = self.draw_counter as Field;
            fields
        }
    }

    impl Deserialize<NUM_BITMAP_BYTES + 2> for Deck {
        fn deserialize(fields: [Field; NUM_BITMAP_BYTES + 2]) -> Self {
            let mut drawn_cards_bitmap = [0 as u8; NUM_BITMAP_BYTES];
            // Get bitmap from first 5 indices
            for i in 0..NUM_BITMAP_BYTES {
                drawn_cards_bitmap[i] = fields[i] as u8;
            }
            // Get seed and counter from last 2 indices
            let deck_seed = fields[NUM_BITMAP_BYTES];
            let draw_counter = fields[NUM_BITMAP_BYTES + 1] as u32;
            Deck { drawn_cards_bitmap, deck_seed, draw_counter }
        }
    }

    impl Deck {
        fn new(deck_seed: Field) -> Self {
            // Initialize with all zeros
            let drawn_cards_bitmap = [0 as u8; NUM_BITMAP_BYTES];
            let draw_counter = 0;

            Self { drawn_cards_bitmap, deck_seed, draw_counter }
        }
    }

    impl ToField for Deck {
        fn to_field(self) -> Field {
            let mut card_fields = [Field::empty(); FIELDS_FOR_DECK];
            for i in 0..self.drawn_cards_bitmap.len() {
                card_fields[i] = self.drawn_cards_bitmap[i].to_field();
            }
            card_fields[FIELDS_FOR_DECK] = self.deck_seed;
            card_fields[(FIELDS_FOR_DECK + 1)] = self.draw_counter.to_field();
            // Hash all card fields into a single Field
            poseidon2::Poseidon2::hash(card_fields, FIELDS_FOR_DECK)
        }
    }

    //-------------------------------BITMASK UTILITIES-----------------------------------
    fn is_card_used(deck: &mut Deck, card_index: u8) -> bool {
        assert(card_index as u32 < TOTAL_CARDS as u32); // Ensure valid card index
        let field_index = (card_index / 8) as u32;
        assert(field_index as u32 < FIELDS_FOR_DECK as u32); // Ensure valid field index
        let bit_index = card_index % 8;
        let current_field = deck.drawn_cards_bitmap[field_index as u8];
        (current_field & (1 << bit_index)) != 0
    }

    fn set_card_used(deck: &mut Deck, card_index: u8) {
        assert(card_index as u32 < TOTAL_CARDS as u32); // Ensure valid card index
        let field_index = (card_index / 8) as u32;
        assert(field_index < FIELDS_FOR_DECK as u32); // Ensure valid field index
        let bit_index = card_index % 8;
        let mut current_value = deck.drawn_cards_bitmap[field_index as u8];
        current_value |= 1 << bit_index;
        deck.drawn_cards_bitmap[field_index as u8] = current_value;
    }

    //---------------------------FIESTEL NETWORK-----------------------------------

    fn feistel_network(seed: Field, input: u64) -> u64 {
        let mut left = (input) & 0xFFFF_FFFF;
        let mut right = (input >> 32) & 0xFFFF_FFFF;

        // Round 1
        let temp = right;
        right = left ^ (feistel_function(right, seed, 0)) as u64;
        left = temp;

        // Round 2
        let temp = right;
        right = left ^ (feistel_function(right, seed, 1)) as u64;
        left = temp;

        // Round 3
        let temp = right;
        right = left ^ (feistel_function(right, seed, 2)) as u64;
        left = temp;

        // Combine left and right
        let output = (left << 32) | right;
        // Map output to 0..51
        (output % 52) as u64
    }

    fn feistel_function(value: u64, seed: Field, round: u32) -> Field {
        let value_field = value as Field;
        poseidon2::Poseidon2::hash([value_field, seed, round.to_field()], 3)
    }

    //-------------------------------DRAW CARD-----------------------------------

    pub fn generate_card(deck_seed: Field, draw_counter: u64) -> Card {
        let card_index = feistel_network(deck_seed, draw_counter);
        id_to_card(card_index as u8)
    }

    pub fn draw_card(mut deck: Deck) -> (Card, Deck) {
        let mut card_index = 0;
        let mut unique_card_found = false;
        let mut final_counter = 0;

        // Instead of breaking, we'll use the first valid card we find
        for attempt in 0..MAX_DRAW_ATTEMPTS {
            if !unique_card_found {
                // Only process if we haven't found a card yet
                let current_draw_counter = deck.draw_counter + attempt;
                let current_card_index =
                    feistel_network(deck.deck_seed, current_draw_counter as u64) as u8;

                if !is_card_used(&mut deck, current_card_index) {
                    // Found a valid card
                    card_index = current_card_index;
                    final_counter = current_draw_counter + 1;
                    unique_card_found = true;

                    set_card_used(&mut deck, card_index);
                }
            }
        }

        // Update the counter after the loop
        if unique_card_found {
            deck.draw_counter = final_counter;
        } else {
            deck.draw_counter = deck.draw_counter + MAX_DRAW_ATTEMPTS;
        }

        let card = if unique_card_found {
            id_to_card(card_index)
        } else {
            Card { rank: 0.to_field(), suit: 0.to_field() }
        };

        (card, deck)
    }

    //-------------------------------CARD FUNCTIONS-----------------------------------

    pub fn start_game(
        deck: &mut Deck,
        player_hand: &mut Hand,
        dealer_hand: &mut Hand,
        // card_deck_storage: PublicMutable<Deck, &mut PublicContext>,
    ) -> (Hand, Hand, &mut Deck) {
        // Draw two cards for the player
        player_hand.cards = BoundedVec::new();
        dealer_hand.cards = BoundedVec::new();

        //draw two cards for the player
        let (card1, updated_deck) = draw_card(*deck);
        player_hand.cards.push(card1);
        let (card2, updated_deck) = draw_card(updated_deck);
        player_hand.cards.push(card2);

        // Draw one card for the dealer (face-up)
        let (dealer_card, final_deck) = draw_card(updated_deck);
        dealer_hand.cards.push(dealer_card);

        (*player_hand, *dealer_hand, deck)
    }

    // pub fn player_hit1(deck: &mut Deck, player_hand: &mut Hand) -> bool {
    //     if let Some(card) = draw_card(deck) {
    //         player_hand.cards.push(card);
    //         // Check if player busts
    //         check_bust(player_hand)
    //     } else {
    //         // Handle no more cards scenario
    //         true // Assuming player busts if no more cards can be drawn
    //     }
    // }

    pub fn player_hit(deck: &mut Deck, player_hand: &mut Hand) -> bool {
        // Draw a new card
        let (card, deck) = draw_card(*deck);
        player_hand.cards.push(card);

        // Check if player busts
        check_bust(player_hand)
    }

    pub fn dealer_play(deck: &mut Deck, dealer_hand: &mut Hand) {
        // Dealer must hit until the hand value is 17 or more
        //need to make this a loop without while loop
        if hand_points(dealer_hand) as u8 < 17 {
            let (card, deck) = draw_card(*deck);
            dealer_hand.cards.push(card);
        }
    }

    fn card_points(card: Card) -> Field {
        if (card.rank as u8 > 1) & (card.rank as u8 <= 10) {
            card.rank
        } else if card.rank == 1 {
            11.to_field() // Ace as 11 initially
        } else {
            10.to_field() //Face cards (J,Q,K)
        }
    }

    pub fn determine_winner(player_hand: &mut Hand, dealer_hand: &mut Hand) -> Field {
        let player_points = hand_points(player_hand) as u8;
        let dealer_points = hand_points(dealer_hand) as u8;

        let player_bust = check_bust(player_hand);
        let dealer_bust = check_bust(dealer_hand);

        //player wins = 0
        //dealer wins = 1
        //push = 2
        if player_bust {
            1.to_field()
        } else if dealer_bust {
            0.to_field()
        } else if player_points > dealer_points {
            0.to_field()
        } else if dealer_points > player_points {
            1.to_field()
        } else {
            2.to_field()
        }
    }

    pub fn hand_points(hand: &mut Hand) -> Field {
        let mut points = 0;
        let mut aces = 0;

        // First pass: Calculate initial points and count the number of Aces.
        for i in 0..hand.cards.len() {
            let card_point = card_points(hand.cards.get(i));
            if card_point == Field::from(11) {
                aces += 1;
            }
            points += card_point;
        }

        // Adjust for Aces if points exceed 21.
        // Adjust for Aces if points exceed 21.
        let max_points = 21;
        if (points as u8 > max_points) & (aces > 0) {
            points = points - 10; // Adjust one Ace from 11 to 1
        }
        if (points as u8 > max_points) & (aces > 1) {
            points = points - 10; // Adjust second Ace if needed
        }
        if (points as u8 > max_points) & (aces > 2) {
            points = points - 10; // Adjust third Ace if needed
        }

        // The above conditions effectively handle up to 4 Aces in a hand.
        points
    }

    pub fn check_bust(hand: &mut Hand) -> bool {
        hand_points(hand) as u8 > 21
    }

    // pub fn generate_deck() -> Deck {
    //     let mut deck: Deck = Deck { drawn_cards_bitmap: [0.to_field(); FIELDS_FOR_DECK] };

    //     let mut index = 0;
    //     for suit in 1..=4 {
    //         for rank in 1..=13 {
    //             let card_index = card_id(rank as u8, suit as u8);
    //             set_card_used(&mut deck, card_index);
    //         }
    //     }
    //     deck
    // }

}

