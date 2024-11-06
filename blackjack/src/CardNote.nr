use dep::aztec::prelude::{NoteGetterOptions, NoteViewerOptions, PrivateContext};

use dep::aztec::{
    context::PublicContext,
    encrypted_logs::encrypted_note_emission::encode_and_encrypt_note,
    keys::getters::get_public_keys,
    macros::notes::note,
    note::{
        note_header::NoteHeader, note_interface::NullifiableNote,
        utils::compute_note_hash_for_nullify,
    },
    protocol_types::{
        address::AztecAddress,
        constants::MAX_NOTE_HASH_READ_REQUESTS_PER_CALL,
        traits::{FromField, Serialize, ToField},
    },
    state_vars::PrivateSet,
};
use dep::value_note::value_note::ValueNote;

//leave this for now, just the note for the card, going to be done in public first

// #[note]
// #[derive(Serialize)]
// pub struct Card {
//     suit: u8, //representing the suit
//     value: u8, //representing the value 1-14
//     // owner: AztecAddress,
// }

// impl FromField for Card {
//     fn from_field(field: Field) -> Card {
//         let value_bytes: [u8; 32] = field.to_le_bytes();
//         let suit = ((value_bytes[0] as u32) + (value_bytes[1] as u32) * 256) % 4;
//         let value = ((value_bytes[2] as u32) + (value_bytes[3] as u32) * 256) % 14;
//         let header = NoteHeader::empty();
//         Card { suit: suit as u8, value: value as u8, header }
//     }
// }

// // impl NullifiableNote for Card {

// //     fn compute_nullifier(
// //         self,
// //         context: &mut PrivateContext,
// //         note_hash_for_nullify: Field,
// //     ) -> Field {
// //         let owner_npk_m_hash: Field = get_public_keys(self.owner).npk_m.hash();
// //         let secret = context.request_nsk_app(owner_npk_m_hash);
// //         poseidon2_hash_with_separator(
// //             [note_hash_for_nullify, secret],
// //             GENERATOR_INDEX__NOTE_NULLIFIER as Field,
// //         )
// //     }

// //     unconstrained fn compute_nullifier_without_context(self) -> Field {
// //         let note_hash_for_nullify = compute_note_hash_for_nullify(self);
// //         let owner_npk_m_hash: Field = get_public_keys(self.owner).npk_m.hash();
// //         let secret = get_nsk_app(owner_npk_m_hash);
// //         poseidon2_hash_with_separator(
// //             [note_hash_for_nullify, secret],
// //             GENERATOR_INDEX__NOTE_NULLIFIER as Field,
// //         )
// //     }
// // }

// impl ToField for Card {
//     fn to_field(self) -> Field {
//         //equivalent to bit shifting 2^16
//         self.suit as Field + self.value as Field * 65536
//     }
// }

// impl Eq for Card {
//     fn eq(self, other: Self) -> bool {
//         (self.suit == other.suit) & (self.value == other.value)
//     }
// }
// impl Serialize<2> for Card {
//     fn serialize(self) -> [Field; 2] {
//         [self.suit as Field, self.value as Field]
//     }
// }

// CardNote.nr
pub mod CardNote {
    use dep::aztec::protocol_types::{
        address::AztecAddress,
        constants::MAX_NOTE_HASH_READ_REQUESTS_PER_CALL,
        traits::{Deserialize, FromField, Serialize, ToField},
    };
    use std::hash::poseidon2;

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
        pub cards: [Card; 10],
        pub card_count: Field,
        pub bust: bool,
    }

    impl Serialize<10> for Hand {
        fn serialize(self) -> [Field; 10] {
            let mut fields = [Field::empty(); 10];
            for i in 0..10 {
                fields[i] = self.cards[i].to_field();
            }
            fields
        }
    }

    impl Deserialize<10> for Hand {
        fn deserialize(fields: [Field; 10]) -> Self {
            let cards = fields.map(|field| Card::from_field(field));
            Hand { cards, card_count: 0, bust: false }
        }
    }

    impl ToField for Hand {
        fn to_field(self) -> Field {
            // Serialize the cards array into fields
            let mut card_fields = [Field::empty(); 10];
            for i in 0..10 {
                card_fields[i] = self.cards[i].to_field();
            }

            // Hash the serialized data
            poseidon2::Poseidon2::hash(card_fields, 10)
        }
    }

    //-------------------------------DECK-----------------------------------
    pub struct Deck {
        pub cards: [Card; 52],
    }

    impl Serialize<52> for Deck {  // Implement Serialize with explicit size
        fn serialize(self) -> [Field; 52] {
            let mut fields = [Field::empty(); 52];
            for i in 0..52 {
                fields[i] = self.cards[i].to_field();
            }
            fields
        }
    }

    impl Deserialize<52> for Deck {
        fn deserialize(fields: [Field; 52]) -> Self {
            let cards = fields.map(|field| Card::from_field(field));
            Deck { cards }
        }
    }

    impl Deck {
        pub fn new(storage_slot: Field) -> Self {
            let cards = [Card { rank: 0, suit: 0 }; 52];
            Deck { cards }
        }
    }

    impl ToField for Deck {
        fn to_field(self) -> Field {
            let mut card_fields = [Field::empty(); 52];
            for i in 0..52 {
                card_fields[i] = self.cards[i].to_field();
            }
            // Hash all card fields into a single Field
            poseidon2::Poseidon2::hash(card_fields, 52)
        }
    }
    //-------------------------------CARD FUNCTIONS-----------------------------------

    pub fn new(rank: Field, suit: Field) -> Card {
        Card { rank, suit }
    }

    pub fn card_points(card: Card) -> Field {
        if (card.rank as u8 > 1) & (card.rank as u8 <= 10) {
            card.rank
        } else if card.rank == 1 {
            11 // Ace as 11 initially
        } else {
            10 //Face cards (J,Q,K)
        }
    }

    pub fn new_hand() -> Hand {
        Hand { cards: [Card { rank: 0, suit: 0 }; 10], card_count: 0, bust: false }
    }

    pub fn hand_points(hand: Hand) -> Field {
        let mut points = 0;
        let mut aces = 0;

        for i in 0..hand.card_count as u8 {
            let card_points = card_points(hand.cards[i]);
            if card_points == 1 {
                aces += 1;
            }
            points += card_points;
        }

        for _ in 0..aces {
            if points as u8 > 21 {
                points -= 10; //convert ace from 11 to 1 if needed
                aces -= 1;
            }
        }
        points
    }

    pub fn check_bust(hand: Hand) -> bool {
        hand_points(hand) as u8 > 21
    }

    pub fn generate_deck() -> Deck {
        let mut deck: Deck = Deck { cards: [Card { rank: 0, suit: 0 }; 52] };
        let mut index = 0;
        for suit in 1..=4 {
            for rank in 1..=13 {
                deck.cards[index] = new(rank as Field, suit as Field);
                index += 1;
            }
        }
        deck
    }

    pub fn draw_card(deck: Deck, index: Field) -> Card {
        deck.cards[index as u8]
    }
}
