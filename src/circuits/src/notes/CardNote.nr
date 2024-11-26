use dep::aztec::{
    context::PrivateContext,
    encrypted_logs::encrypted_note_emission::encode_and_encrypt_note,
    keys::getters::{get_nsk_app, get_public_keys},
    macros::notes::note,
    note::{
        note_header::NoteHeader, note_interface::NullifiableNote,
        utils::compute_note_hash_for_nullify,
    },
    oracle::random::random,
    protocol_types::{
        address::AztecAddress,
        constants::GENERATOR_INDEX__NOTE_NULLIFIER,
        hash::poseidon2_hash_with_separator,
        traits::{Deserialize, FromField, Serialize, ToField},
    },
    state_vars::PrivateSet,
};

// Custom Address Note implementation, as the default one lacks serialization and the Eq trait.

//---------------------------CARD Properties--------------------------------

#[derive(Serialize)]
#[derive(Deserialize)]
pub struct Card {
    rank: u64,
    suit: u64,
}

impl FromField for Card {
    fn from_field(field: Field) -> Card {
        let value_bytes: [u8; 32] = field.to_le_bytes();
        let rank_raw = ((value_bytes[0] as u64) + (value_bytes[1] as u64) * 256) % 13 + 1; // Ranks from 1 to 13
        let suit = ((value_bytes[2] as u64) + (value_bytes[3] as u64) * 256) % 4 + 1; // Suits from 1 to 4
        // Cap the rank at 10
        let rank = if rank_raw > 10 { 10 } else { rank_raw } as u64;

        Card { rank, suit: suit as u64 }
    }
}

impl ToField for Card {
    fn to_field(self) -> Field {
        self.rank as Field + self.suit as Field * 65536
    }
}

impl Eq for Card {
    fn eq(self, other: Self) -> bool {
        (self.rank == other.rank) & (self.suit == other.suit)
    }
}

fn card_id(rank: u64, suit: u64) -> u64 {
    (suit as u64) * 13 + (rank as u64) - 1 // Ranks from 1 to 13
}

//----------------------------DECK--------------------------------

pub struct Deck {
    card: Card,
}

impl Deck {
    pub fn new(card: Card) -> Self {
        Deck { card }
    }
}

impl Serialize<1> for Deck {
    fn serialize(self) -> [Field; 1] {
        [self.card.to_field()]
    }
}

impl Deserialize<1> for Deck {
    fn deserialize(fields: [Field; 1]) -> Self {
        Deck { card: Card::from_field(fields[0]) }
    }
}

impl Deck {
    pub fn add_card(
        &mut self,
        owner: AztecAddress,
        card: Card,
        storage: &mut PrivateSet<CardNote, &mut PrivateContext>,
        context: &mut PrivateContext,
    ) {
        let msg_sender_ovpk_m = get_public_keys(context.msg_sender()).ovpk_m;

        let mut card_note = CardNote::new(card, owner);
        storage.insert(&mut card_note).emit(encode_and_encrypt_note(
            context,
            msg_sender_ovpk_m,
            owner,
            owner,
        ));
    }
}

//---------------------------CARD NOTE--------------------------------

#[note]
struct CardNote {
    card: Card, // The card with the value and suit in the hand
    // The nullifying public key hash is used with the nsk_app to ensure that the note can be privately spent.
    randomness: Field,
    owner: AztecAddress,
}

impl NullifiableNote for CardNote {

    /**
     * Computes the nullifier for the note using the provided private context.
     * This is necessary to ensure that the note can be nullified (spent) privately.
     *
     * @param context - A mutable reference to the private context, used to retrieve the note's nullifying secret key.
     * @param note_hash_for_nullify - The precomputed note hash used as part of the nullifier.
     * @returns A `Field` value representing the nullifier for this note.
     */
    fn compute_nullifier(
        self,
        context: &mut PrivateContext,
        note_hash_for_nullify: Field,
    ) -> Field {
        // Retrieves the nullifying secret key from the context.
        let owner_npk_m_hash = get_public_keys(self.owner).npk_m.hash();
        let secret = context.request_nsk_app(owner_npk_m_hash);

        // Uses Poseidon hashing to compute the nullifier, incorporating the note hash and the secret.
        poseidon2_hash_with_separator(
            [note_hash_for_nullify, secret],
            GENERATOR_INDEX__NOTE_NULLIFIER as Field,
        )
    }

    /**
     * Computes the nullifier for the note without needing the context.
     * This is an unconstrained function that allows generating the nullifier for use in tests or specific use cases
     * where the context is not required.
     *
     * @returns Field value representing the nullifier for this note, computed without context.
     */
    unconstrained fn compute_nullifier_without_context(self) -> Field {
        // Computes the note hash for nullification.
        let note_hash_for_nullify = compute_note_hash_for_nullify(self);
        let owner_npk_m_hash = get_public_keys(self.owner).npk_m.hash();
        // Retrieves the nullifying secret key directly without context.
        let secret = get_nsk_app(owner_npk_m_hash);

        // Uses Poseidon hashing to compute the nullifier, incorporating the note hash and the secret.
        poseidon2_hash_with_separator(
            [note_hash_for_nullify, secret],
            GENERATOR_INDEX__NOTE_NULLIFIER as Field,
        )
    }
}

impl CardNote {
    /**
     * Creates a new instance of `CardNote` with the provided Aztec address and nullifying public key hash.
     * 
     * @param address - The AztecAddress associated with the note.
     * @param npk_m_hash - The nullifying public key hash, used to ensure private spending.
     * @returns A new `CardNote` instance.
     */
    pub fn new(card: Card, owner: AztecAddress) -> Self {
        // Ensure the card rank is capped at 10
        let rank_capped = if card.rank > 10 { 10 } else { card.rank };
        let card_capped = Card { rank: rank_capped, suit: card.suit };

        let randomness = unsafe { random() };
        let header = NoteHeader::empty();
        CardNote { card: card_capped, randomness, owner, header }
    }
}

impl Eq for CardNote {
    /**
     * Custom equality implementation for `CardNote`.
     * Compares the card and owner fields to determine if two notes are equal.
     *
     * @param other - The other note to compare with.
     * @returns `true` if both notes are equal, `false` otherwise.
     */
    fn eq(self, other: Self) -> bool {
        (self.card == other.card)
            & (self.owner == other.owner)
            & (self.randomness == other.randomness)
    }
}

impl Serialize<3> for CardNote {
    fn serialize(self) -> [Field; 3] {
        [self.card.to_field(), self.randomness, self.owner.to_field()]
    }
}

impl Deserialize<3> for CardNote {
    fn deserialize(fields: [Field; 3]) -> Self {
        CardNote {
            card: Card::from_field(fields[0]),
            randomness: fields[1],
            owner: AztecAddress::from_field(fields[2]),
            header: NoteHeader::empty(),
        }
    }
}

//----------------------------Game Actions--------------------------------

