// //try to make a blackjack game.
// //will make it public first, then private

// // mod CardNote;

// use dep::aztec::macros::aztec;

// #[aztec]
// contract BlackJack {

//     use aztec::{
//         macros::{events::event, functions::{initializer, public, view}, storage::storage},
//         prelude::{AztecAddress, Map, PublicImmutable, PublicMutable},
//         protocol_types::{point::Point, traits::Serialize},
//     };

//     global DepositLowLimit = 1;
//     global DepositHighLimit = 1000;

//     global BetLowLimit = 1;
//     global BetHighLimit = 1000;

//     #[storage]
//     struct Storage<Context> {
//         rng_counter: PublicMutable<Field, Context>,
//         index_counter: PublicMutable<Field, Context>,
//         owner: PublicImmutable<AztecAddress, Context>,
//         current_players_to_game_id_map: Map<AztecAddress, PublicMutable<Field, Context>, Context>,
//     }

//     global NUMBER_OF_CARDS: u8 = 52;
//     global NUMBER_OF_DECKS: u8 = 1;

//     pub struct Game {
//         Id: Field,
//         Player: AztecAddress,

//         SafeBalance: Field,
//         OriginalBalance: Field,
//         SplitCounter: Field,
//         GamesPlayed: Field,

//         PlayerBet: Field,
//         InsuranceBet: Field,
//         PlayerCard1: Field,
//         PlayerCard2: Field,
//         PlayerNewCard: Field,
//         PlayerCardTotal: Field,
//         PlayerSplitTotal: Field,

//         DealerCard1: Field,
//         DealerCard2: Field,
//         DealerNewCard: Field,
//         DealerCardTotal: Field,

//         CanDoubleDown: bool,
//         CanInsure: bool,
//         CanSplit: bool,
//         IsSplitting: bool,
//         IsSoftHand: bool,

//         IsRoundInProgress: bool,

//         DealerMsg: Field, //compresses string or something
//     }

//     #[derive(Serialize)]
//     #[event]
//     struct StartNewGame {
//         GameId: Field,
//         Player: AztecAddress,
//         Amount: Field,
//     }

//     #[derive(Serialize)]
//     #[event]
//     struct CashOutEvent {
//         GameId: Field,
//         Player: AztecAddress,
//         Amount: Field,
//     }

//     #[derive(Serialize)]
//     #[event]
//     struct BeforeValueTransferEvent {
//         GameId: Field,
//         Player: AztecAddress,
//         Amount: Field,
//     }

//     #[derive(Serialize)]
//     #[event]
//     struct AfterValueTransferEvent {
//         Player: AztecAddress,
//     }

//     #[initializer]
//     #[public]
//     fn constructor(owner: AztecAddress) {
//         storage.rng_counter.write(1);
//         storage.index_counter.write(1);
//         storage.owner.initialize(owner);
//     }

//     #[public]
//     fn start_new_game(amount: Field) {
//         //do not worry to much about the assertions for now
//         let player_game_id = storage.current_players_to_game_id_map.at(context.msg_sender()).read();
//         assert(
//             (amount as u32 >= DepositLowLimit) & (amount as u32 <= DepositHighLimit),
//             "Invalid deposit amount",
//         );

//         //initialize the game
//         let mut game = Game {
//             Id: storage.index_counter.read(),
//             Player: context.msg_sender(),
//             SafeBalance: amount,
//             OriginalBalance: amount,
//             SplitCounter: 0,
//             GamesPlayed: 0,
//             PlayerBet: 0,
//             InsuranceBet: 0,
//             PlayerCard1: 0,
//             PlayerCard2: 0,
//             PlayerNewCard: 0,
//             PlayerCardTotal: 0,
//             PlayerSplitTotal: 0,
//             DealerCard1: 0,
//             DealerCard2: 0,
//             DealerNewCard: 0,
//             DealerCardTotal: 0,
//             CanDoubleDown: false,
//             CanInsure: false,
//             CanSplit: false,
//             IsSplitting: false,
//             IsSoftHand: false,
//             IsRoundInProgress: true,
//             DealerMsg: 0, // Placeholder for compressed string
//         };

//         // Update the index counter
//         storage.index_counter.write(game.Id + 1);

//         // Map the player to the new game ID
//         storage.current_players_to_game_id_map.at(context.msg_sender()).write(game.Id);

//         //emit event
//         context.emit_unencrypted_log(
//             StartNewGame { GameId: game.Id, Player: game.Player, Amount: game.OriginalBalance },
//         );
//     }

//     #[public]
//     fn place_bet(amount: Field, player: AztecAddress, mut game: Game) {
//         // Retrieve the player's game ID
//         let player_game_id = storage.current_players_to_game_id_map.at(player).read();
//         assert(player_game_id != 0, "Game_DNE");

//         // Ensure the round is not already in progress
//         assert(!game.IsRoundInProgress, "IsNewRound_Only");

//         // Ensure the bet is within the allowed limits
//         assert(
//             (amount as u32 >= BetLowLimit) & (amount as u32 <= BetHighLimit),
//             "Bet_Limit",
//         );

//         // Ensure the player has enough balance to place the bet
//         assert(
//             (amount as u32 > 0) & (amount as u32 <= game.SafeBalance as u32),
//             "INS_Funds",
//         );

//         // Update the game state with the new bet
//         game.SafeBalance -= amount;
//         if game.CanDoubleDown || game.CanSplit {
//             game.PlayerBet += amount;
//         } else {
//             game.PlayerBet = amount;
//         }

//         // Mark the round as in progress
//         game.IsRoundInProgress = true;

//         // Increment the games played counter
//         game.GamesPlayed += 1;

//         // Update the game in storage
//         storage.ids_to_game_map.at(player_game_id).write(game);

//         // Emit an event or update the game state as needed
//         // context.emit_unencrypted_log(...);
// }

// }
