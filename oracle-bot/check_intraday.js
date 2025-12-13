const axios = require('axios');

async function getIntradayData(ticker) {
    try {
        console.log(`Fetching intraday data for ${ticker}...`);
        // Interval 1h to show hourly movement, Range 5d to capture last Friday
        const url = `https://query1.finance.yahoo.com/v8/finance/chart/${ticker}?interval=60m&range=5d`;
        const response = await axios.get(url, {
            headers: { 'User-Agent': 'Mozilla/5.0' }
        });

        const result = response.data.chart.result[0];
        const timestamps = result.timestamp;
        const quotes = result.indicators.quote[0];
        const closes = quotes.close;

        console.log(`\nData for ${ticker} (Last Trading Session):`);
        console.log("-------------------------------------------------");
        console.log("Time (Local)        | Price      | Change");
        console.log("-------------------------------------------------");

        // We only want the last day. Simplified logic: take last 7-8 candles.
        // Or filter by date of the last timestamp.

        const lastTimestamp = timestamps[timestamps.length - 1];
        const lastDate = new Date(lastTimestamp * 1000).getDate();

        let previousPrice = 0;

        for (let i = 0; i < timestamps.length; i++) {
            const date = new Date(timestamps[i] * 1000);

            // Only show the last active day
            if (date.getDate() === lastDate) {
                const price = closes[i];
                if (!price) continue;

                // Format Time (assuming text output, showing UTC likely, need manual shift for readability or just raw)
                // Yahoo timestamps are UTC. ^JKSE trades +7.
                // 02:00 UTC = 09:00 WIB.

                const wibHour = date.getUTCHours() + 7;
                const timeString = `${wibHour.toString().padStart(2, '0')}:00`;

                // Skip if outside 9-16 (sometimes pre/post market data exists)
                if (wibHour < 9 || wibHour > 16) continue;

                const change = previousPrice === 0 ? 0 : price - previousPrice;
                const changeStr = change >= 0 ? `+${change.toFixed(2)}` : change.toFixed(2);

                console.log(`${timeString} WIB           | ${price.toFixed(2)}   | ${previousPrice === 0 ? '-' : changeStr}`);

                previousPrice = price;
            }
        }
        console.log("-------------------------------------------------");

    } catch (error) {
        console.error("Error:", error.message);
    }
}

// Check IHSG (Jakarta) for 9-4 example
getIntradayData('^JKSE');
