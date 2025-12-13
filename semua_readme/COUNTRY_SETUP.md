# Country Setup Guide

## Cara Menambahkan Negara ke Sistem Trading

Setelah contract `CountryRegistry` di-deploy, Anda perlu menambahkan negara-negara yang ingin di-trade. Berikut langkah-langkahnya:

### 1. Siapkan Chainlink Price Feed

Setiap negara memerlukan Chainlink price feed untuk mendapatkan harga real-time. 
- Cari price feed yang sesuai di: https://docs.chain.link/data-feeds/price-feeds/addresses
- Pastikan price feed sudah tersedia di network yang Anda gunakan

### 2. Tentukan Country Code

Country code adalah `bytes32` yang mewakili negara. Anda bisa menggunakan:
- `keccak256("US")` untuk United States
- `keccak256("ID")` untuk Indonesia
- `keccak256("SG")` untuk Singapore
- `keccak256("JP")` untuk Japan
- dll.

### 3. Tambahkan Negara ke Registry

Panggil function `addCountry` di contract `CountryRegistry`:

```solidity
// Contoh: Menambahkan United States
bytes32 usCode = keccak256("US");
string memory usName = "United States";
address usPriceFeed = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419; // ETH/USD sebagai contoh

countryRegistry.addCountry(usCode, usName, usPriceFeed);
```

### 4. Contoh Script untuk Menambahkan Beberapa Negara

```solidity
// Script untuk menambahkan beberapa negara sekaligus
function setupCountries() external onlyOwner {
    // United States
    countryRegistry.addCountry(
        keccak256("US"),
        "United States",
        0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419 // ETH/USD (contoh)
    );
    
    // Indonesia
    countryRegistry.addCountry(
        keccak256("ID"),
        "Indonesia",
        0x... // Ganti dengan price feed yang sesuai
    );
    
    // Singapore
    countryRegistry.addCountry(
        keccak256("SG"),
        "Singapore",
        0x... // Ganti dengan price feed yang sesuai
    );
}
```

### 5. Verifikasi Negara Telah Ditambahkan

Gunakan function `getCountry` untuk memverifikasi:

```solidity
bytes32 countryCode = keccak256("US");
ICountryRegistry.Country memory country = countryRegistry.getCountry(countryCode);
require(country.isActive, "Country is not active");
```

### Catatan Penting

1. **Price Feed Compatibility**: Pastikan price feed yang digunakan kompatibel dengan format yang diharapkan (Chainlink AggregatorV3Interface)

2. **Network**: Pastikan price feed address sesuai dengan network yang digunakan (Mainnet, Sepolia, dll.)

3. **Decimals**: Chainlink price feeds biasanya menggunakan 8 decimals. Contract sudah menangani konversi ke 18 decimals.

4. **Testing**: Selalu test di testnet terlebih dahulu sebelum deploy ke mainnet

### Daftar Negara yang Bisa Ditambahkan

Anda bisa menambahkan negara apapun selama:
- Memiliki Chainlink price feed yang valid
- Price feed aktif dan ter-update secara berkala
- Price feed menggunakan format USD (atau format yang konsisten)

### Troubleshooting

Jika ada error saat menambahkan negara:
1. Pastikan price feed address valid dan contract-nya adalah Chainlink AggregatorV3Interface
2. Pastikan country code belum pernah ditambahkan sebelumnya
3. Pastikan Anda adalah owner dari CountryRegistry contract

