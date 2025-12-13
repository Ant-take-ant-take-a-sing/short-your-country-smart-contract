# Architecture Overview

## Contract Structure

### Core Contracts

1. **CountryRegistry.sol**
   - Manages country tokens and their Chainlink price feeds
   - Owner can add/remove/update countries
   - Provides price data from Chainlink oracles
   - **PLACEHOLDER**: Countries are added via `addCountry()` function

2. **CountryTrading.sol**
   - Main trading contract
   - Handles all trading operations (deposit, withdraw, open/close positions)
   - Manages user collateral balances
   - Implements liquidation mechanism
   - Uses USDT as collateral

3. **TradingMath.sol** (Library)
   - P&L calculations
   - Fee calculations
   - Liquidation checks
   - Position value calculations

### Interfaces

- `ICountryTrading.sol`: Interface for CountryTrading contract
- `ICountryRegistry.sol`: Interface for CountryRegistry contract

## Key Features

### 1. Deposit & Withdraw
- Users deposit USDT as collateral
- Can withdraw collateral (with safety checks)
- Collateral is stored in contract

### 2. Position Management
- **Long Position**: Profit when country price goes up
- **Short Position**: Profit when country price goes down
- Each user can have multiple positions (up to 100)
- Positions are tracked by unique position IDs

### 3. Fee System
- **Trading Fee**: 0.1% (10 basis points) on position size
- Charged when opening position
- Charged when closing position
- Fees are deducted from collateral
- Gas fees paid by user (standard Ethereum behavior)

### 4. Liquidation
- Position can be liquidated if value drops below 85% of collateral
- Liquidator gets 5% bonus from remaining value
- Protocol keeps the rest
- Anyone can liquidate undercollateralized positions

### 5. Risk Management
- **Leverage**: 1x (position size = collateral)
- **Liquidation Threshold**: 85%
- **Max Positions**: 100 per user
- Withdrawal safety checks prevent undercollateralization

## Data Flow

### Opening a Position
1. User calls `openLongPosition()` or `openShortPosition()`
2. Contract checks:
   - Sufficient collateral (including fee)
   - Country is active
   - User hasn't reached max positions
3. Gets current price from Chainlink via CountryRegistry
4. Calculates position size (1x leverage = collateral amount)
5. Deducts collateral + fee
6. Creates position record
7. Emits event

### Closing a Position
1. User calls `closePosition(positionId)`
2. Contract gets current price from Chainlink
3. Calculates P&L using TradingMath library
4. Calculates closing fee
5. Returns remaining collateral (collateral + P&L - fee)
6. Removes position from user's list
7. Emits event

### Liquidation
1. Anyone calls `liquidatePosition(user, positionId)`
2. Contract checks if position can be liquidated
3. Gets current price and calculates P&L
4. Calculates liquidation amount
5. Liquidator gets 5% bonus
6. Protocol keeps the rest
7. Position is removed
8. Emits event

## Country Management

### Adding Countries

**PLACEHOLDER**: Countries are added by calling `addCountry()` on CountryRegistry:

```solidity
// Example
bytes32 countryCode = keccak256("US");
string memory name = "United States";
address priceFeed = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419; // Chainlink price feed

countryRegistry.addCountry(countryCode, name, priceFeed);
```

### Country Requirements
- Must have valid Chainlink price feed (AggregatorV3Interface)
- Price feed must be active and updating
- Country code must be unique (bytes32)

## Security Features

1. **ReentrancyGuard**: All state-changing functions protected
2. **SafeERC20**: Safe token transfers
3. **Ownable**: Only owner can manage countries
4. **Input Validation**: All inputs validated
5. **Withdrawal Safety**: Checks prevent undercollateralization

## Price Feed Integration

- Uses Chainlink AggregatorV3Interface
- Prices are scaled from 8 decimals (Chainlink) to 18 decimals
- Price staleness checked (updatedAt > 0)
- Negative prices rejected

## Gas Optimization

- Uses mappings for efficient lookups
- Minimal storage operations
- Events for off-chain indexing
- Library functions for reusable calculations

## Future Enhancements

Potential improvements:
- Higher leverage options
- Funding rates
- Stop loss / take profit orders
- Position limits per country
- Dynamic fee system
- Insurance fund

