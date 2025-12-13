// Configuration for Country Performance Index (CPI) Bot

module.exports = {
    // Refresh Interval in milliseconds (e.g., 10 seconds)
    interval: 60000,

    // Global Macro Indicators (Applied to everyone based on correlation)
    globals: {
        tickerYield: "^TNX",    // US 10Y Treasury Yield
        tickerOil: "CL=F"       // Crude Oil Futures
    },

    countries: {
        ID: {
            name: "Indonesia",
            tickerETF: "EIDO",
            tickerFX: "IDR=X",
            isInverseFX: true,
            baseGDP: 1300,

            // Correlations: 1 (Positive), -1 (Negative), 0 (Neutral)
            // Indo: Oil Up = Good (Exporter). US Yield Up = Bad (Capital Flight).
            corrOil: 0.5,           // Weighted 50% impact
            corrYield: -1.0         // Strong negative impact
        },
        SG: {
            name: "Singapore",
            tickerETF: "EWS",
            tickerFX: "SGD=X",
            isInverseFX: true,
            baseGDP: 500,

            // SG: Oil Up = Bad (Importer/Cost). US Yield Up = Bad (Global Liquidity drying).
            corrOil: -0.5,
            corrYield: -1.0
        },
        US: {
            name: "United States",
            tickerETF: "SPY",
            tickerFX: "DX-Y.NYB",
            isInverseFX: false,
            baseGDP: 25000,

            // US: Oil Up = Bad (Inflation). Yield Up = Bad (Tightening Financial Conds).
            // Note: S&P500 already reflects this, so keep weights low to avoid double counting.
            corrOil: -0.2,
            corrYield: -0.2
        }
    }
};
