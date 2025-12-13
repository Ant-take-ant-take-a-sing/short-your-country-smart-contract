// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title FundingRateCalculator
 * @notice Library for calculating funding rates based on long/short imbalance
 */
library FundingRateCalculator {
    uint256 public constant BASIS_POINTS = 10000; // 100% = 10000 basis points
    uint256 public constant MAX_FUNDING_RATE_BPS = 100; // 1% max funding rate per period
    uint256 public constant FUNDING_PERIOD = 8 hours; // Funding applied every 8 hours

    /**
     * @notice Calculate funding rate based on long/short imbalance
     * @param longOpenInterest Total long open interest
     * @param shortOpenInterest Total short open interest
     * @return fundingRate Funding rate in basis points (positive = long pays short, negative = short pays long)
     */
    function calculateFundingRate(uint256 longOpenInterest, uint256 shortOpenInterest)
        internal
        pure
        returns (int256 fundingRate)
    {
        if (longOpenInterest == 0 && shortOpenInterest == 0) {
            return 0;
        }

        uint256 totalOI = longOpenInterest + shortOpenInterest;

        // Calculate imbalance: (long - short) / total
        // Positive = more longs, long pays short
        // Negative = more shorts, short pays long
        int256 imbalance;
        if (longOpenInterest > shortOpenInterest) {
            imbalance = int256((longOpenInterest - shortOpenInterest) * BASIS_POINTS / totalOI);
        } else {
            imbalance = -int256((shortOpenInterest - longOpenInterest) * BASIS_POINTS / totalOI);
        }

        // Funding rate = imbalance * max_funding_rate
        // Calculate potential rate first, THEN clamp
        int256 potentialRate = (imbalance * int256(MAX_FUNDING_RATE_BPS)) / int256(BASIS_POINTS);
        int256 maxRate = int256(MAX_FUNDING_RATE_BPS);

        if (potentialRate > maxRate) {
            fundingRate = maxRate;
        } else if (potentialRate < -maxRate) {
            fundingRate = -maxRate;
        } else {
            fundingRate = potentialRate;
        }
    }

    /**
     * @notice Calculate funding fee for a position
     * @param positionSize Position size
     * @param fundingRate Funding rate in basis points
     * @param isLong Whether position is long
     * @return fundingFee Funding fee (positive = pay, negative = receive)
     */
    function calculateFundingFee(uint256 positionSize, int256 fundingRate, bool isLong)
        internal
        pure
        returns (int256 fundingFee)
    {
        if (fundingRate == 0) {
            return 0;
        }

        // Long pays if funding rate is positive, receives if negative
        // Short pays if funding rate is negative, receives if positive
        if (isLong) {
            // Long pays when funding rate > 0
            fundingFee = (int256(positionSize) * fundingRate) / int256(BASIS_POINTS);
        } else {
            // Short pays when funding rate < 0 (which means we flip the sign)
            fundingFee = -(int256(positionSize) * fundingRate) / int256(BASIS_POINTS);
        }
    }

    /**
     * @notice Check if funding should be applied (every 8 hours)
     * @param lastFundingTimestamp Last time funding was applied
     * @return shouldApply Whether funding should be applied
     * @return timeElapsed Time elapsed since last funding
     */
    function shouldApplyFunding(uint256 lastFundingTimestamp)
        internal
        view
        returns (bool shouldApply, uint256 timeElapsed)
    {
        if (lastFundingTimestamp == 0) {
            return (false, 0);
        }

        timeElapsed = block.timestamp - lastFundingTimestamp;
        shouldApply = timeElapsed >= FUNDING_PERIOD;
    }
}

