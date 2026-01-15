require('dotenv').config();

console.log("--- DEBUGGING ENVIRONMENT VARIABLES ---");

const pk = process.env.PRIVATE_KEY;

// 1. Cek apakah terbaca atau undefined
if (!pk) {
    console.log(" STATUS: Private Key TIDAK TERBACA/KOSONG.");
    console.log(" Saran: Cek nama file '.env' (jangan .env.txt) atau cek path-nya.");
    process.exit(1);
} else {
    console.log(" STATUS: Private Key terdeteksi (Isinya ada).");
}

// 2. Cek Panjang Karakter
console.log(` Panjang Karakter: ${pk.length}`);

// 3. Cek Prefix 0x
if (pk.startsWith("0x")) {
    console.log(" Prefix: Diawali dengan '0x' (Bagus).");
} else {
    console.log(" Prefix: TIDAK diawali '0x'.");
    console.log(" Saran: Tambahkan '0x' di depan key Anda di file .env");
}

// 4. Cek Spasi atau Kutip
if (pk.includes('"') || pk.includes("'")) {
    console.log(" ERROR: Ada tanda kutip di dalam key.");
    console.log(" Saran: Hapus tanda kutip di .env, tulis key polosan saja.");
}
if (pk.includes(" ")) {
    console.log(" ERROR: Ada spasi kosong.");
    console.log(" Saran: Hapus spasi di awal atau akhir key di .env.");
}