
// CardNote.nr
pub mod CardNote {
    use dep::aztec::{protocol_types::{
        address::AztecAddress,
        constants::MAX_NOTE_HASH_READ_REQUESTS_PER_CALL,
        traits::{Deserialize, FromField, Serialize, ToField},
    },
    oracle::random::random,
    prelude::PublicMutable,
    };
    use std::hash::poseidon2;

    global MAX_CARDS_IN_HAND: u32 = 6;
    global MAX_CARDS_IN_DECK: u32 = 52;


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
        // only track the cards that have been drawn
        drawn_cards: BoundedVec<Card, MAX_CARDS_IN_DECK>,
    }


    impl Serialize<MAX_CARDS_IN_DECK> for Deck {  // Implement Serialize with explicit size
        fn serialize(self) -> [Field; MAX_CARDS_IN_DECK] {
            let mut fields = [Field::empty(); MAX_CARDS_IN_DECK];
            for i in 0..self.drawn_cards.len() {
                fields[i] = self.drawn_cards.get(i).to_field();
            }
            fields
        }
    }

    impl Deserialize<MAX_CARDS_IN_DECK> for Deck {
        fn deserialize(fields: [Field; MAX_CARDS_IN_DECK]) -> Self {
            let mut drawn_cards = BoundedVec::new();
            for i in 0..drawn_cards.len() {
                drawn_cards.push(Card::from_field(fields[i]));
            }
            Deck { drawn_cards }
        }
    }

    impl Deck {
        fn new() -> Self {
            Deck {
            drawn_cards: BoundedVec::new(), // Empty at start
        }
    }
}


    impl ToField for Deck {
        fn to_field(self) -> Field {
            let mut card_fields = [Field::empty(); MAX_CARDS_IN_DECK];
            for i in 0..self.drawn_cards.len() {
                card_fields[i] = self.drawn_cards.get(i).to_field();
            }
            // Hash all card fields into a single Field
                poseidon2::Poseidon2::hash(card_fields, MAX_CARDS_IN_DECK)
        }
    }
    //-------------------------------CARD FUNCTIONS-----------------------------------

    fn new(rank: Field, suit: Field) -> Card {
        Card { rank, suit }
    }

    pub fn draw_card(deck: &mut Deck) -> Card {
        let card = generate_card();
        if deck.drawn_cards.len() < MAX_CARDS_IN_DECK {
            deck.drawn_cards.push(card);
        }
        card
    }

    pub fn start_game(deck: &mut Deck, player_hand: &mut Hand, dealer_hand: &mut Hand) -> (Hand, Hand) {
        // Draw two cards for the player
        player_hand.cards = BoundedVec::new();
        dealer_hand.cards = BoundedVec::new();

        //draw two cards for the player
        player_hand.cards.push(draw_card(deck));
        player_hand.cards.push(draw_card(deck));

        // Draw one card for the dealer (face-up)
        dealer_hand.cards.push(draw_card(deck));

        (*player_hand, *dealer_hand)
    }

    pub fn player_hit(deck: &mut Deck, player_hand: &mut Hand) -> bool {
        // Draw a new card
        player_hand.cards.push(draw_card(deck));

        // Check if player busts
        check_bust(player_hand)
    }

    pub fn dealer_play(deck: &mut Deck, dealer_hand: &mut Hand) {
        // Dealer must hit until the hand value is 17 or more
        //need to make this a loop without while loop
        if hand_points(dealer_hand) as u8 < 17 {
            dealer_hand.cards.push(draw_card(deck));
        }
    }

    fn card_points(card: Card) -> Field {
        if (card.rank as u8 > 1) & (card.rank as u8 <= 10) {
            card.rank
        } else if card.rank == 1 {
            11 // Ace as 11 initially
        } else {
            10 //Face cards (J,Q,K)
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
            points = points - 10;  // Adjust one Ace from 11 to 1
        }
        if (points as u8 > max_points) & (aces > 1) {
        points = points - 10;  // Adjust second Ace if needed
        }
        if (points as u8 > max_points) & (aces > 2) {
            points = points - 10;  // Adjust third Ace if needed
        }

        // The above conditions effectively handle up to 4 Aces in a hand.

        points
    }


    pub fn check_bust(hand: &mut Hand) -> bool {
        hand_points(hand) as u8 > 21
    }

    pub fn generate_deck() -> Deck {
        let mut deck: Deck = Deck {
            drawn_cards: BoundedVec::new(),
        };

        let mut index = 0;
        for suit in 1..=4 {
            for rank in 1..=13 {
                deck.drawn_cards.push(new(rank as Field, suit as Field));
                index += 1;
            }
        }
        deck
    }

    fn generate_card() -> Card {
        // Generate two independent random values
        // let random_rank = unsafe { random() };
        // let random_suit = unsafe { random() };

        let random_rank = 3.to_field();
        let random_suit = 2.to_field();
        // Use modulo operations to set rank and suit within their respective ranges
        let rank = (random_rank as u64 % 13) + 1; // rank from 1 to 13
        let suit = (random_suit as u64 % 4) + 1;   // suit from 1 to 4

        Card { 
            rank: rank as Field, 
            suit: suit as Field 
        }
    }

}

