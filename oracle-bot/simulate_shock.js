require('dotenv').config({ path: '../.env' });
const config = require('./config');

// MOCK SHOCK VALUES
const SHOCK_SCENARIO = {
    yieldChange: 0.05,  // +5% Spike in US Yield (Bad for everyone usually)
    oilChange: 0.10     // +10% Spike in Oil (Good for ID, Bad for SG)
};

async function runSimulation() {
    console.log("⚠️  STARTING 'GLOBAL CRISIS' SIMULATION ⚠️");
    console.log("-----------------------------------------");
    console.log(`SCENARIO:`);
    console.log(`US 10Y Treasury Yield: +${(SHOCK_SCENARIO.yieldChange * 100).toFixed(0)}% (Panic Selling)`);
    console.log(`Crude Oil Price:       +${(SHOCK_SCENARIO.oilChange * 100).toFixed(0)}% (Supply Shock)`);
    console.log("-----------------------------------------");

    console.log("\nCALCULATING IMPACT PER COUNTRY...");

    for (const [countryCode, data] of Object.entries(config.countries)) {
        // Assume ETF and FX are flat (0%) to isolate the Global Shock impact
        const etfChange = 0;
        const fxChange = 0;

        // Apply Correlations
        const yieldImpact = SHOCK_SCENARIO.yieldChange * (data.corrYield || 0);
        const oilImpact = SHOCK_SCENARIO.oilChange * (data.corrOil || 0);

        const totalImpact = etfChange + fxChange + yieldImpact + oilImpact;
        const newScore = data.baseGDP * (1 + totalImpact);

        console.log(`\n[${countryCode}] ${data.name}:`);
        console.log(`   Base Score: ${data.baseGDP}`);
        console.log(`   Impact from Yield: ${(yieldImpact * 100).toFixed(2)}%`);
        console.log(`   Impact from Oil:   ${(oilImpact * 100).toFixed(2)}%`);
        console.log(`   TOTAL CHANGE:      ${(totalImpact * 100).toFixed(2)}%`);
        console.log(`   => NEW SCORE:      ${newScore.toFixed(4)}`);

        if (totalImpact < -0.05) console.log("   🚨 CRASH ALERT! 🚨");
        if (totalImpact > 0.02) console.log("   🚀 BOOM!");
    }
}

runSimulation();
