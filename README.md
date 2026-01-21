# Foundry DeFi Stablecoin

**⚠️ This project is not audited, use at your own risk**

## Table of Contents

- [Foundry DeFi Stablecoin](#foundry-defi-stablecoin)
  - [Table of Contents](#table-of-contents)
  - [About](#about)
    - [Key Features](#key-features)
    - [How It Works](#how-it-works)
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
    - [Deploy to Testnet](#deploy-to-testnet)
    - [Verify Contract](#verify-contract)
    - [Interact with Contract](#interact-with-contract)
    - [Deployed Contract Addresses](#deployed-contract-addresses)
  - [Security](#security)
    - [Access Control](#access-control)
    - [Audit Status](#audit-status)
    - [Known Limitations](#known-limitations)
  - [Gas Optimization](#gas-optimization)
  - [Contributing](#contributing)
  - [License](#license)

## About

**DSC (Decentralized Stablecoin)** is an algorithmic stablecoin protocol inspired by MakerDAO's DAI. Users deposit wETH or wBTC collateral to mint DSC tokens pegged 1:1 to USD. The system maintains peg stability through overcollateralization (>150% ratio) and permissionless liquidation mechanisms.

### Key Features

- **Decentralized Stablecoin (DSC)**: ERC20 token pegged to USD
- **Exogenous Collateral**: Users must deposit real assets (wETH or wBTC) to mint DSC
- **Overcollateralized System**: Requires >150% collateral ratio to maintain peg stability
- **Permissionless**: Deposit, mint, redeem, and liquidate without permission
- **Oracle-Driven**: Uses Chainlink V3 price feeds for real-time price data with staleness detection
- **Liquidation Mechanism**: Allows liquidators to restore health factor when users health factor falls below threshold
- **Comprehensive Testing**: Includes unit tests, integration tests, and advanced invariant testing with fuzz handlers

**Tech Stack:**
- Solidity 0.8.33
- Foundry (Forge + Anvil) with forge-std v1.13.0
- OpenZeppelin Contracts v5.5.0
- Chainlink Price Feeds (chainlink-brownie-contracts 1.3.0)
- Foundry Development and Operations (foundry-devops 0.4.0)

### How It Works

1. **Deposit & Mint**: Approve collateral → Deposit wETH/wBTC → Mint DSC
2. **Redeem & Burn**: Burn DSC → Withdraw collateral (health factor must stay ≥ 1.0)
3. **Liquidation**: If health factor < 1.0, anyone can liquidate and earn 10% bonus

**Health Factor Calculation:**
```
healthFactor = (collateralValueInUsd * LIQUIDATION_THRESHOLD / 100) * 1e18 / totalDscMinted
```
- Health Factor < 1.0 → User can be liquidated
- Health Factor = 1.0 → Minimum safe threshold
- Health Factor > 1.0 → Safe; higher values indicate more buffer

**Liquidation Process:**
1. Liquidator calls `liquidate(userAddress, collateralToken, debtAmount)`
2. System verifies user has broken health factor (< 1.0)
3. Liquidator provides DSC to pay off part of user's debt
4. User's collateral (+ 10% bonus) is transferred to liquidator
5. User's health factor must improve after liquidation
6. Liquidator's own health factor must not break after receiving collateral

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
│  ┌─────────────────────────────────────────────────────┐     │
│  │  • Deposit/Withdraw Collateral (wETH, wBTC)         │     │
│  │  • Mint/Burn DSC Tokens                             │     │
│  │  • Health Factor Calculation                        │     │
│  │  • Liquidation Logic                                │     │
│  │  • Reentrancy Protection (ReentrancyGuard)          │     │
│  └─────────────────────────────────────────────────────┘     │
│                                                              │
└───────────────┬──────────────────────────┬──────────────────-┘
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
│   ├── DSCEngine.sol                     # Core protocol engine
│   ├── DecentralizedStableCoin.sol       # ERC20 stablecoin token
│   └── libraries/
│       └── OracleLib.sol                 # Price feed validation & safety
├── script/
│   ├── DeployDSC.s.sol                  # Main deployment script
│   └── HelperConfig.s.sol               # Network configuration helper
├── test/
│   ├── unit/
│   │   ├── DSCEngineTest.t.sol           # DSCEngine unit tests
│   │   └── DecentralizedStableCoinTest.t.sol  # Token unit tests
│   ├── integration/
│   │   └── DeployDSCTest.t.sol           # Deployment integration tests
│   ├── mocks/
│   │   └── MockV3Aggregator.sol          # Mock Chainlink price feed
│   └── fuzz/
│       ├── failOnRevert/
│       │   ├── Handler.t.sol             # Fuzz action handler
│       │   └── InvariantsTest.t.sol      # Invariant tests (fail on revert)
│       └── continueOnRevert/
│           └── OpenInvariantsTest.t.sol  # Invariant tests (continue on revert)
├── lib/
│   ├── forge-std/                        # Foundry standard library
│   ├── openzeppelin-contracts/           # OpenZeppelin utilities
│   ├── foundry-devops/                   # Foundry dev utilities
│   └── chainlink-brownie-contracts/      # Chainlink price feed interfaces
├── foundry.toml                          # Foundry configuration
├── Makefile                              # Build & test commands
└── README.md                             # This file
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
make
```

### Environment Setup

1. **Copy the environment template:**
   ```bash
   cp .env.example .env
   ```

2. **Configure your `.env` file:**
   ```bash
   ETH_SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/your-api-key
   ETH_MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/your-api-key
   ARB_SEPOLIA_RPC_URL=https://arb-sepolia.g.alchemy.com/v2/your-api-key
   ARB_MAINNET_RPC_URL=https://arb-mainnet.g.alchemy.com/v2/your-api-key
   ETHERSCAN_API_KEY=your_etherscan_api_key_here
   DEFAULT_KEY_ADDRESS=public_address_of_your_encrypted_private_key_here
   ```

3. **Get testnet ETH:**
   - Sepolia Faucet: [Google Cloud Faucet](https://cloud.google.com/application/web3/faucet/ethereum/sepolia)

4. **Configure Makefile**
- Change account name in Makefile to the name of your desired encrypted key 
  - change "--account defaultKey" to "--account <YOUR_ENCRYPTED_KEY_NAME>"
  - check encrypted key names stored locally with:

```bash
cast wallet list
```
- **If no encrypted keys found**
  - Encrypt private key to be used securely within foundry:

```bash
cast wallet import <account_name> --interactive
```

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
Check test coverage

```bash
forge coverage
```

Create test coverage report and save to .txt file:

```bash
make coverage-report
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

### Deploy to Testnet

Deploy to Ethereum Sepolia:

```bash
make deploy ARGS="--network eth sepolia"
```

Deploy to Arbitrum Sepolia:

```bash
make deploy ARGS="--network arb sepolia"
```

Or using forge directly:

```bash
forge script script/DeployDSC.s.sol:DeployDSC --rpc-url $ETH_SEPOLIA_RPC_URL --account defaultKey --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY -vvvv
```

### Verify Contract

If automatic verification fails, verify DSCEngine:

```bash
forge verify-contract <DSC_ENGINE_ADDRESS> src/DSCEngine.sol:DSCEngine --chain-id 11155111 --etherscan-api-key $ETHERSCAN_API_KEY
```

Or verify DecentralizedStableCoin:

```bash
forge verify-contract <DSC_TOKEN_ADDRESS> src/DecentralizedStableCoin.sol:DecentralizedStableCoin --chain-id 11155111 --etherscan-api-key $ETHERSCAN_API_KEY
```

### Interact with Contract

Once deployed, you can interact with the DSC system using cast:

```bash
# Approve collateral spending
cast send <COLLATERAL_ADDRESS> "approve(address,uint256)" <DSC_ENGINE_ADDRESS> <AMOUNT> --rpc-url $ETH_SEPOLIA_RPC_URL --account defaultKey

# Deposit collateral (wETH example)
cast send <DSC_ENGINE_ADDRESS> "depositCollateral(address,uint256)" <WETH_ADDRESS> <AMOUNT> --rpc-url $ETH_SEPOLIA_RPC_URL --account defaultKey

# Mint DSC
cast send <DSC_ENGINE_ADDRESS> "mintDsc(uint256)" <DSC_AMOUNT> --rpc-url $ETH_SEPOLIA_RPC_URL --account defaultKey

# Check health factor
cast call <DSC_ENGINE_ADDRESS> "getHealthFactor(address)" <YOUR_ADDRESS> --rpc-url $ETH_SEPOLIA_RPC_URL

# Get collateral value
cast call <DSC_ENGINE_ADDRESS> "getCollateralValueInUsd(address,address)" <USER_ADDRESS> <COLLATERAL_ADDRESS> --rpc-url $ETH_SEPOLIA_RPC_URL
```

### Deployed Contract Addresses

| Network     | Contract                | Address                                      | Explorer                                          |
| ----------- | ----------------------- | -------------------------------------------- | ------------------------------------------------- |
| Arb Sepolia | DSCEngine               | `0xd560D60d441A2351a093Ab200CD967723b8b2e15` | [View on Arbiscan](https://sepolia.arbiscan.io)   |
| Arb Sepolia | DecentralizedStableCoin | `0x6b755b42725F6239aa09Baa7fb971Ef92344b6D9` | [View on Arbiscan](https://sepolia.arbiscan.io)   |
| Eth Sepolia | DSCEngine               | `TBD`                                        | [View on Etherscan](https://sepolia.etherscan.io) |
| Eth Sepolia | DecentralizedStableCoin | `TBD`                                        | [View on Etherscan](https://sepolia.etherscan.io) |

## Security

### Access Control

**DecentralizedStableCoin (DSC Token):**
- **Owner**: Deployer (set during initialization)
  - The DSCEngine is designed to be decentralized. The DSC token's owner role is intended to be held by the DSCEngine contract itself post-deployment to prevent arbitrary minting.

**DSCEngine (Protocol Logic):**
- **No Role-Based Access Control**: All functions are public/external with no role restrictions

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

**Approximate gas costs on local anvil chain (may vary by network and gas conditions):**

| Function                      | Gas Cost |
| ----------------------------- | -------- |
| `depositCollateral`           | ~63,764  |
| `depositCollateralAndMintDsc` | ~164,508 |
| `redeemCollateral`            | ~107,850 |
| `redeemCollateralForDsc`      | ~142,603 |
| `burnDsc`                     | ~101,956 |
| `mintDsc`                     | ~105,403 |
| `liquidate`                   | ~95,657  |

Generate gas report:

```bash
make gas-report
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