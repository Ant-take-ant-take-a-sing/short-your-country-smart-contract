# Quick Start: Deploy ke Mantle Testnet

## TL;DR - Langkah Cepat

```bash
# 1. Setup .env
cp .env.example .env
# Edit .env dengan:
# RPC_URL=https://rpc.testnet.mantle.xyz
# CHAIN_ID=5001
# PRIVATE_KEY=your_key

# 2. Dapatkan BIT token untuk gas
# Kunjungi: https://faucet.testnet.mantle.xyz

# 3. Deploy Mock USDT
forge script script/DeployMockUSDT.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
# Copy USDT_ADDRESS ke .env as COLLATERAL_TOKEN_ADDRESS

# 4. Deploy Mock Oracle
forge script script/DeployMockOracle.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
# Copy price feed addresses ke .env

# 5. Deploy Contracts
forge script script/Deploy.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
# Copy contract addresses ke .env

# 6. Add Countries
forge script script/AddCountries.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

## File .env untuk Mantle Testnet

```bash
# Network
RPC_URL=https://rpc.testnet.mantle.xyz
CHAIN_ID=5001
PRIVATE_KEY=your_private_key_without_0x

# Tokens (isi setelah deploy mock)
USDT_ADDRESS=0x...

# Contracts (isi setelah deployment)
COUNTRY_REGISTRY_ADDRESS=0x...
COUNTRY_TRADING_ADDRESS=0x...

# Mock Oracles (isi setelah deploy mock oracle)
US_PRICE_FEED=0x...
ID_PRICE_FEED=0x...
SG_PRICE_FEED=0x...
```

## Update Price di Mock Oracle

Untuk testing, update price di mock oracle:

```bash
# Update US price ke $3500
cast send $US_PRICE_FEED "updatePrice(int256)" 350000000000 --rpc-url $RPC_URL --private-key $PRIVATE_KEY

# Price dalam 8 decimals: $3500 = 3500 * 10^8 = 350000000000
```

## Resources

- **Faucet**: https://faucet.testnet.mantle.xyz
- **Explorer**: https://explorer.testnet.mantle.xyz
- **RPC**: https://rpc.testnet.mantle.xyz
- **Docs**: https://docs.mantle.xyz

## Catatan

- Mock contracts hanya untuk testing di testnet
- Untuk production, gunakan real Chainlink oracle dan real USDT
- Pastikan punya BIT token untuk gas fees

