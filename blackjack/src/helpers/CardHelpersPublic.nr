// Card HelpersPublic.nr
pub mod CardHelpersPublic {
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
    global USED_CARDS_ELEMENTS: u32 = 20;

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

    impl Serialize<MAX_CARDS_IN_HAND + 1> for Hand {
        fn serialize(self) -> [Field; MAX_CARDS_IN_HAND + 1] {
            let mut fields = [Field::empty(); MAX_CARDS_IN_HAND + 1];
            //only serialize the cards that exist
            for i in 0..self.cards.len() {
                fields[i] = self.cards.get(i).to_field();
            }
            fields[MAX_CARDS_IN_HAND] = if self.bust {
                1.to_field()
            } else {
                0.to_field()
            };
            fields
        }
    }

    impl Deserialize<MAX_CARDS_IN_HAND + 1> for Hand {
        fn deserialize(fields: [Field; MAX_CARDS_IN_HAND + 1]) -> Self {
            let mut cards = BoundedVec::new();
            // Correct: Loop only over the card fields
            for i in 0..MAX_CARDS_IN_HAND {
                let field = fields[i];
                if field != Field::empty() {
                    cards.push(Card::from_field(field));
                }
            }
            // Deserialize the bust status
            let bust_field = fields[MAX_CARDS_IN_HAND];
            let bust = bust_field == Field::from(1);
            Hand { cards, bust }
        }
    }

    impl ToField for Hand {
        fn to_field(self) -> Field {
            // Serialize the cards array into fields
            let mut card_fields = [Field::empty(); MAX_CARDS_IN_HAND + 1];
            for i in 0..self.cards.len() {
                card_fields[i] = self.cards.get(i).to_field();
            }

            //add the bust field
            card_fields[MAX_CARDS_IN_HAND] = if self.bust {
                1.to_field()
            } else {
                0.to_field()
            };

            // Hash the serialized data
            poseidon2::Poseidon2::hash(card_fields, MAX_CARDS_IN_HAND + 1)
        }
    }

    pub fn new_hand() -> Hand {
        Hand { cards: BoundedVec::new(), bust: false }
    }

    //-------------------------------DECK-----------------------------------
    pub struct Deck {
        // Bitmask to track used cards
        used_cards: BoundedVec<u8, 20>,
        deck_seed: Field,
    }

    impl Serialize<USED_CARDS_ELEMENTS + 2> for Deck {
        fn serialize(self) -> [Field; USED_CARDS_ELEMENTS + 2] {
            let mut fields = [0.to_field(); USED_CARDS_ELEMENTS + 2];
            // Serialize the used_cards vector
            for i in 0..self.used_cards.len() {
                fields[i] = self.used_cards.get(i).to_field();
            }
            // Fill remaining slots with zero
            for i in self.used_cards.len()..USED_CARDS_ELEMENTS {
                fields[i] = 0.to_field();
            }
            fields[USED_CARDS_ELEMENTS] = self.deck_seed;
            fields
        }
    }

    impl Deserialize<USED_CARDS_ELEMENTS + 2> for Deck {
        fn deserialize(fields: [Field; USED_CARDS_ELEMENTS + 2]) -> Self {
            let mut used_cards = BoundedVec::new();
            // Deserialize the used_cards vector
            for i in 0..USED_CARDS_ELEMENTS {
                let field = fields[i];
                if field != 0.to_field() {
                    let card_index = field as u8;
                    used_cards.push(card_index);
                }
            }
            let deck_seed = fields[USED_CARDS_ELEMENTS];
            Deck { used_cards, deck_seed }
        }
    }

    impl Deck {
        fn new(deck_seed: Field) -> Self {
            // Initialize with all zeros
            let used_cards = BoundedVec::new();

            Self { used_cards, deck_seed }
        }
    }

    impl ToField for Deck {
        fn to_field(self) -> Field {
            let mut card_fields = [Field::empty(); USED_CARDS_ELEMENTS + 2];
            for i in 0..self.used_cards.len() {
                card_fields[i] = self.used_cards.get(i).to_field();
            }
            card_fields[USED_CARDS_ELEMENTS] = self.deck_seed;
            // Hash all card fields into a single Field
            poseidon2::Poseidon2::hash(card_fields, USED_CARDS_ELEMENTS + 2)
        }
    }

