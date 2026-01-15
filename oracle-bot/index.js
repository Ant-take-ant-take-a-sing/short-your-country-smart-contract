require('dotenv').config();
const { ethers } = require('ethers');
const axios = require('axios');
const config = require('./config');

// Load Environment Variables
const RPC_URL = process.env.RPC_URL;
const PRIVATE_KEY = process.env.PRIVATE_KEY;

// Contract ABIs
const ORACLE_ABI = [
    "function updatePrice(int256 _price) external",
    "function getPrice() external view returns (uint256)",
    "function decimals() external view returns (uint8)"
];

const ORACLE_ADDRESSES = {
    ID: process.env.ID_PRICE_FEED,
    SG: process.env.SG_PRICE_FEED,
    US: process.env.US_PRICE_FEED
};

// Yahoo Finance API Helper
async function getYahooQuote(ticker) {
    try {
        const url = `https://query1.finance.yahoo.com/v8/finance/chart/${ticker}?interval=1d&range=5d`;
        const response = await axios.get(url, {
            headers: { 'User-Agent': 'Mozilla/5.0' }
        });

        const result = response.data.chart.result[0];
        const quotes = result.indicators.quote[0];
        const closes = quotes.close;

        // Filter out nulls
        const validCloses = closes.filter(c => c != null);

        if (validCloses.length < 2) {
            return {
                price: result.meta.regularMarketPrice,
                prev: result.meta.previousClose,
                changePct: 0
            };
        }

        const lastClose = validCloses[validCloses.length - 1];
        const prevClose = validCloses[validCloses.length - 2];
        const changePct = (lastClose - prevClose) / prevClose;

        return {
            price: lastClose,
            prev: prevClose,
            changePct: changePct
        };
    } catch (error) {
        throw new Error(`Failed to fetch ${ticker}: ${error.message}`);
    }
}

async function main() {
    console.log("Starting Universal CPI Oracle Bot (Global Macro Edition)...");
    console.log(`Interval: ${config.interval}ms`);

    const provider = new ethers.JsonRpcProvider(RPC_URL);
    const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

    // Initial run
    await runBotCycle(wallet);
}

async function runBotCycle(wallet) {
    try {
        console.log("--- Starting Update Cycle (With Global Macro) ---");

        // 1. Fetch Globals First (Once per cycle)
        // We handle potential failures gracefully (default to 0 change)
        const [yieldData, oilData] = await Promise.all([
            getYahooQuote(config.globals.tickerYield).catch(e => ({ changePct: 0 })),
            getYahooQuote(config.globals.tickerOil).catch(e => ({ changePct: 0 }))
        ]);

        console.log(`[Global] US 10Y Yield: ${(yieldData.changePct ? yieldData.changePct * 100 : 0).toFixed(2)}% | Crude Oil: ${(oilData.changePct ? oilData.changePct * 100 : 0).toFixed(2)}%`);

        // 2. Pass Globals to processing
        await updateAllCountries(wallet, yieldData.changePct || 0, oilData.changePct || 0);

    } catch (err) {
        console.error("Cycle Error:", err);
    }

    // Schedule next run
    console.log(`Waiting ${config.interval}ms...`);
    setTimeout(() => runBotCycle(wallet), config.interval);
}

async function updateAllCountries(wallet, yieldChange, oilChange) {
    for (const [countryCode, countryData] of Object.entries(config.countries)) {
        await processCountry(wallet, countryCode, countryData, yieldChange, oilChange);
    }
}

async function processCountry(wallet, countryCode, data, yieldChange, oilChange) {
    const oracleAddress = ORACLE_ADDRESSES[countryCode];
    if (!oracleAddress) return;

    try {
        // Fetch Country Specific Data
        const [etfData, fxData] = await Promise.all([
            getYahooQuote(data.tickerETF),
            getYahooQuote(data.tickerFX)
        ]);

        // Adjust FX Polarity
        let fxImpact = fxData.changePct;
        if (data.isInverseFX) fxImpact = -fxImpact;

        // Apply Correlations for Globals
        const yieldImpact = yieldChange * (data.corrYield || 0);
        const oilImpact = oilChange * (data.corrOil || 0);

        // Calculate Final Composite Change
        // Apply Volatility Multiplier to amplify movements for Perpetual Trading
        const multiplier = config.volatilityMultiplier || 1;

        // Apply Simulated Jitter (Random Noise)
        // Math.random() is 0 to 1. (Math.random() * 2 - 1) gives -1 to +1.
        const jitterParam = config.jitter || 0;
        const randomJitter = (Math.random() * 2 - 1) * jitterParam;

        // Total = (Real Data * Multiplier) + Random Jitter
        const totalChange = ((etfData.changePct + fxImpact + yieldImpact + oilImpact) * multiplier) + randomJitter;

        const finalScoreRaw = data.baseGDP * (1 + totalChange);
        const finalScoreBigInt = ethers.parseUnits(finalScoreRaw.toFixed(8), 8);

        console.log(`[${countryCode}] Score: ${finalScoreRaw.toFixed(4)} | ETF: ${(etfData.changePct * 100).toFixed(2)}% FX: ${(fxImpact * 100).toFixed(2)}% Yield: ${(yieldImpact * 100).toFixed(2)}% Oil: ${(oilImpact * 100).toFixed(2)}%`);

        const oracleContract = new ethers.Contract(oracleAddress, ORACLE_ABI, wallet);
        const tx = await oracleContract.updatePrice(finalScoreBigInt);
        const receipt = await tx.wait();
        console.log(`[${countryCode}] Updated! Block: ${receipt.blockNumber}`);

    } catch (error) {
        console.error(`[${countryCode}] Error:`, error.message);
    }
}

main().catch(console.error);
