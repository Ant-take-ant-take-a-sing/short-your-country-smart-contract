# Environment Variables Checklist

## ✅ Environment Variables yang Sudah Lengkap

### 1. Network Configuration ✅
- `RPC_URL` - RPC endpoint untuk network
- `PRIVATE_KEY` - Private key deployer (tanpa 0x)
- `CHAIN_ID` - Chain ID (optional, auto-detect)

### 2. Token Addresses ✅
- `COLLATERAL_TOKEN_ADDRESS` - **PRIMARY** (Recommended)
  - Bisa USDT, USDC, atau token ERC20 lainnya
  - Deploy script akan menggunakan ini jika tersedia
- `USDT_ADDRESS` - **LEGACY/FALLBACK**
  - Digunakan jika `COLLATERAL_TOKEN_ADDRESS` tidak ada
  - Untuk backward compatibility

### 3. Deployed Contract Addresses ✅
- `COUNTRY_REGISTRY_ADDRESS` - Address CountryRegistry (setelah deploy)
- `LIQUIDITY_POOL_ADDRESS` - Address LiquidityPool (setelah deploy)
- `COUNTRY_TRADING_ADDRESS` - Address CountryTrading (setelah deploy)

### 4. Chainlink Price Feed Addresses ✅
- `US_PRICE_FEED` - Price feed untuk US
- `ID_PRICE_FEED` - Price feed untuk Indonesia
- `SG_PRICE_FEED` - Price feed untuk Singapore
- `JP_PRICE_FEED` - Price feed untuk Japan
- (Tambahkan lebih banyak sesuai kebutuhan)

## 📋 Complete .env Template

```bash
# ============================================
# NETWORK CONFIGURATION
# ============================================
RPC_URL=https://rpc.testnet.mantle.xyz
PRIVATE_KEY=your_private_key_here_without_0x_prefix
CHAIN_ID=5001

# ============================================
# TOKEN ADDRESSES
# ============================================
# PRIMARY (Recommended)
COLLATERAL_TOKEN_ADDRESS=0x...

# LEGACY/FALLBACK
USDT_ADDRESS=0x...

# ============================================
# DEPLOYED CONTRACT ADDRESSES
# ============================================
# Isi setelah deployment
COUNTRY_REGISTRY_ADDRESS=
LIQUIDITY_POOL_ADDRESS=
COUNTRY_TRADING_ADDRESS=

# ============================================
# CHAINLINK PRICE FEED ADDRESSES
# ============================================
US_PRICE_FEED=0x...
ID_PRICE_FEED=0x...
SG_PRICE_FEED=0x...
JP_PRICE_FEED=0x...
```

## 🔍 Verification

### Scripts yang Menggunakan Environment Variables:

1. **Deploy.s.sol** ✅
   - `PRIVATE_KEY`
   - `COLLATERAL_TOKEN_ADDRESS` (primary) atau `USDT_ADDRESS` (fallback)

2. **AddCountries.s.sol** ✅
   - `PRIVATE_KEY`
   - `COUNTRY_REGISTRY_ADDRESS`
   - `US_PRICE_FEED`, `ID_PRICE_FEED`, `SG_PRICE_FEED` (optional, sesuai negara)

3. **DeployMockUSDT.s.sol** ✅
   - `PRIVATE_KEY`

4. **DeployMockUSDC.s.sol** ✅
   - `PRIVATE_KEY`

5. **DeployMockOracle.s.sol** ✅
   - `PRIVATE_KEY`
   - (Tidak perlu env untuk oracle addresses, karena di-deploy langsung)

## ✅ Status: LENGKAP

**Tidak ada environment variables yang terlewat!**

Semua environment variables yang diperlukan sudah tercakup di `ENV_SETUP.md`.

### Notes:
- `COLLATERAL_TOKEN_ADDRESS` adalah **primary option** (recommended)
- `USDT_ADDRESS` adalah **fallback** untuk backward compatibility
- Deploy script akan otomatis menggunakan `COLLATERAL_TOKEN_ADDRESS` jika tersedia
- Jika `COLLATERAL_TOKEN_ADDRESS` tidak ada, akan fallback ke `USDT_ADDRESS`

## 🚀 Deployment Flow

1. **Setup .env** dengan semua required variables
2. **Deploy mock tokens** (jika di testnet tanpa native tokens)
3. **Deploy contracts** menggunakan `Deploy.s.sol`
4. **Update .env** dengan deployed contract addresses
5. **Deploy mock oracles** (jika di testnet tanpa Chainlink)
6. **Add countries** menggunakan `AddCountries.s.sol`
7. **Deposit liquidity** ke pool
8. **Start trading!**

