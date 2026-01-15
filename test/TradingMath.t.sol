// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {TradingMath} from "../src/libraries/TradingMath.sol";

/**
 * @title TradingMathTest
 * @notice Tests for TradingMath library
 */
contract TradingMathTest is Test {
    using TradingMath for uint256;

    function test_CalculatePnL_Long_Profit() public {
        bool isLong = true;
        uint256 positionSize = 1000 * 1e18;
        uint256 entryPrice = 3000 * 1e18;
        uint256 currentPrice = 3500 * 1e18; // Price up

        int256 pnl = TradingMath.calculatePnL(isLong, positionSize, entryPrice, currentPrice);

        assertGt(pnl, 0); // Should be profit
        // P&L = (1000 * (3500 - 3000)) / 3000 = 166.67...
        assertApproxEqAbs(uint256(pnl), 166 * 1e18, 1e18);
    }

    function test_CalculatePnL_Long_Loss() public {
        bool isLong = true;
        uint256 positionSize = 1000 * 1e18;
        uint256 entryPrice = 3000 * 1e18;
        uint256 currentPrice = 2500 * 1e18; // Price down

        int256 pnl = TradingMath.calculatePnL(isLong, positionSize, entryPrice, currentPrice);

        assertLt(pnl, 0); // Should be loss
    }

    function test_CalculatePnL_Short_Profit() public {
        bool isLong = false;
        uint256 positionSize = 1000 * 1e18;
        uint256 entryPrice = 3000 * 1e18;
        uint256 currentPrice = 2500 * 1e18; // Price down

        int256 pnl = TradingMath.calculatePnL(isLong, positionSize, entryPrice, currentPrice);

        assertGt(pnl, 0); // Should be profit (short profit when price down)
    }

    function test_CalculatePnL_Short_Loss() public {
        bool isLong = false;
        uint256 positionSize = 1000 * 1e18;
        uint256 entryPrice = 3000 * 1e18;
        uint256 currentPrice = 3500 * 1e18; // Price up

        int256 pnl = TradingMath.calculatePnL(isLong, positionSize, entryPrice, currentPrice);

        assertLt(pnl, 0); // Should be loss (short loss when price up)
    }

    function test_CalculateFee() public {
        uint256 amount = 1000 * 1e18;
        uint256 feeBps = 10; // 0.1%

        uint256 fee = TradingMath.calculateFee(amount, feeBps);

        // Fee = 1000 * 10 / 10000 = 1
        assertEq(fee, 1 * 1e18);
    }

    function test_CalculatePositionValue_Profit() public {
        uint256 collateralAmount = 1000 * 1e18;
        int256 pnl = 100 * 1e18; // Profit

        uint256 value = TradingMath.calculatePositionValue(collateralAmount, pnl);

        assertEq(value, 1100 * 1e18); // 1000 + 100
    }

    function test_CalculatePositionValue_Loss() public {
        uint256 collateralAmount = 1000 * 1e18;
        int256 pnl = -200 * 1e18; // Loss

        uint256 value = TradingMath.calculatePositionValue(collateralAmount, pnl);

        assertEq(value, 800 * 1e18); // 1000 - 200
    }

    function test_CalculatePositionValue_LargeLoss() public {
        uint256 collateralAmount = 1000 * 1e18;
        int256 pnl = -1500 * 1e18; // Loss exceeds collateral

        uint256 value = TradingMath.calculatePositionValue(collateralAmount, pnl);

        assertEq(value, 0); // Should be 0, not negative
    }

    function test_CanLiquidate() public {
        uint256 collateralAmount = 1000 * 1e18;
        int256 pnl = -200 * 1e18; // Loss of 200
        uint256 liquidationThresholdBps = 8500; // 85%

        // Position value = 1000 - 200 = 800
        // Threshold = 1000 * 8500 / 10000 = 850
        // 800 < 850, so can liquidate
        bool canLiquidate = TradingMath.canLiquidate(collateralAmount, pnl, liquidationThresholdBps);

        assertTrue(canLiquidate);
    }

    function test_CannotLiquidate() public {
        uint256 collateralAmount = 1000 * 1e18;
        int256 pnl = -50 * 1e18; // Small loss
        uint256 liquidationThresholdBps = 8500; // 85%

        // Position value = 1000 - 50 = 950
        // Threshold = 850
        // 950 > 850, so cannot liquidate
        bool canLiquidate = TradingMath.canLiquidate(collateralAmount, pnl, liquidationThresholdBps);

        assertFalse(canLiquidate);
    }
}

