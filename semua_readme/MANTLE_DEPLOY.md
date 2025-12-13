# Deployment Guide untuk Mantle Testnet

## Overview

Mantle Testnet memiliki beberapa perbedaan dengan Ethereum mainnet/testnet:
- **Chain ID**: 5001
- **RPC URL**: `https://rpc.testnet.mantle.xyz`
- **Block Explorer**: `https://explorer.testnet.mantle.xyz`
- **Gas Token**: BIT (bukan ETH)
- **Chainlink**: Tidak tersedia di testnet (perlu mock oracle)
- **USDT**: Tidak ada native USDT (perlu deploy mock token)

## Langkah-langkah Deployment

### 1. Setup Environment Variables

Buat/update file `.env` dengan konfigurasi Mantle Testnet:

```bash
# Network Configuration
RPC_URL=https://rpc.testnet.mantle.xyz
CHAIN_ID=5001
PRIVATE_KEY=your_private_key_here_without_0x_prefix

# Collateral Token Address (USDC/USDT - akan diisi setelah deploy mock token)
# Untuk Mantle Mainnet, gunakan USDC: 0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9
COLLATERAL_TOKEN_ADDRESS=

# Contract Addresses (akan diisi setelah deployment)
COUNTRY_REGISTRY_ADDRESS=
COUNTRY_TRADING_ADDRESS=

# Mock Oracle Addresses (akan diisi setelah deploy mock oracle)
US_PRICE_FEED=
ID_PRICE_FEED=
SG_PRICE_FEED=
```

### 2. Dapatkan Testnet BIT Token

Untuk membayar gas fees, Anda perlu BIT token:
- Faucet: https://faucet.testnet.mantle.xyz
- Atau gunakan faucet alternatif jika tersedia

### 3. Deploy Mock Collateral Token (USDT)

Script sudah tersedia untuk men-deploy Mock USDT (18 decimals):

```bash
# Deploy Mock USDT
forge script script/DeployMockUSDT.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

**Output**:
- Catat address `Mock USDT` dari terminal
- Masukkan ke `.env`: `USDT_ADDRESS=0x...` dan `COLLATERAL_TOKEN_ADDRESS=0x...`

### 4. Deploy Mock Callisto Oracle (Hybrid)

Kita menggunakan script khusus yang mendeploy 3 Oracle sekaligus (ID, SG, US) untuk keperluan Bot.

```bash
# Deploy 3 Mock Oracles
forge script script/DeployMockOracle.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

**Output**:
- Catat address `US_PRICE_FEED`, `ID_PRICE_FEED`, dan `SG_PRICE_FEED` dari terminal.
- Update `.env` dengan address tersebut.

### 5. Deploy CountryRegistry dan CountryTrading

Setelah mock collateral token (USDC/USDT) dan mock oracle sudah di-deploy:

```bash
forge script script/Deploy.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

Update `.env` dengan contract addresses.

### 6. Tambahkan Negara ke Registry

Edit `script/AddCountries.s.sol` dan uncomment/edit contoh, lalu:

```bash
forge script script/AddCountries.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

## Testing dengan Mock Oracle

Untuk testing, Anda bisa update price di mock oracle:

```solidity
// Via cast command
cast send <MOCK_ORACLE_ADDRESS> "updatePrice(int256)" 350000000000 --rpc-url $RPC_URL --private-key $PRIVATE_KEY

// Atau via script
```

## Catatan Penting

1. **Mock Oracle untuk Testing Only**
   - Mock oracle hanya untuk testing di testnet
   - Untuk production, gunakan Chainlink real oracle atau oracle yang terpercaya

2. **Collateral Token**
   - Mock token hanya untuk testing
   - Untuk mainnet, gunakan USDC native: `0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9`
   - Pastikan user approve spending sebelum deposit
   - Lihat `MANTLE_TOKENS.md` untuk info token yang tersedia

3. **Gas Fees**
   - Mantle Testnet menggunakan BIT token untuk gas
   - Pastikan wallet punya cukup BIT

4. **Price Updates**
   - Mock oracle perlu di-update manual untuk simulasi price movement
   - Untuk testing yang lebih realistis, buat script yang update price secara berkala

## Troubleshooting

### Error: "Insufficient funds"
- Pastikan wallet punya BIT token untuk gas
- Dapatkan dari faucet: https://faucet.testnet.mantle.xyz

### Error: "Price feed not found"
- Pastikan mock oracle sudah di-deploy
- Pastikan address di `.env` benar

### Error: "Invalid collateral token address"
- Pastikan mock token sudah di-deploy
- Pastikan address di `.env` benar
- Untuk mainnet, pastikan menggunakan USDC address yang benar

## Next Steps

Setelah semua contract di-deploy:
1. Approve USDT spending untuk CountryTrading contract
2. Deposit USDT sebagai collateral
3. Test open/close positions
4. Test liquidation mechanism

