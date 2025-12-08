# Foundry DeFi Stablecoin

**⚠️ This is an educational project - not audited, use at your own risk**

## Table of Contents

- [Foundry DeFi Stablecoin](#foundry-defi-stablecoin)
  - [Table of Contents](#table-of-contents)
  - [About](#about)
    - [Key Features](#key-features)
    - [Architecture](#architecture)
  - [Getting Started](#getting-started)
    - [Requirements](#requirements)
    - [Quickstart](#quickstart)
    - [Environment Setup](#environment-setup)
  - [Usage](#usage)
    - [Build](#build)
    - [Testing](#testing)
    - [Test Coverage](#test-coverage)
    - [Deploy Locally](#deploy-locally)
    - [Interact with Contract](#interact-with-contract)
  - [Deployment](#deployment)
    - [Deploy to Testnet](#deploy-to-testnet)
    - [Verify Contract](#verify-contract)
    - [Deployment Addresses](#deployment-addresses)
  - [Security](#security)
    - [Audit Status](#audit-status)
    - [Known Limitations](#known-limitations)
  - [Gas Optimization](#gas-optimization)
  - [Contributing](#contributing)
  - [License](#license)

## About

The Decentralized Stablecoin (DSC) is a collateral-backed stablecoin system that maintains a 1:1 USD peg through algorithmic minting and burning mechanisms. The system is overcollateralized using wETH and wBTC, leveraging Chainlink price feeds for secure oracle-based valuations.

### Key Features

- **Decentralized Stablecoin (DSC)**: ERC20 token pegged to USD
- **Overcollateralized System**: Requires >150% collateral ratio to maintain peg stability
- **Dual Collateral Support**: Accepts wETH and wBTC as collateral
- **Oracle-Driven**: Uses Chainlink V3 price feeds for real-time price data
- **Liquidation Mechanism**: Allows liquidators to restore health factor when users become undercollateralized
- **Comprehensive Testing**: Includes unit tests, integration tests, and advanced invariant testing with fuzz handlers

**Tech Stack:**
- Solidity ^0.8.19
- Foundry (Forge + Anvil)
- OpenZeppelin Contracts
- Chainlink Price Feeds

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Users/EOAs                             │
└─────────────┬────────────────┬──────────────┬───────────────┘
              │                │              │
       deposit/mint     withdraw/burn   liquidate()
              │                │              │
              ▼                ▼              ▼
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│                      DSCEngine.sol                           │
│                   (Core Protocol Logic)                      │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  • Deposit/Withdraw Collateral (wETH, wBTC)        │    │
│  │  • Mint/Burn DSC Tokens                            │    │
│  │  • Health Factor Calculation                       │    │
│  │  • Liquidation Logic                               │    │
│  │  • Reentrancy Protection (ReentrancyGuard)        │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                              │
└───────────────┬──────────────────────────┬──────────────────┘
                │                          │
                ▼                          ▼
    ┌───────────────────────┐  ┌──────────────────────┐
    │ DecentralizedStable   │  │ OracleLib.sol        │
    │ Coin.sol (ERC20)      │  │ (Price Validation)   │
    │                       │  │                      │
    │ • DSC Token Transfer  │  │ • Price Feed Check   │
    │ • Mint/Burn Functions │  │ • Stale Price Detect │
    └───────────────────────┘  └──────────────────────┘
                                        │
                                        │ queries
                                        ▼
                            ┌──────────────────────┐
                            │  Chainlink Oracles   │
                            │   (wETH/USD, wBTC)   │
                            │    Price Feeds       │
                            └──────────────────────┘
```

**Repository Structure:**
```
foundry-defi-stablecoin/
├── src/
│   ├── DSCEngine.sol                  # Core protocol engine
│   ├── DecentralizedStableCoin.sol    # ERC20 stablecoin token
│   └── libraries/
│       └── OracleLib.sol              # Price feed validation & safety
├── script/
│   ├── DeployDSC.s.sol               # Main deployment script
│   └── HelperConfig.s.sol            # Network configuration helper
├── test/
│   ├── unit/
│   │   ├── DSCEngineTest.t.sol        # Unit tests for DSCEngine
│   │   └── DecentralizedStableCoinTest.t.sol  # Token unit tests
│   ├── integration/
│   │   └── DeployDSCTest.t.sol        # Deployment integration tests
│   ├── mocks/
│   │   └── MockV3Aggregator.sol       # Mock Chainlink price feed
│   └── fuzz/
│       ├── failOnRevert/
│       │   ├── Handler.t.sol          # Fuzz action handler
│       │   └── InvariantsTest.t.sol   # Invariant tests (fail on revert)
│       └── continueOnRevert/
│           └── OpenInvariantsTest.t.sol  # Invariant tests (continue on revert)
├── lib/
│   ├── forge-std/                     # Foundry standard library
│   ├── openzeppelin-contracts/        # OpenZeppelin ERC20 & utilities
│   └── chainlink-brownie-contracts/   # Chainlink price feed interfaces
├── foundry.toml                       # Foundry configuration
├── Makefile                           # Build & test commands
└── README.md                          # This file
```

## Getting Started

### Requirements

- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  - Verify installation: `git --version`
- [foundry](https://getfoundry.sh/)
  - Verify installation: `forge --version`

### Quickstart

```bash
git clone https://github.com/0xGearhart/foundry-defi-stablecoin
cd foundry-defi-stablecoin
forge install
forge build
```

### Environment Setup

1. **Copy the environment template:**
   ```bash
   cp .env.example .env
   ```

2. **Configure your `.env` file:**
   ```bash
   SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/your-api-key
   MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/your-api-key
   ETHERSCAN_API_KEY=your_etherscan_api_key_here
   DEFAULT_KEY_ADDRESS=public_address_of_your_encrypted_private_key_here
   ```

3. **Get testnet ETH:**
   - Sepolia Faucet: [Google Cloud Faucet](https://cloud.google.com/application/web3/faucet/ethereum/sepolia)

**⚠️ Security Warning:**
- Never commit your `.env` file
- Never use your mainnet private key for testing
- Use a separate wallet with only testnet funds for development

## Usage

### Build

Compile the contracts:

```bash
forge build
```

### Testing

Run the test suite:

```bash
forge test
```

Run tests with verbosity:

```bash
forge test -vvv
```

Run specific test:

```bash
forge test --match-test testFunctionName
```

### Test Coverage

Generate coverage report:

```bash
forge coverage
```

### Deploy Locally

Start a local Anvil node:

```bash
make anvil
```

Deploy to local node (in another terminal):

```bash
make deploy
```

### Interact with Contract

Once deployed, you can interact with the DSC system using cast:

```bash
# Approve collateral spending
cast send <COLLATERAL_ADDRESS> "approve(address,uint256)" <DSC_ENGINE_ADDRESS> <AMOUNT> --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Deposit collateral (wETH example)
cast send <DSC_ENGINE_ADDRESS> "depositCollateral(address,uint256)" <WETH_ADDRESS> <AMOUNT> --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Mint DSC
cast send <DSC_ENGINE_ADDRESS> "mintDsc(uint256)" <DSC_AMOUNT> --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Check health factor
cast call <DSC_ENGINE_ADDRESS> "getHealthFactor(address)" <YOUR_ADDRESS> --rpc-url $SEPOLIA_RPC_URL

# Get collateral value
cast call <DSC_ENGINE_ADDRESS> "getCollateralValueInUsd(address,address)" <USER_ADDRESS> <COLLATERAL_ADDRESS> --rpc-url $SEPOLIA_RPC_URL
```

## Deployment

### Deploy to Testnet

Deploy to Sepolia:

```bash
make deploy ARGS="--network sepolia"
```

Or using forge directly:

```bash
forge script script/DeployContract.s.sol:DeployContract --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY -vvvv
```

### Verify Contract

If automatic verification fails:

```bash
forge verify-contract <CONTRACT_ADDRESS> src/MainContract.sol:MainContract --chain-id 11155111 --etherscan-api-key $ETHERSCAN_API_KEY
```

### Deployment Addresses

| Network | Contract | Address | Explorer |
|---------|----------|---------|----------|
| Sepolia | DSCEngine | `TBD` | [View on Etherscan](https://sepolia.etherscan.io) |
| Sepolia | DecentralizedStableCoin | `TBD` | [View on Etherscan](https://sepolia.etherscan.io) |
| Mainnet | DSCEngine | `TBD` | [View on Etherscan](https://etherscan.io) |
| Mainnet | DecentralizedStableCoin | `TBD` | [View on Etherscan](https://etherscan.io) |

## Security

### Audit Status

⚠️ **This contract has not been audited.** Use at your own risk.

For production use, consider:
- Professional security audit
- Bug bounty program
- Gradual rollout with monitoring

### Known Limitations

- **Centralized Price Feeds**: System relies on Chainlink price feeds; oracle failure will impact system stability
- **Fixed Collateral Types**: Currently limited to wETH and wBTC; adding new collateral requires contract updates
- **No Governance**: All protocol parameters are immutable; no governance mechanism for protocol upgrades
- **Liquidation Incentives**: Fixed liquidation bonus; no dynamic incentive adjustment based on market conditions
- **No Flash Loan Protection**: Potential vulnerability to flash loan attacks (educational project)

**Centralization Risks:**
- Owner/deployer has ability to set collateral addresses and price feeds during initialization
- No timelock mechanism for critical operations

**Oracle Dependencies:**
- System security depends on Chainlink oracle accuracy and availability
- Uses secondary price feed validation in OracleLib to prevent stale prices
- If both ETH and BTC price feeds fail, system cannot mint new DSC

## Gas Optimization

| Function                      | Gas Cost |
|-------------------------------|----------|
| `depositCollateral`           | ~63,764  |
| `depositCollateralAndMintDsc` | ~164,508 |
| `redeemCollateral`            | ~107,850 |
| `redeemCollateralForDsc`      | ~142,603 |
| `burnDsc`                     | ~101,956 |
| `mintDsc`                     | ~105,403 |
| `liquidate`                   | ~95,657  |

Generate gas report:

```bash
forge test --gas-report
```

Generate gas snapshot:

```bash
forge snapshot
```

Compare gas changes:

```bash
forge snapshot --diff
```

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Disclaimer:** This software is provided "as is", without warranty of any kind. Use at your own risk.

**Built with [Foundry](https://getfoundry.sh/)**