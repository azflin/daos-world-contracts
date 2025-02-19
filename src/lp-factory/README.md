# DaoWorld Token & LP Factory

A smart contract system for creating ERC20 tokens and automatically adding liquidity to Uniswap V3. The system is designed to create tokens with initial liquidity pairs against WETH, making them immediately tradeable.

## Overview

The project provides a factory contract that:

- Creates new ERC20 tokens
- Automatically adds liquidity to Uniswap V3
- Sets initial price based on desired market cap
- Manages whitelisted addresses that can create tokens
- Configurable pool percentage for initial liquidity

## Core Contracts

### DaosWorldShitcoinFactory.sol

The main factory contract that orchestrates token creation and liquidity provision. Features:

- Creates new ERC20 tokens
- Adds initial WETH/Token liquidity with 1% fee tier
- Whitelist system for token creators
- Configurable pool percentage (default 10%)
- Two-step ownership transfer
- Initial market cap of 30 ETH

### DaosWorldShitcoin.sol

A simple ERC20 token implementation that:

- Inherits from OpenZeppelin's ERC20
- Mints total supply to creator
- Used as the base token for all created tokens

### Libraries

#### PriceHelper.sol (internal)

Utility library for price calculations:

- Calculates sqrtPriceX96 for Uniswap V3 pool initialization
- Handles price conversion based on token/WETH ordering

#### TickMath.sol (external)

Uniswap V3 library for tick calculations:

- Computes sqrt prices from ticks
- Handles tick-to-price conversions
- Supports prices between 2**-128 and 2**128

## Environment Setup

Create a `.env` file with the following variables:

```env
# RPC URL for the network (Base Mainnet)
RPC_URL=

# Private key for deployment
PRIVATE_KEY=

# Etherscan API key for verification (basescan API_KEY)
ETHERSCAN_API_KEY=
```

## Available Commands

The project includes several make commands for deployment and verification:

```bash
# Deploy factory to Base Mainnet
make deploy_dao_world

# Check deployment parameters
make check_dao_world
```

## Development

### Install Foundry

First, you'll need to install Foundry:

```bash
curl -L https://foundry.paradigm.xyz | bash
```

Then restart your terminal session and run:

```bash
foundryup
```

This will install `forge`, `cast`, and `anvil`.

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

## Testing

The test suite includes comprehensive tests for:

- Token creation
- Liquidity provision
- Access control
- Price calculations
- Error cases

Run tests with:

```bash
forge test -vv
```

## Documentation

For more detailed documentation on the tools used:

- [Foundry Book](https://book.getfoundry.sh/)
- [Uniswap V3 Docs](https://docs.uniswap.org/protocol/reference/periphery/NonfungiblePositionManager)
