# Aztec Private Blackjack

A fully private implementation of Blackjack running on the Aztec Network. Players can enjoy classic blackjack gameplay with complete transaction privacy, including betting, hitting, standing, splitting, and insurance options.

## Features

- Private betting with ERC20 tokens
- Classic blackjack gameplay mechanics
- Double down functionality
- Split hands
- Insurance bets
- Fully private game state
- React-based UI with Tailwind styling

## Prerequisites

- Node.js (v18+)
- Yarn
- [Aztec CLI](https://docs.aztec.network/dev_docs/getting_started/quickstart)

## Installation

1. Clone the repository:

```bash
git clone https://github.com/yourusername/aztec-blackjack.git

cd aztec-blackjack
```

2. Install dependencies:

```bash
yarn install
```

3. Start the Aztec Sandbox (in a separate terminal):

- Make sure the versions of the sandbox, nargo.toml and aztec.js are the same

```bash
aztec start --sandbox
```

4. Compile the Noir contracts and generate artifacts:

```bash
yarn prep
```

5. Start the development server:

```bash
yarn dev
```

The app will be available at `http://localhost:8080`

## Testing

Run the full test suite (both Noir and TypeScript tests):

```bash
yarn test
```

Run only the Noir contract tests:

```bash
cd src/circuits
aztec test
```

Run only the TypeScript integration tests:

```bash
yarn test:node
```

## Project Structure

- `/src/circuits/` - Noir smart contracts
  - `/src/circuits/src/main.nr` - Main blackjack contract
  - `/src/circuits/src/notes/` - Note implementations for cards and values
  - `/src/circuits/src/helpers/` - Helper functions for game logic
- `/src/pages/` - React components
- `/src/components/` - Reusable UI components
- `/src/contexts/` - React context providers
- `/test/` - Integration tests

## Game Rules

1. Place a bet using supported ERC20 tokens
2. Receive two cards and view the dealer's up card
3. Choose to:
   - Hit (take another card)
   - Stand (keep current hand)
   - Double Down (double bet and take one card)
   - Split (if you have matching cards)
   - Take Insurance (if dealer shows an Ace)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to your branch
5. Open a Pull Request

## License

MIT
