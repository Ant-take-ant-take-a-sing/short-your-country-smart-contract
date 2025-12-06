// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ICountryTrading} from "./interfaces/ICountryTrading.sol";
import {CountryRegistry} from "./CountryRegistry.sol";
import {LiquidityPool} from "./LiquidityPool.sol";
import {TradingMath} from "./libraries/TradingMath.sol";
import {FundingRateCalculator} from "./libraries/FundingRateCalculator.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title CountryTrading
 * @notice Main contract for trading country tokens with long/short positions
 * @dev Uses liquidity pool for profit/loss, implements funding rate mechanism
 */
contract CountryTrading is ICountryTrading, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // Constants
    uint256 public constant LEVERAGE = 1e18; // 1x leverage (1e18 = 100%)
    uint256 public constant TRADING_FEE_BPS = 10; // 0.1% (10 basis points)
    uint256 public constant LIQUIDATION_THRESHOLD_BPS = 8500; // 85% (8500 basis points)
    uint256 public constant MAX_POSITIONS_PER_USER = 100; // Maximum positions per user
    uint256 public constant MIN_POSITION_SIZE = 1e18; // Minimum position size (1 token with 18 decimals)
    uint256 public constant MAX_POSITION_SIZE = 1_000_000 * 1e18; // Maximum position size (1M tokens)
    uint256 public constant LIQUIDATOR_BONUS_BPS = 500; // 5% (500 basis points)

    // State variables
    IERC20 public immutable collateralToken;
    CountryRegistry public immutable countryRegistry;
    LiquidityPool public immutable liquidityPool;

    // User balances (collateral untuk margin)
    mapping(address => uint256) public collateralBalances;

    // Positions
    mapping(address => mapping(uint256 => Position)) public positions; // user => positionId => Position
    mapping(address => uint256[]) public userPositionIds; // user => positionIds[]
    mapping(address => uint256) public nextPositionId; // user => nextPositionId

    // Total protocol metrics
    uint256 public totalCollateral; // Total user collateral (not pool)
    uint256 public protocolFees; // Track protocol fees separately

    constructor(address _collateralToken, address _countryRegistry, address _liquidityPool) Ownable(msg.sender) {
        require(_collateralToken != address(0), "CountryTrading: Invalid collateral token");
        require(_countryRegistry != address(0), "CountryTrading: Invalid country registry");
        require(_liquidityPool != address(0), "CountryTrading: Invalid liquidity pool");

        collateralToken = IERC20(_collateralToken);
        countryRegistry = CountryRegistry(_countryRegistry);
        liquidityPool = LiquidityPool(_liquidityPool);
    }

    /**
     * @notice Deposit collateral (for margin)
     * @param amount Amount to deposit
     */
    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "CountryTrading: Amount must be greater than 0");

        collateralToken.safeTransferFrom(msg.sender, address(this), amount);
        collateralBalances[msg.sender] += amount;
        totalCollateral += amount;

        emit Deposit(msg.sender, amount);
    }

    /**
     * @notice Withdraw collateral
     * @param amount Amount to withdraw
     */
    function withdraw(uint256 amount) external nonReentrant {
        require(amount > 0, "CountryTrading: Amount must be greater than 0");
        require(collateralBalances[msg.sender] >= amount, "CountryTrading: Insufficient balance");
        require(collateralToken.balanceOf(address(this)) >= amount, "CountryTrading: Insufficient contract balance");

        // Check if withdrawal would cause any position to be undercollateralized
        _checkWithdrawalSafety(msg.sender, amount);

        collateralBalances[msg.sender] -= amount;
        totalCollateral -= amount;
        collateralToken.safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount);
    }

    /**
     * @notice Open a long position
     * @param countryCode Country code to long
     * @param collateralAmount Amount of collateral to use
     * @return positionId The ID of the opened position
     */
    function openLongPosition(bytes32 countryCode, uint256 collateralAmount)
        external
        nonReentrant
        returns (uint256 positionId)
    {
        require(collateralAmount >= MIN_POSITION_SIZE, "CountryTrading: Position too small");
        require(collateralAmount <= MAX_POSITION_SIZE, "CountryTrading: Position too large");
        require(countryRegistry.isCountryActive(countryCode), "CountryTrading: Country not active");
        require(userPositionIds[msg.sender].length < MAX_POSITIONS_PER_USER, "CountryTrading: Max positions reached");

        // Get current price
        (uint256 currentPrice,) = countryRegistry.getCountryPrice(countryCode);

        // Calculate position size (with 1x leverage, position size = collateral)
        uint256 positionSize = collateralAmount;

        // Calculate trading fee
        uint256 tradingFee = TradingMath.calculateFee(positionSize, TRADING_FEE_BPS);

        // Check sufficient collateral
        require(
            collateralBalances[msg.sender] >= collateralAmount + tradingFee, "CountryTrading: Insufficient collateral"
        );

        // Deduct collateral and fee
        collateralBalances[msg.sender] -= (collateralAmount + tradingFee);
        totalCollateral -= (collateralAmount + tradingFee);

        // Send trading fee to pool
        collateralToken.safeTransfer(address(liquidityPool), tradingFee);
        liquidityPool.receiveTradingFee(tradingFee);
        protocolFees += tradingFee; // Track for protocol

        // Update open interest in pool
        liquidityPool.updateOpenInterest(true, int256(positionSize));

        // Create position
        positionId = _createPosition(msg.sender, countryCode, true, collateralAmount, positionSize, currentPrice);

        emit PositionOpened(msg.sender, countryCode, positionId, true, collateralAmount, positionSize, currentPrice);

        emit ProtocolFeesCollected(tradingFee, "open");
    }

    /**
     * @notice Open a short position
     * @param countryCode Country code to short
     * @param collateralAmount Amount of collateral to use
     * @return positionId The ID of the opened position
     */
    function openShortPosition(bytes32 countryCode, uint256 collateralAmount)
        external
        nonReentrant
        returns (uint256 positionId)
    {
        require(collateralAmount >= MIN_POSITION_SIZE, "CountryTrading: Position too small");
        require(collateralAmount <= MAX_POSITION_SIZE, "CountryTrading: Position too large");
        require(countryRegistry.isCountryActive(countryCode), "CountryTrading: Country not active");
        require(userPositionIds[msg.sender].length < MAX_POSITIONS_PER_USER, "CountryTrading: Max positions reached");

        // Get current price
        (uint256 currentPrice,) = countryRegistry.getCountryPrice(countryCode);

        // Calculate position size (with 1x leverage, position size = collateral)
        uint256 positionSize = collateralAmount;

        // Calculate trading fee
        uint256 tradingFee = TradingMath.calculateFee(positionSize, TRADING_FEE_BPS);

        // Check sufficient collateral
        require(
            collateralBalances[msg.sender] >= collateralAmount + tradingFee, "CountryTrading: Insufficient collateral"
        );

        // Deduct collateral and fee
        collateralBalances[msg.sender] -= (collateralAmount + tradingFee);
        totalCollateral -= (collateralAmount + tradingFee);

        // Send trading fee to pool
        collateralToken.safeTransfer(address(liquidityPool), tradingFee);
        liquidityPool.receiveTradingFee(tradingFee);
        protocolFees += tradingFee; // Track for protocol

        // Update open interest in pool
        liquidityPool.updateOpenInterest(false, int256(positionSize));

        // Create position
        positionId = _createPosition(msg.sender, countryCode, false, collateralAmount, positionSize, currentPrice);

        emit PositionOpened(msg.sender, countryCode, positionId, false, collateralAmount, positionSize, currentPrice);

        emit ProtocolFeesCollected(tradingFee, "open");
    }

    /**
     * @notice Close a position
     * @param positionId ID of the position to close
     */
    function closePosition(uint256 positionId) external nonReentrant {
        Position storage position = positions[msg.sender][positionId];
        require(position.entryPrice > 0, "CountryTrading: Position does not exist");

        // Apply funding rate if needed
        _applyFundingRate(msg.sender, positionId);

        // Get current price
        (uint256 currentPrice,) = countryRegistry.getCountryPrice(position.countryCode);

        // Calculate P&L
        int256 pnl = TradingMath.calculatePnL(position.isLong, position.positionSize, position.entryPrice, currentPrice);

        // Calculate trading fee for closing
        uint256 positionValue = TradingMath.calculatePositionValue(position.collateralAmount, pnl);
        uint256 closingFee = TradingMath.calculateFee(positionValue, TRADING_FEE_BPS);

        // Handle profit/loss with pool
        if (pnl >= 0) {
            // Profit: pool pays profit, user gets collateral + profit - fee
            uint256 profit = uint256(pnl);

            // Calculate total return: collateral + profit
            uint256 totalReturn = position.collateralAmount + profit;

            // Calculate amount after fee
            uint256 amountAfterFee;
            if (totalReturn >= closingFee) {
                amountAfterFee = totalReturn - closingFee;
            } else {
                // Fee exceeds total, user gets nothing
                amountAfterFee = 0;
                closingFee = totalReturn; // Adjust fee to actual amount
            }

            // Return collateral to user balance
            collateralBalances[msg.sender] += position.collateralAmount;
            totalCollateral += position.collateralAmount;

            // Calculate how much profit to pay and how much fee to deduct
            // User should get: amountAfterFee = totalReturn - fee
            // We already returned collateral, so we need to:
            // 1. Pay profit (from pool)
            // 2. Deduct fee (from balance or profit)

            if (closingFee > 0) {
                // Calculate fee coverage: fee can be covered by collateral or profit
                uint256 feeFromCollateral =
                    closingFee > position.collateralAmount ? position.collateralAmount : closingFee;
                uint256 feeFromProfit = closingFee - feeFromCollateral;

                // Deduct fee from collateral (balance)
                if (feeFromCollateral > 0) {
                    collateralBalances[msg.sender] -= feeFromCollateral;
                    totalCollateral -= feeFromCollateral;
                    collateralToken.safeTransfer(address(liquidityPool), feeFromCollateral);
                    liquidityPool.receiveTradingFee(feeFromCollateral);
                }

                // Pay profit minus fee portion (if fee > collateral)
                uint256 profitToPay = profit > feeFromProfit ? profit - feeFromProfit : 0;
                if (profitToPay > 0) {
                    liquidityPool.payProfit(msg.sender, profitToPay);
                }

                // If fee > collateral + profit, we already adjusted closingFee above
            } else {
                // No fee, pay full profit
                if (profit > 0) {
                    liquidityPool.payProfit(msg.sender, profit);
                }
            }
        } else {
            // Loss: loss goes to pool, user gets collateral - loss - fee
            uint256 loss = uint256(-pnl);

            // Cap loss at collateral amount
            uint256 actualLoss = loss > position.collateralAmount ? position.collateralAmount : loss;

            // Transfer loss to pool
            if (actualLoss > 0) {
                collateralToken.safeTransfer(address(liquidityPool), actualLoss);
                liquidityPool.receiveLoss(actualLoss);
            }

            // Calculate remaining collateral after loss
            uint256 remainingCollateral = position.collateralAmount - actualLoss;

            // Calculate amount after fee
            uint256 amountAfterFee;
            if (remainingCollateral >= closingFee) {
                amountAfterFee = remainingCollateral - closingFee;
                collateralBalances[msg.sender] += amountAfterFee;
                totalCollateral += amountAfterFee;

                // Send fee to pool
                collateralToken.safeTransfer(address(liquidityPool), closingFee);
                liquidityPool.receiveTradingFee(closingFee);
            } else {
                // Fee exceeds remaining collateral
                amountAfterFee = 0;
                if (remainingCollateral > 0) {
                    // All remaining goes to pool as fee
                    collateralToken.safeTransfer(address(liquidityPool), remainingCollateral);
                    liquidityPool.receiveTradingFee(remainingCollateral);
                    closingFee = remainingCollateral; // Adjust fee
                }
            }
        }

        protocolFees += closingFee;

        // Update open interest in pool
        liquidityPool.updateOpenInterest(position.isLong, -int256(position.positionSize));

        // Remove position from user's list
        _removePosition(msg.sender, positionId);

        // Clear position
        delete positions[msg.sender][positionId];

        emit PositionClosed(
            msg.sender,
            position.countryCode,
            positionId,
            position.isLong,
            position.collateralAmount,
            position.positionSize,
            position.entryPrice,
            currentPrice,
            pnl
        );

        emit ProtocolFeesCollected(closingFee, "close");
    }

    /**
     * @notice Apply funding rate to a position
     * @param user User address
     * @param positionId Position ID
     */
    function _applyFundingRate(address user, uint256 positionId) internal {
        Position storage position = positions[user][positionId];

        (bool shouldApply,) = FundingRateCalculator.shouldApplyFunding(position.lastFundingTimestamp);
        if (!shouldApply) {
            return;
        }

        // Get pool metrics for funding rate calculation
        (, uint256 longOI, uint256 shortOI) = liquidityPool.getPoolMetrics();

        // Calculate funding rate
        int256 fundingRate = FundingRateCalculator.calculateFundingRate(longOI, shortOI);

        if (fundingRate != 0) {
            // Calculate funding fee
            int256 fundingFee =
                FundingRateCalculator.calculateFundingFee(position.positionSize, fundingRate, position.isLong);

            if (fundingFee > 0) {
                // Position pays funding fee
                uint256 feeAmount = uint256(fundingFee);

                // Deduct from collateral balance
                if (collateralBalances[user] >= feeAmount) {
                    collateralBalances[user] -= feeAmount;
                    totalCollateral -= feeAmount;
                    collateralToken.safeTransfer(address(liquidityPool), feeAmount);
                    liquidityPool.receiveFundingFee(feeAmount);
                } else {
                    // If insufficient, take from collateral
                    uint256 available = collateralBalances[user];
                    if (available > 0) {
                        collateralBalances[user] = 0;
                        totalCollateral -= available;
                        collateralToken.safeTransfer(address(liquidityPool), available);
                        liquidityPool.receiveFundingFee(available);
                    }
                }
            } else if (fundingFee < 0) {
                // Position receives funding fee (paid by pool)
                uint256 feeAmount = uint256(-fundingFee);
                liquidityPool.payProfit(user, feeAmount);
            }
        }

        // Update last funding timestamp
        position.lastFundingTimestamp = block.timestamp;
    }

    /**
     * @notice Liquidate a position that is undercollateralized
     * @param user Address of the user whose position to liquidate
     * @param positionId ID of the position to liquidate
     */
    function liquidatePosition(address user, uint256 positionId) external nonReentrant {
        require(user != address(0), "CountryTrading: Invalid user address");
        require(canLiquidate(user, positionId), "CountryTrading: Position cannot be liquidated");

        Position storage position = positions[user][positionId];
        require(position.entryPrice > 0, "CountryTrading: Position does not exist");

        // Apply funding rate if needed
        _applyFundingRate(user, positionId);

        // Get current price
        (uint256 currentPrice,) = countryRegistry.getCountryPrice(position.countryCode);

        // Calculate P&L
        int256 pnl = TradingMath.calculatePnL(position.isLong, position.positionSize, position.entryPrice, currentPrice);

        // Calculate liquidation amount (remaining value after loss)
        uint256 liquidationAmount = TradingMath.calculateLiquidationAmount(position.collateralAmount, pnl);

        // Liquidator gets a bonus (5% of remaining value)
        uint256 liquidatorBonus = (liquidationAmount * LIQUIDATOR_BONUS_BPS) / 10000;
        uint256 poolAmount = liquidationAmount - liquidatorBonus; // Pool gets the rest

        // Update open interest in pool
        liquidityPool.updateOpenInterest(position.isLong, -int256(position.positionSize));

        // Remove position from user's list
        _removePosition(user, positionId);

        // Clear position
        delete positions[user][positionId];

        // Transfer liquidation amount (from collateral that's still in contract)
        // Note: liquidationAmount is positionValue, which may be less than collateralAmount
        // We transfer the actual liquidationAmount, not the full collateral
        if (liquidationAmount > 0) {
            // Transfer liquidator bonus
            if (liquidatorBonus > 0) {
                collateralToken.safeTransfer(msg.sender, liquidatorBonus);
            }

            // Rest goes to pool (loss)
            if (poolAmount > 0) {
                collateralToken.safeTransfer(address(liquidityPool), poolAmount);
                liquidityPool.receiveLoss(poolAmount);
            }
        }
        // If liquidationAmount == 0, position is fully liquidated, nothing to transfer

        // Protocol gets small fee from liquidation (1% of pool amount)
        uint256 protocolFee = (poolAmount * 100) / 10000;
        if (protocolFee > 0) {
            protocolFees += protocolFee;
        }

        emit PositionLiquidated(user, position.countryCode, positionId, liquidationAmount);
        emit ProtocolFeesCollected(protocolFee, "liquidation");
    }

    /**
     * @notice Get position details
     * @param user User address
     * @param positionId Position ID
     * @return Position struct
     */
    function getPosition(address user, uint256 positionId) external view returns (Position memory) {
        return positions[user][positionId];
    }

    /**
     * @notice Get all position IDs for a user
     * @param user User address
     * @return Array of position IDs
     */
    function getUserPositions(address user) external view returns (uint256[] memory) {
        return userPositionIds[user];
    }

    /**
     * @notice Get user's collateral balance
     * @param user User address
     * @return Collateral balance
     */
    function getCollateralBalance(address user) external view returns (uint256) {
        return collateralBalances[user];
    }

    /**
     * @notice Get current value of a position
     * @param user User address
     * @param positionId Position ID
     * @return Current position value
     */
    function getPositionValue(address user, uint256 positionId) external view returns (uint256) {
        Position memory position = positions[user][positionId];
        require(position.entryPrice > 0, "CountryTrading: Position does not exist");

        (uint256 currentPrice,) = countryRegistry.getCountryPrice(position.countryCode);
        int256 pnl = TradingMath.calculatePnL(position.isLong, position.positionSize, position.entryPrice, currentPrice);

        return TradingMath.calculatePositionValue(position.collateralAmount, pnl);
    }

    /**
     * @notice Check if a position can be liquidated
     * @param user User address
     * @param positionId Position ID
     * @return Whether position can be liquidated
     */
    function canLiquidate(address user, uint256 positionId) public view returns (bool) {
        Position memory position = positions[user][positionId];
        if (position.entryPrice == 0) {
            return false;
        }

        (uint256 currentPrice,) = countryRegistry.getCountryPrice(position.countryCode);
        int256 pnl = TradingMath.calculatePnL(position.isLong, position.positionSize, position.entryPrice, currentPrice);

        return TradingMath.canLiquidate(position.collateralAmount, pnl, LIQUIDATION_THRESHOLD_BPS);
    }

    /**
     * @notice Check if withdrawal is safe (won't cause undercollateralization)
     * @param user User address
     * @param amount Amount to withdraw
     */
    function _checkWithdrawalSafety(address user, uint256 amount) internal view {
        uint256[] memory positionIds = userPositionIds[user];

        for (uint256 i = 0; i < positionIds.length; i++) {
            uint256 positionId = positionIds[i];
            Position memory position = positions[user][positionId];

            if (position.entryPrice == 0) continue;

            // Calculate current position value
            (uint256 currentPrice,) = countryRegistry.getCountryPrice(position.countryCode);
            int256 pnl =
                TradingMath.calculatePnL(position.isLong, position.positionSize, position.entryPrice, currentPrice);

            // Check if position would be undercollateralized after withdrawal
            uint256 positionValue = TradingMath.calculatePositionValue(position.collateralAmount, pnl);

            uint256 requiredCollateral =
                positionValue > position.collateralAmount ? position.collateralAmount : positionValue;

            uint256 availableCollateral = collateralBalances[user] - amount;

            require(
                availableCollateral >= requiredCollateral,
                "CountryTrading: Withdrawal would cause undercollateralization"
            );
        }
    }

    /**
     * @notice Remove position ID from user's list
     * @param user User address
     * @param positionId Position ID to remove
     */
    function _removePosition(address user, uint256 positionId) internal {
        uint256[] storage positionIds = userPositionIds[user];
        uint256 length = positionIds.length;

        for (uint256 i = 0; i < length; i++) {
            if (positionIds[i] == positionId) {
                positionIds[i] = positionIds[length - 1];
                positionIds.pop();
                return;
            }
        }
        revert("CountryTrading: Position not found in user list");
    }

    /**
     * @notice Withdraw protocol fees (owner only)
     * @dev Protocol fees are tracked but stored in the liquidity pool
     * @dev Owner should withdraw from LiquidityPool directly, this function only tracks
     * @param amount Amount to withdraw (must be <= protocolFees)
     * @notice This function only tracks protocol fees. Actual withdrawal must be done
     *         via LiquidityPool.withdraw() by the pool owner. If pool owner == trading owner,
     *         they can withdraw directly from pool.
     */
    function withdrawProtocolFees(uint256 amount) external onlyOwner {
        require(amount <= protocolFees, "CountryTrading: Insufficient protocol fees");
        require(amount > 0, "CountryTrading: Amount must be greater than 0");

        // Protocol fees are stored in the liquidity pool, not in this contract
        // We only track the amount here. Actual withdrawal must be done via pool
        protocolFees -= amount;

        emit ProtocolFeesWithdrawn(owner(), amount);

        // Note: To actually withdraw, owner must call LiquidityPool.withdraw()
        // This assumes pool owner == trading contract owner, or they coordinate
    }

    /**
     * @notice Get position P&L without closing
     * @param user User address
     * @param positionId Position ID
     * @return pnl Profit or loss
     * @return currentPrice Current price from oracle
     */
    function getPositionPnL(address user, uint256 positionId) external view returns (int256 pnl, uint256 currentPrice) {
        Position memory position = positions[user][positionId];
        require(position.entryPrice > 0, "CountryTrading: Position does not exist");

        (currentPrice,) = countryRegistry.getCountryPrice(position.countryCode);
        pnl = TradingMath.calculatePnL(position.isLong, position.positionSize, position.entryPrice, currentPrice);
    }

    /**
     * @notice Get user's position count
     * @param user User address
     * @return count Number of active positions
     */
    function getUserPositionCount(address user) external view returns (uint256 count) {
        return userPositionIds[user].length;
    }

    /**
     * @notice Get protocol metrics
     * @return totalCollateral_ Total collateral in contract
     * @return protocolFees_ Total protocol fees collected
     */
    function getProtocolMetrics() external view returns (uint256 totalCollateral_, uint256 protocolFees_) {
        return (totalCollateral, protocolFees);
    }

    /**
     * @notice Get funding rate for current market
     * @return fundingRate Current funding rate in basis points
     */
    function getCurrentFundingRate() external view returns (int256 fundingRate) {
        (, uint256 longOI, uint256 shortOI) = liquidityPool.getPoolMetrics();
        return FundingRateCalculator.calculateFundingRate(longOI, shortOI);
    }

    /**
     * @notice Internal function to create a position
     * @param user User address
     * @param countryCode Country code
     * @param isLong Whether position is long
     * @param collateralAmount Collateral amount
     * @param positionSize Position size
     * @param entryPrice Entry price
     * @return positionId Created position ID
     */
    function _createPosition(
        address user,
        bytes32 countryCode,
        bool isLong,
        uint256 collateralAmount,
        uint256 positionSize,
        uint256 entryPrice
    ) internal returns (uint256 positionId) {
        positionId = nextPositionId[user]++;
        positions[user][positionId] = Position({
            countryCode: countryCode,
            isLong: isLong,
            collateralAmount: collateralAmount,
            positionSize: positionSize,
            entryPrice: entryPrice,
            entryTimestamp: block.timestamp,
            lastFundingTimestamp: block.timestamp
        });

        userPositionIds[user].push(positionId);
    }
}
