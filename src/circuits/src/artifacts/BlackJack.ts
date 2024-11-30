
/* Autogenerated file, do not edit! */

/* eslint-disable */
import {
  type AbiType,
  AztecAddress,
  type AztecAddressLike,
  CompleteAddress,
  Contract,
  type ContractArtifact,
  ContractBase,
  ContractFunctionInteraction,
  type ContractInstanceWithAddress,
  type ContractMethod,
  type ContractStorageLayout,
  type ContractNotes,
  decodeFromAbi,
  DeployMethod,
  EthAddress,
  type EthAddressLike,
  EventSelector,
  type FieldLike,
  Fr,
  type FunctionSelectorLike,
  L1EventPayload,
  loadContractArtifact,
  type NoirCompiledContract,
  NoteSelector,
  Point,
  type PublicKey,
  PublicKeys,
  type UnencryptedL2Log,
  type Wallet,
  type WrappedFieldLike,
} from '@aztec/aztec.js';
import BlackJackContractArtifactJson from '../../target/blackjack-BlackJack.json' assert { type: 'json' };
export const BlackJackContractArtifact = loadContractArtifact(BlackJackContractArtifactJson as NoirCompiledContract);



/**
 * Type-safe interface for contract BlackJack;
 */
export class BlackJackContract extends ContractBase {
  
  private constructor(
    instance: ContractInstanceWithAddress,
    wallet: Wallet,
  ) {
    super(instance, BlackJackContractArtifact, wallet);
  }
  

  
  /**
   * Creates a contract instance.
   * @param address - The deployed contract's address.
   * @param wallet - The wallet to use when interacting with the contract.
   * @returns A promise that resolves to a new Contract instance.
   */
  public static async at(
    address: AztecAddress,
    wallet: Wallet,
  ) {
    return Contract.at(address, BlackJackContract.artifact, wallet) as Promise<BlackJackContract>;
  }

  
  /**
   * Creates a tx to deploy a new instance of this contract.
   */
  public static deploy(wallet: Wallet, ) {
    return new DeployMethod<BlackJackContract>(PublicKeys.default(), wallet, BlackJackContractArtifact, BlackJackContract.at, Array.from(arguments).slice(1));
  }

  /**
   * Creates a tx to deploy a new instance of this contract using the specified public keys hash to derive the address.
   */
  public static deployWithPublicKeys(publicKeys: PublicKeys, wallet: Wallet, ) {
    return new DeployMethod<BlackJackContract>(publicKeys, wallet, BlackJackContractArtifact, BlackJackContract.at, Array.from(arguments).slice(2));
  }

  /**
   * Creates a tx to deploy a new instance of this contract using the specified constructor method.
   */
  public static deployWithOpts<M extends keyof BlackJackContract['methods']>(
    opts: { publicKeys?: PublicKeys; method?: M; wallet: Wallet },
    ...args: Parameters<BlackJackContract['methods'][M]>
  ) {
    return new DeployMethod<BlackJackContract>(
      opts.publicKeys ?? PublicKeys.default(),
      opts.wallet,
      BlackJackContractArtifact,
      BlackJackContract.at,
      Array.from(arguments).slice(1),
      opts.method ?? 'constructor',
    );
  }
  

  
  /**
   * Returns this contract's artifact.
   */
  public static get artifact(): ContractArtifact {
    return BlackJackContractArtifact;
  }
  

  public static get storage(): ContractStorageLayout<'player_hand' | 'split_hand' | 'dealer_hand' | 'player_bust' | 'dealer_bust' | 'blackjack' | 'bet' | 'split_bet' | 'insurance' | 'token' | 'has_split' | 'double_down' | 'game_state'> {
      return {
        player_hand: {
      slot: new Fr(1n),
    },
split_hand: {
      slot: new Fr(2n),
    },
dealer_hand: {
      slot: new Fr(3n),
    },
player_bust: {
      slot: new Fr(4n),
    },
dealer_bust: {
      slot: new Fr(5n),
    },
blackjack: {
      slot: new Fr(6n),
    },
bet: {
      slot: new Fr(7n),
    },
split_bet: {
      slot: new Fr(8n),
    },
insurance: {
      slot: new Fr(9n),
    },
token: {
      slot: new Fr(10n),
    },
has_split: {
      slot: new Fr(11n),
    },
double_down: {
      slot: new Fr(12n),
    },
game_state: {
      slot: new Fr(13n),
    }
      } as ContractStorageLayout<'player_hand' | 'split_hand' | 'dealer_hand' | 'player_bust' | 'dealer_bust' | 'blackjack' | 'bet' | 'split_bet' | 'insurance' | 'token' | 'has_split' | 'double_down' | 'game_state'>;
    }
    

  public static get notes(): ContractNotes<'AddressNote' | 'UintNote' | 'ValueNote' | 'CardNote'> {
    return {
      AddressNote: {
          id: new NoteSelector(2232136525),
        },
UintNote: {
          id: new NoteSelector(202136239),
        },
ValueNote: {
          id: new NoteSelector(1038582377),
        },
CardNote: {
          id: new NoteSelector(3719046069),
        }
    } as ContractNotes<'AddressNote' | 'UintNote' | 'ValueNote' | 'CardNote'>;
  }
  

  /** Type-safe wrappers for the public methods exposed by the contract. */
  public declare methods: {
    
    /** begin_game() */
    begin_game: (() => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** compute_note_hash_and_optionally_a_nullifier(contract_address: struct, nonce: field, storage_slot: field, note_type_id: field, compute_nullifier: boolean, serialized_note: array) */
    compute_note_hash_and_optionally_a_nullifier: ((contract_address: AztecAddressLike, nonce: FieldLike, storage_slot: FieldLike, note_type_id: FieldLike, compute_nullifier: boolean, serialized_note: FieldLike[]) => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** constructor() */
    constructor: (() => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** contract_address() */
    contract_address: (() => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** dealer_hand() */
    dealer_hand: (() => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** dealer_points() */
    dealer_points: (() => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** double_down() */
    double_down: (() => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** get_bet() */
    get_bet: (() => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** get_split_hand() */
    get_split_hand: (() => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** get_token() */
    get_token: (() => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** is_blackjack_view() */
    is_blackjack_view: (() => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** is_dealer_bust_view() */
    is_dealer_bust_view: (() => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** is_player_bust_view() */
    is_player_bust_view: (() => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** make_bet(bet: field, token: struct) */
    make_bet: ((bet: FieldLike, token: AztecAddressLike) => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** place_insurance_bet() */
    place_insurance_bet: (() => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** player_hand() */
    player_hand: (() => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** player_hit(hand: integer) */
    player_hit: ((hand: (bigint | number)) => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** player_points() */
    player_points: (() => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** player_stand() */
    player_stand: (() => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** public_dispatch(selector: field) */
    public_dispatch: ((selector: FieldLike) => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** reset_game() */
    reset_game: (() => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** split() */
    split: (() => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** split_points() */
    split_points: (() => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;

    /** sync_notes() */
    sync_notes: (() => ContractFunctionInteraction) & Pick<ContractMethod, 'selector'>;
  };

  
}
