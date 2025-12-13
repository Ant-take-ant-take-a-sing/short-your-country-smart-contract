# Panduan Deployment Manual (Step-by-Step)

Berdasarkan permintaan Anda, berikut adalah langkah-langkah manual untuk men-deploy smart contract satu per satu melalui terminal.

## Prasyarat
Pastikan Anda berada di folder project di terminal WSL:
```bash
cd ~/project_hackathon/short-your-country-smart-contract
```

Pastikan file `.env` sudah diisi dengan format: `VARIABLE=VALUE` (TANPA SPASI di sekitar =):
```ini
PRIVATE_KEY=...
RPC_URL=https://mantle-sepolia.drpc.org
```
> **WARNING**: Jangan pakai spasi!
> ❌ Salah: `RPC_URL = https://...`
> ✅ Benar: `RPC_URL=https://...`

---

## Langkah 1: Deploy Mock USDT
Kita perlu token mata uang palsu (USDT) untuk testing.

**Perintah Terminal:**
```bash
source .env && forge script script/DeployMockUSDT.s.sol --tc DeployMockUSDT --rpc-url $RPC_URL --broadcast
```
*(Catatan: `--tc DeployMockUSDT` penting agar sistem tidak bingung memilih contract)*

**Setelah Selesai:**
1.  Cari output `Mock USDT Address: 0x...` di terminal.
2.  Buka file `.env` Anda.
3.  Update baris `USDT_ADDRESS=0x...` dengan alamat yang baru didapat.

---

## Langkah 2: Deploy Contract Utama
Script ini akan men-deploy `CountryRegistry`, `LiquidityPool`, dan `CountryTrading` sekaligus dan menghubungkan mereka.

**Perintah Terminal:**
```bash
source .env && forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast
```

**Setelah Selesai:**
Terminal akan menampilkan "Deployment Summary". Simpan alamat-alamat ini (Copy-Paste ke Notepad), kita butuh untuk Frontend:
*   `CountryRegistry: 0x...`
*   `LiquidityPool: 0x...`
*   `CountryTrading: 0x...`
*   `Collateral Token: 0x...`

---

## Langkah 3: Update .env (PENTING)
Setelah mendapatkan alamat-alamat di atas, **Wajib update file `.env`** Anda agar tersimpan dan bisa dipakai Frontend nantinya.

Buka file `.env` dan isi seperti ini:
```ini
# --- Token ---
USDT_ADDRESS=0x... (Isi alamat Mock USDT dari Langkah 1)
COLLATERAL_TOKEN_ADDRESS=0x... (Sama dengan atas)

# --- Contracts (Isi dari Output Langkah 2) ---
COUNTRY_REGISTRY_ADDRESS=0x...
LIQUIDITY_POOL_ADDRESS=0x...
COUNTRY_TRADING_ADDRESS=0x...
```

---

## Langkah 4: Setup Awal (Isi Bensin)
Agar aplikasi bisa dites, kita perlu menambahkan Negara dan mengisi Liquidity Pool.

### A. Tambah Negara (Indonesia - ID)
Kita perlu mendaftarkan negara Indonesia agar bisa di-trade. Kita akan pakai Mock Oracle untuk harga.

```bash
# 1. Deploy Mock Oracle menggunakan Script
forge script script/DeployMockOracle.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

> **PENTING**: Script ini akan mendeploy 3 Oracle sekaligus (ID, SG, US).
> Cek output terminal atau Etherscan, lalu catat alamat masing-masing dan masukkan ke `.env`:
> `ID_PRICE_FEED=0x...`
> `SG_PRICE_FEED=0x...`
> `US_PRICE_FEED=0x...`

```bash
# 2. Daftarkan INDONESIA (ID)
# Ganti ADDRESS_REGISTRY dan ID_PRICE_FEED (dari .env)
cast send ADDRESS_REGISTRY "addCountry(bytes32,string,address)" "0x4944000000000000000000000000000000000000000000000000000000000000" "Indonesia" ID_PRICE_FEED --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

```bash
# 3. Daftarkan SINGAPORE (SG)
# Ganti SG_PRICE_FEED
cast send ADDRESS_REGISTRY "addCountry(bytes32,string,address)" "0x5347000000000000000000000000000000000000000000000000000000000000" "Singapore" SG_PRICE_FEED --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

```bash
# 4. Daftarkan USA (US)
# Ganti US_PRICE_FEED
cast send ADDRESS_REGISTRY "addCountry(bytes32,string,address)" "0x5553000000000000000000000000000000000000000000000000000000000000" "United States" US_PRICE_FEED --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

> **CATATAN BYTES32**:
> *   ID: `0x4944...`
> *   SG: `0x5347...`
> *   US: `0x5553...`

---

## Langkah 5: Minting & Trading (User Setup)
Agar Anda bisa trading di Frontend, wallet Anda butuh saldo Mock USDT.

```bash
# Mint 1,000 USDT ke Wallet Anda Sendiri
# Ganti ADDRESS_USDT dan YOUR_WALLET_ADDRESS
cast send ADDRESS_USDT "mint(address,uint256)" YOUR_WALLET_ADDRESS 1000000000000000000000 --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

### B. Isi Liquidity Pool
Agar user yang profit bisa dibayar, Pool harus punya uang.

```bash
# Approve USDT ke Pool (Ganti ADDRESS_USDT dan ADDRESS_POOL)
cast send ADDRESS_USDT "approve(address,uint256)" ADDRESS_POOL 10000000000000000000000 --rpc-url $RPC_URL --private-key $PRIVATE_KEY

# Deposit ke Pool
cast send ADDRESS_POOL "deposit(uint256)" 1000000000000000000000 --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

---

## Langkah 6: Jalankan Oracle Bot
Terakhir, nyalakan mesin harga agar grafik bergerak.

```bash
cd oracle-bot
node index.js
```
