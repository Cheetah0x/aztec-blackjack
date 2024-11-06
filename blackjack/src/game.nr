global NUMBER_OF_CARDS: u8 = 52;
global NUMBER_OF_DECKS: u8 = 1;

pub struct Game {
    Id: Field,
    Player: AztecAddress,

    SafeBalance: Field,
    OriginalBalance: Field,
    SplitCounter: Field,
    GamesPlayed: Field,

    PlayerBet: Field,
    InsuranceBet: Field,
    PlayerCard1: Field,
    PlayerCard2: Field,
    PlayerNewCard: Field,
    PlayerCardTotal: Field,
    PlayerSplitTotal: Field,

    DealerCard1: Field,
    DealerCard2: Field,
    DealerNewCard: Field,
    DealerCardTotal: Field,

    CanDoubleDown: bool,
    CanInsure: bool,
    CanSplit: bool,
    IsSplitting: bool,
    IsSoftHand: bool,

    IsRoundInProgress: bool,

    DealerMsg: Field, //compresses string or something
}
