# Country Trading Smart Contract

Smart contract untuk tokenisasi negara di mana negara-negara bisa di-long dan di-short dengan collateral token ERC20 (USDT, USDC, atau token lainnya). Sistem ini menggunakan **hybrid perpetual DEX model** dengan liquidity pool yang membayar profit trader dan menerima loss trader.

## 📋 Daftar Isi

- [Overview](#overview)
- [Fitur Utama](#fitur-utama)
- [Arsitektur](#arsitektur)
- [Parameter Trading](#parameter-trading)
- [Liquidity Pool & Funding Rate](#liquidity-pool--funding-rate)
- [Risk Management](#risk-management)

## 🎯 Overview

Sistem ini memungkinkan trading negara dengan mekanisme:
- **Long Position**: Profit ketika harga negara naik
- **Short Position**: Profit ketika harga negara turun
- **Liquidity Pool**: Pool membayar profit trader dan menerima loss trader
- **Funding Rate**: Menyeimbangkan long/short positions setiap 8 jam
- **Liquidation**: Posisi yang undercollateralized akan di-liquidate

### Alur Dana (Money Flow)

```
Profit Trader → Pool membayar profit → Trader dapat profit
Loss Trader → Loss masuk ke pool → Pool balance bertambah
Trading Fees → Pool
Funding Fees → Pool (dari sisi ramai ke sisi sedikit)
Liquidation Surplus → Pool
```

## ✨ Fitur Utama

### Core Trading Features
- ✅ **Deposit & Withdraw**: Deposit dan withdraw token ERC20 sebagai collateral
- ✅ **Long Position**: Buka posisi long pada negara tertentu
- ✅ **Short Position**: Buka posisi short pada negara tertentu
- ✅ **Close Position**: Tutup posisi dan ambil profit/loss
- ✅ **Multi-Position**: Setiap user bisa memiliki hingga 100 positions

### Risk Management
- ✅ **Liquidation**: Mekanisme likuidasi otomatis untuk posisi yang undercollateralized
- ✅ **Liquidation Threshold**: 85% dari collateral value
- ✅ **Liquidator Bonus**: 5% dari remaining value
- ✅ **Withdrawal Safety Check**: Mencegah withdrawal yang menyebabkan undercollateralization

### Fee System
- ✅ **Trading Fee**: 0.1% (10 basis points) untuk open dan close position
- ✅ **Funding Fee**: Dihitung berdasarkan long/short imbalance
- ✅ **Protocol Fees**: Semua fees masuk ke liquidity pool

### Oracle & Price Feed
- ✅ **Chainlink Oracle**: Menggunakan Chainlink price feeds untuk harga real-time
- ✅ **Price Staleness Check**: Maksimal 1 jam (3600 detik)
- ✅ **Round Completeness Check**: Memastikan price feed round sudah complete

### Liquidity Pool
- ✅ **Profit Payment**: Pool membayar profit trader
- ✅ **Loss Reception**: Pool menerima loss trader
- ✅ **Fee Collection**: Pool mengumpulkan trading fees dan funding fees
- ✅ **Open Interest Tracking**: Track total long dan short open interest

### Funding Rate
- ✅ **Automatic Application**: Funding rate di-apply setiap 8 jam
- ✅ **Imbalance Based**: Funding rate berdasarkan long/short imbalance
- ✅ **Max Rate**: 1% per period (8 jam)
- ✅ **Long Pays Short**: Jika long > short, long membayar funding fee
- ✅ **Short Pays Long**: Jika short > long, short membayar funding fee

## 🏗️ Arsitektur

### Contract Structure

```
CountryTrading (Main Contract)
├── CountryRegistry (Country & Price Feed Management)
├── LiquidityPool (Pool Management)
├── TradingMath (P&L & Fee Calculations)
└── FundingRateCalculator (Funding Rate Logic)
```

### 1. CountryRegistry.sol
**Fungsi**: Mengelola negara dan Chainlink price feed-nya

**Fitur**:
- Add/remove countries
- Update price feed
- Get country price (dengan staleness check)
- Check country status

**Access Control**: Owner only untuk add/remove/update

### 2. LiquidityPool.sol
**Fungsi**: Mengelola liquidity pool untuk trading protocol

**Fitur**:
- Deposit/withdraw liquidity (owner)
- Pay profit to traders
- Receive loss from traders
- Receive trading fees
- Receive funding fees
- Track open interest (long/short)

**Access Control**: 
- Owner: deposit/withdraw
- Trading Contract: payProfit, receiveLoss, receiveFees, updateOpenInterest

### 3. CountryTrading.sol
**Fungsi**: Main contract untuk trading operations

**Fitur**:
- Deposit/withdraw collateral
- Open long/short positions
- Close positions
- Liquidate positions
- Apply funding rate
- Track protocol metrics

**Access Control**:
- Public: deposit, withdraw, open/close positions
- Anyone: liquidate (jika position bisa di-liquidate)
- Owner: withdrawProtocolFees

### 4. TradingMath.sol
**Library**: Perhitungan trading

**Fungsi**:
- `calculatePnL()`: Hitung profit/loss
- `calculateFee()`: Hitung trading fee
- `calculatePositionValue()`: Hitung position value
- `canLiquidate()`: Check apakah position bisa di-liquidate
- `calculateLiquidationAmount()`: Hitung liquidation amount

### 5. FundingRateCalculator.sol
**Library**: Perhitungan funding rate

**Fungsi**:
- `calculateFundingRate()`: Hitung funding rate berdasarkan imbalance
- `calculateFundingFee()`: Hitung funding fee untuk position
- `shouldApplyFunding()`: Check apakah funding harus di-apply (8 jam)

## 📊 Parameter Trading

| Parameter | Value | Description |
|-----------|-------|-------------|
| **Leverage** | 1x (fixed) | Position size = collateral amount |
| **Trading Fee** | 0.1% (10 bps) | Applied on open and close |
| **Liquidation Threshold** | 85% | Position liquidated if value < 85% of collateral |
| **Max Positions per User** | 100 | Maximum active positions |
| **Min Position Size** | 1 token (1e18) | Minimum collateral amount |
| **Max Position Size** | 1,000,000 tokens | Maximum collateral amount |
| **Liquidator Bonus** | 5% | Bonus dari remaining value |
| **Funding Period** | 8 hours | Funding rate applied every 8 hours |
| **Max Funding Rate** | 1% per period | Maximum funding rate per 8 hours |
| **Price Staleness** | 1 hour | Maximum price age (3600 seconds) |

## 💰 Liquidity Pool & Funding Rate

### Liquidity Pool

Pool bertanggung jawab untuk:
- **Membayar profit** trader (dari pool balance)
- **Menerima loss** trader (masuk ke pool balance)
- **Mengumpulkan fees** (trading fees, funding fees)
- **Track open interest** (long/short positions)

### Funding Rate Mechanism

Funding rate menyeimbangkan long/short positions:

1. **Calculate Imbalance**: `(longOI - shortOI) / totalOI`
2. **Calculate Rate**: `imbalance * maxFundingRate`
3. **Apply Every 8 Hours**: Funding di-apply saat close position
4. **Payment Flow**:
   - Jika long > short: Long pays funding fee → Pool
   - Jika short > long: Short pays funding fee → Pool
   - Jika long < short: Long receives funding fee ← Pool
   - Jika short < long: Short receives funding fee ← Pool

### Example Funding Rate

```
Long OI: 1000
Short OI: 500
Total OI: 1500
Imbalance: (1000 - 500) / 1500 = 33.3%
Funding Rate: 33.3% * 1% = 0.333% per period

Long positions pay: positionSize * 0.333%
Short positions receive: positionSize * 0.333%
```

## ⚠️ Risk Management

### Liquidation

Posisi akan di-liquidate jika:
- Position value < 85% of collateral amount
- Formula: `positionValue < (collateralAmount * 85%)`

**Liquidation Process**:
1. Apply funding rate (jika perlu)
2. Calculate liquidation amount (remaining value)
3. Liquidator gets 5% bonus
4. Rest goes to pool (as loss)
5. Protocol gets 1% fee (from pool amount)

### Withdrawal Safety

Withdrawal akan di-block jika:
- Withdrawal menyebabkan position menjadi undercollateralized
- Check dilakukan untuk semua active positions

### Position Limits

- **Min Position Size**: 1 token (prevents dust)
- **Max Position Size**: 1,000,000 tokens (prevents excessive risk)
- **Max Positions**: 100 per user (prevents gas issues)
