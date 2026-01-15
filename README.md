# GeoBit - Country Trading Protocol

Decentralized perpetual exchange for trading country economic indices with ERC20 collateral (USDT/USDC). The liquidity pool acts as counterparty to all trades.

## 📋 Table of Contents

- [Deployed Contracts](#deployed-contracts)
- [Core Features](#core-features)
- [Architecture](#architecture)
- [Trading Parameters](#trading-parameters)
- [Getting Started](#getting-started)

## 🚀 Deployed Contracts

### Mantle Sepolia Testnet

| Contract | Address | Description |
|----------|---------|-------------|
| **CountryRegistry** | `0xE078C2e2b7127a2D2a4b6adb471bb7FD430ff505` | Manages country registration and price feeds |
| **LiquidityPool** | `0x6Bc56dd4b203f8007bfa43eA24040c6AEc3e7F84` | Handles pool funds and open interest |
| **CountryTrading** | `0xbad3D7656275D64665D501DAf3C20156671B5d2E` | Main trading contract |
| **Collateral (USDT)** | `0xb70c008C221d71d49aa479a12e4DDb435a997425` | ERC20 collateral token |

### Price Feeds (Mock Chainlink Oracles)

| Country | Address | Initial Price |
|---------|---------|---------------|
| **United States (US)** | `0x159Bd0f548E63053419DCf253DeCCeC86C57cFff` | $3,000.00 |
| **Indonesia (ID)** | `0x4e871ee828a862709a0a87f626e579121a99e6F1` | $15,000.00 |
| **Singapore (SG)** | `0x52D539544B520F08a2BE850749c1541e430F8DFC` | $1,350.00 |

## ✨ Core Features

- **Long/Short Trading**: Perpetual positions on country indices with 1x leverage
- **Partial Close**: Close 10-100% of positions
- **Auto-Liquidation**: Positions liquidated at 85% threshold with 5% liquidator bonus
- **Funding Rate**: Dynamic rate balancing long/short positions (max 1% per 8h)
- **Chainlink Oracles**: Price feeds with staleness checks (1 hour max age)
- **Multi-Position**: Up to 100 active positions per user


## 🏗️ Architecture

### Contract Overview

```
CountryTrading (Main Trading Engine)
├── CountryRegistry (Price Feed & Country Management)
├── LiquidityPool (Counterparty & Fund Management)
├── TradingMath Library (P&L Calculations)
└── FundingRateCalculator Library (Funding Rate Logic)
```

### Interaction Flow

```
User → CountryTrading.openPosition()
  ↓
CountryTrading checks CountryRegistry.getPrice()
  ↓
CountryTrading transfers collateral from user
  ↓
CountryTrading updates LiquidityPool.updateOpenInterest()
  ↓
Position created and stored

User → CountryTrading.closePosition()
```

### CountryRegistry.sol
Manages country registration and Chainlink price feeds.

**Key Functions**:
- `addCountry()` - Register new country with price feed
- `getPrice()` - Get current price with validation (max 1h staleness)
- `updatePriceFeed()` - Update oracle address

### LiquidityPool.sol
Acts as counterparty, manages funds and open interest.

**Key Functions**:
- `depositLiquidity()` / `withdrawLiquidity()` - Owner fund management
- `payProfit()` / `receiveLoss()` - Trade settlement
- `updateOpenInterest()` - Track long/short positions

### CountryTrading.sol
Main trading engine for positions and liquidations.

**Key Functions**:
- `deposit()` / `withdraw()` - Manage collateral
- `openPosition()` - Open long/short position
- `closePosition()` - Close position (full or partial)
- `addMargin()` - Increase collateral
- `liquidatePosition()` - Liquidate undercollateralized positions

### Libraries
- **TradingMath**: P&L and liquidation calculations
- **FundingRateCalculator**: Funding rate logicases)**:
- Trader losses (position closes at loss)
- Trading fees (0.1% of position size)
- Funding fees from crowded side
- Liquidation surplus (after liquidator bonus)
- Owner deposits

**Outflows (Pool Balance Decreases)**:
- Trader profits (position closes at profit)
- Funding fees to thin side
- Owner withdrawals

**Balance Formula**:
```
Pool Balance = Initial Deposits + Cumulative Losses + Fees - Cumulative Profits
```

### Open Interest Tracking

```solidity
totalLongOpenInterest  = sum of all long position sizes
totalShortOpenInterest = sum of all short position sizes
```

**Used for**:
- Funding rate calculation
- Risk exposure monitoring
- Pool health assessment

### Funding Rate Mechanism

**Purpose**: Balance long and short positions by creating a cost for the crowded side

**Calculation**:
```solidity
// 1. Calculate imbalance
totalOI = longOI + shortOI
imbalance = (longOI - shortOI) / totalOI  // -100% to +100%

// 2. Calculate funding rate
fundingRate = imbalance * maxFundingRate  // Max ±1% per 8h

// 3. Cap at maximum
if (fundingRate > maxRate) fundingRate = maxRate
if (fundingRate < -maxRate) fundingRate = -maxRate
```

## ⚠️ Risk Management

### Liquidation System

**Trigger Condition**:
```solidity
Position Value = Collateral + P&L
Liquidation Threshold = Collateral * 85%

if (Position Value < Liquidation Threshold) {
    // Position can be liquidated
}
```

**Example Scenarios**:

```
Long Position - Liquidatable
Collateral: 100 tokens
Entry: $3,000
Current: $2,550 (15% drop)
P&L: -15 tokens
Position Value: 100 - 15 = 85 tokens
Threshold: 100 * 85% = 85 tokens
Status: 85 < 85 → Can liquidate

Short Position - Safe
Collateral: 100 tokens  
Entry: $3,000
Current: $3,300 (10% rise)
P&L: -10 tokens
Position Value: 100 - 10 = 90 tokens
Threshold: 100 * 85% = 85 tokens
Status: 90 > 85 → Safe
```

**Liquidation Process**:

```solidity
1. Anyone calls liquidatePosition(user, positionId)
2. Verify position is liquidatable
3. Apply any pending funding fees
4. Calculate remaining value after P&L
5. Liquidator bonus = remaining value * 5%
6. Protocol fee = (remaining - bonus) * 5%
7. Pool receives rest as loss
8. Transfer bonus to liquidator
9. Close position and update OI
```

**Liquidation Rewards**:
```
Remaining value: 85 tokens
Liquidator bonus: 85 * 5% = 4.25 tokens
Protocol fee: (85 - 4.25) * 5% = 4.04 tokens
Pool receives: 85 - 4.25 - 4.04 = 76.71 tokens
```

### Withdrawal Safety

**Safety Check on Withdrawal**:
```solidity
function withdraw(uint256 amount) {
    // Check all active positions remain safe
    for each position {
        newBalance = userBalance - amount
        if (position would be liquidatable with newBalance) {
            revert("Withdrawal would cause undercollateralization")
        }
    }
    // Process withdrawal
}
```

This prevents users from withdrawing collateral that would make their positions liquidatable.

### Position Size Limits

**Minimum Size** (1 token):
- Prevents dust positions
- Ensures meaningful liquidation rewards
- Reduces gas waste on tiny positions

**Maximum Size** (1,000,000 tokens):
- Limits single-position risk
- Protects pool from excessive exposure
- Encourages position diversification

**Maximum Positions** (100 per user):
- Prevents gas limit issues on batch operations
- Limits attack surface
- Encourages position consolidation

## 🚀 Getting Started

### Prerequisites

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install Node.js dependencies (for oracle bot)
npm install
```

### Local Development

```bash
# Clone repository
git clone https://github.com/your-repo/geobit-contracts
cd geobit-contracts

# Install dependencies
forge install

# Run tests
forge test

# Run tests with gas report
forge test --gas-report

# Deploy to local network
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

### Deployment

```bash
# Set environment variables
cp .env.example .env
# Edit .env with your values

# Deploy to testnet
forge script script/Deploy.s.sol \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify

# Deploy mock oracles
forge script script/DeployMockOracle.s.sol \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast

# Add countries
forge script script/AddCountries.s.sol \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast
```

##Leverage | 1x | Fixed leverage |
| Trading Fee | 0.1% | On open/close |
| Liquidation Threshold | 85% | Auto-liquidation trigger |
| Liquidator Bonus | 5% | Liquidation reward |
| Funding Period | 8 hours | Rate application interval |
| Max Funding Rate | 1% | Per 8h period |
| Min Position | 1 token | Minimum size |
| Max Position | 1M tokens | Maximum size |
| Max Positions | 100 | Per user |

### P&L Calculation

```
Long P&L  = (currentPrice - entryPrice) * positionSize / entryPrice
Short P&L = (entryPrice - currentPrice) * positionSize / entryPrice
```

### Funding Rate

```
Imbalance = (longOI - shortOI) / totalOI
Funding Rate = Imbalance * maxRate (±1%)
Applied every 8 hours
```

### Liquidation

Position liquidated when: `Collateral + P&L < Collateral * 85%`

Liquidator receives 5% bonus, protocol takes 5% fee, rest goes to pool.Installation

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install dependencies
forge install
npm install
```

### Testing & Deployment

```bash
# Run tests
forge test

# Deploy contracts
forge script script/Deploy.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

# Start oracle bot
pm2 start oracle-bot/index.js --name "geobit-oracle"
```

## 📄 License

MIT License

## ⚠️ Disclaimer

Experimental software. Not audited. Use at your own risk