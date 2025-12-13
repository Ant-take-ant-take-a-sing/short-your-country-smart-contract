require('dotenv').config({ path: '../.env' });

console.log("DUMPING ADDRESSES FOR FRONTEND:");
console.log("-------------------------------");
console.log("ID:", process.env.ID_PRICE_FEED);
console.log("SG:", process.env.SG_PRICE_FEED);
console.log("US:", process.env.US_PRICE_FEED);
console.log("-------------------------------");
