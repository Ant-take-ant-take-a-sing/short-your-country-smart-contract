// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title TradingMath
 * @notice Library for trading calculations (P&L, fees, liquidation checks)
 */
library TradingMath {
    uint256 public constant PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10000; // 100% = 10000 basis points

    /**
     * @notice Calculate P&L for a position
     * @param isLong Whether the position is long
     * @param positionSize Size of the position
     * @param entryPrice Entry price of the position
     * @param currentPrice Current price from oracle
     * @return pnl Profit or loss (positive for profit, negative for loss)
     */
    function calculatePnL(bool isLong, uint256 positionSize, uint256 entryPrice, uint256 currentPrice)
        internal
        pure
        returns (int256 pnl)
    {
        if (isLong) {
            // Long: profit when price goes up
            if (currentPrice > entryPrice) {
                pnl = int256((positionSize * (currentPrice - entryPrice)) / entryPrice);
            } else {
                pnl = -int256((positionSize * (entryPrice - currentPrice)) / entryPrice);
            }
        } else {
            // Short: profit when price goes down
            if (currentPrice < entryPrice) {
                pnl = int256((positionSize * (entryPrice - currentPrice)) / entryPrice);
            } else {
                pnl = -int256((positionSize * (currentPrice - entryPrice)) / entryPrice);
            }
        }
    }

    /**
     * @notice Calculate trading fee
     * @param amount Amount to calculate fee on
     * @param feeBps Fee in basis points (e.g., 10 = 0.1%)
     * @return fee Fee amount
     */
    function calculateFee(uint256 amount, uint256 feeBps) internal pure returns (uint256 fee) {
        fee = (amount * feeBps) / BASIS_POINTS;
    }

    /**
     * @notice Calculate position value (collateral + P&L)
     * @param collateralAmount Collateral amount
     * @param pnl Profit or loss
     * @return value Position value
     */
    function calculatePositionValue(uint256 collateralAmount, int256 pnl) internal pure returns (uint256 value) {
        if (pnl >= 0) {
            value = collateralAmount + uint256(pnl);
        } else {
            uint256 loss = uint256(-pnl);
            if (loss >= collateralAmount) {
                value = 0;
            } else {
                value = collateralAmount - loss;
            }
        }
    }

    /**
     * @notice Check if position can be liquidated
     * @param collateralAmount Collateral amount
     * @param pnl Profit or loss
     * @param liquidationThresholdBps Liquidation threshold in basis points (e.g., 8500 = 85%)
     * @return isLiquidatable Whether position can be liquidated
     */
    function canLiquidate(uint256 collateralAmount, int256 pnl, uint256 liquidationThresholdBps)
        internal
        pure
        returns (bool isLiquidatable)
    {
        uint256 positionValue = calculatePositionValue(collateralAmount, pnl);
        uint256 threshold = (collateralAmount * liquidationThresholdBps) / BASIS_POINTS;
        isLiquidatable = positionValue < threshold;
    }

    /**
     * @notice Calculate liquidation amount
     * @param collateralAmount Collateral amount
     * @param pnl Profit or loss
     * @return liquidationAmount Amount to liquidate
     */
    function calculateLiquidationAmount(uint256 collateralAmount, int256 pnl)
        internal
        pure
        returns (uint256 liquidationAmount)
    {
        uint256 positionValue = calculatePositionValue(collateralAmount, pnl);
        // Liquidate the entire position
        liquidationAmount = positionValue;
    }
}

