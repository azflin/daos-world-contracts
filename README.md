# DaoWorld Smart Contract System

A comprehensive smart contracts for Daos.World ecosystem.

## Core Components

### DAO's World Main Contracts

- **DaosWorldFactoryV1**: Factory contract for creating new DAOs
- **DaosWorldV1**: Main DAO contract with fundraising and treasury management
- **DaosWorldV1Token**: ERC20 token implementation for DAOs

### LP Factory Contracts

- **DaosWorldShitcoinFactory**: Factory for creating tokens with automated Uniswap V3 liquidity
- **DaosWorldShitcoin**: Simple ERC20 token implementation
- **PriceHelper**: Utility library for Uniswap V3 price calculations

### LP Locker Contracts

- **LockerFactory**: Factory for creating liquidity lockers
- **LpLocker**: Contract for time-locking Uniswap V3 LP positions

## Contract Details

### DAO System

#### DaosWorldFactoryV1.sol

- Creates new DAO instances
- Controls gated deployments
- Manages whitelisted deployers
- Uses WETH on Base network

#### DaosWorldV1.sol

Main DAO contract featuring:

- Fundraising mechanism with goals and deadlines
- Whitelist management
- Treasury management
- Uniswap V3 integration
- Fund expiry controls

#### DaosWorldV1Token.sol

- Standard ERC20 implementation
- Used as the base token for DAOs
- Managed by the DAO treasury

### LP Factory System

#### DaosWorldShitcoinFactory.sol

Features:

- Creates ERC20 tokens
- Automatic Uniswap V3 pool creation
- Initial liquidity provision
- Configurable pool parameters
- Whitelist system for creators

#### DaosWorldShitcoin.sol

- Simple ERC20 implementation
- One-time mint on creation
- Fixed total supply

### LP Locker System

#### LockerFactory.sol

- Creates new LP locker instances
- Manages protocol administration
- Tracks deployed lockers

#### LpLocker.sol

Features:

- Time-locks Uniswap V3 LP positions
- Fee collection and distribution
- Extendable lock duration
- Protocol fee management

## Development

### Prerequisites

- Foundry
- Node.js
- Git

### Installation

```bash
# Clone the repository
git clone <repository-url>

# Install dependencies
forge install
```

### Environment Setup

Create a `.env` file:

```env
RPC_URL=                  # Base Mainnet RPC URL
PRIVATE_KEY=             # Deployment private key
ETHERSCAN_API_KEY=       # Basescan API key
```

### Build & Test

```bash
# Build contracts
forge build

# Run tests
forge test

# Run tests with gas reporting
forge test --gas-report

# Format code
forge fmt
```

### Deployment

```bash
# Check deployments (dry-run)
make check_shitcoin_factory     # Check DaosWorldShitcoinFactory deployment
make check_factory_v2           # Check DaosWorldFactoryV2 deployment

# Deploy contracts
make deploy_shitcoin_factory    # Deploy DaosWorldShitcoinFactory 
make deploy_factory_v2          # Deploy DaosWorldFactoryV2 
```

## Documentation

For detailed documentation:

- [Foundry Book](https://book.getfoundry.sh/)
- [Uniswap V3 Docs](https://docs.uniswap.org/protocol/reference/periphery/NonfungiblePositionManager)
- [OpenZeppelin Docs](https://docs.openzeppelin.com/)

## Security

- All contracts use OpenZeppelin's secure implementations
- Reentrancy guards on critical functions
- Time-locked mechanisms for fund management
- Access control for administrative functions