    //-------------------------------BITMASK UTILITIES-----------------------------------
    fn is_card_used(deck: &mut Deck, card_index: u8) -> bool {
        let mut valid = false;
        for i in 0..deck.used_cards.len() {
            if deck.used_cards.get(i) == card_index {
                valid = true;
            }
        }
        valid
    }

    fn set_card_used(deck: &mut Deck, card_index: u8) {
        if deck.used_cards.len() < USED_CARDS_ELEMENTS {
            deck.used_cards.push(card_index);
        }
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

    pub fn draw_card(deck: &mut Deck) -> (Card) {
        let mut card_index = 0;
        let mut unique_card_found = false;
        let mut final_counter = 0;

        // use first valid card found
        for attempt in 0..MAX_DRAW_ATTEMPTS {
            if !unique_card_found {
                // Only process if we haven't found a card yet
                let current_draw_counter = deck.used_cards.len() + attempt;
                let current_card_index =
                    feistel_network(deck.deck_seed, current_draw_counter as u64) as u8;

                // Initialize used_cards if it's empty
                if deck.used_cards.len() == 0 {
                    unique_card_found = true;
                    card_index = current_card_index;
                    final_counter = current_draw_counter + 1;
                    set_card_used(deck, current_card_index);
                } else if !is_card_used(deck, current_card_index) {
                    unique_card_found = true;
                    card_index = current_card_index;
                    final_counter = current_draw_counter + 1;
                    set_card_used(deck, current_card_index);
                }
            }
        }

        let card = if unique_card_found {
            id_to_card(card_index)
        } else {
            Card { rank: 0.to_field(), suit: 0.to_field() }
        };

        (card)
    }

    //-------------------------------CARD FUNCTIONS-----------------------------------

    pub fn start_game(
        deck: &mut Deck,
        player_hand: &mut Hand,
        dealer_hand: &mut Hand,
        // card_deck_storage: PublicMutable<Deck, &mut PublicContext>,
    ) -> (Hand, Hand, Deck) {
        // Draw two cards for the player
        player_hand.cards = BoundedVec::new();
        dealer_hand.cards = BoundedVec::new();

        //draw two cards for the player
        let card1 = draw_card(deck);
        player_hand.cards.push(card1);
        let card2 = draw_card(deck);
        player_hand.cards.push(card2);

        // Draw one card for the dealer (face-up)
        let dealer_card = draw_card(deck);
        dealer_hand.cards.push(dealer_card);

        (*player_hand, *dealer_hand, *deck)
    }

    pub fn player_hit_helper(deck: &mut Deck, player_hand: &mut Hand) -> bool {
        // Draw a new card
        let card = draw_card(deck);
        player_hand.cards.push(card);

        // Check if player busts
        check_bust(player_hand)
    }

    pub fn dealer_play(deck: &mut Deck, dealer_hand: &mut Hand) {
        // Dealer must hit until the hand value is 17 or more
        //need to make this a loop without while loop
        if hand_points(dealer_hand) as u8 < 17 {
            let card = draw_card(deck);
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

    pub fn determine_winner_helper(player_hand: &mut Hand, dealer_hand: &mut Hand) -> u8 {
        let player_points = hand_points(player_hand) as u8;
        let dealer_points = hand_points(dealer_hand) as u8;

        let player_bust = check_bust(player_hand);
        let dealer_bust = check_bust(dealer_hand);

        //player wins = 0
        //dealer wins = 1
        //push = 2
        if player_bust {
            1
        } else if dealer_bust {
            0
        } else if player_points > dealer_points {
            0
        } else if dealer_points > player_points {
            1
        } else {
            2
        }
    }

    pub fn hand_points(hand: &mut Hand) -> u8 {
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
        points as u8
    }

    pub fn check_bust(hand: &mut Hand) -> bool {
        if hand_points(hand) as u8 > 21 {
            hand.bust = true;
            true
        } else {
            hand.bust = false;
            false
        }
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

