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
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title CountryTrading
 * @notice Main contract for trading country tokens with long/short positions
 * @dev Uses liquidity pool for profit/loss, implements funding rate mechanism
 */
contract CountryTrading is ICountryTrading, ReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;

    // Constants
    uint256 public constant LEVERAGE = 1e18; // 1x leverage (1e18 = 100%)
    uint256 public tradingFeeBps = 10; // 0.1% (10 basis points) - Mutable
    uint256 public liquidationThresholdBps = 8500; // 85% (8500 basis points) - Mutable
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
    function deposit(uint256 amount) external nonReentrant whenNotPaused {
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
    function withdraw(uint256 amount) external nonReentrant whenNotPaused {
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
        whenNotPaused
        returns (uint256 positionId)
    {
        return _openPosition(countryCode, collateralAmount, true);
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
        whenNotPaused
        returns (uint256 positionId)
    {
        return _openPosition(countryCode, collateralAmount, false);
    }

    /**
     * @notice Internal function to handle position opening logic
     * @param countryCode Country code
     * @param collateralAmount Collateral amount
     * @param isLong Whether position is long
     * @return positionId The ID of the opened position
     */
    function _openPosition(bytes32 countryCode, uint256 collateralAmount, bool isLong)
        internal
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
        uint256 tradingFee = TradingMath.calculateFee(positionSize, tradingFeeBps);

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
        liquidityPool.updateOpenInterest(isLong, int256(positionSize));

        // Create position
        positionId = _createPosition(msg.sender, countryCode, isLong, collateralAmount, positionSize, currentPrice);

        emit PositionOpened(msg.sender, countryCode, positionId, isLong, collateralAmount, positionSize, currentPrice);

        emit ProtocolFeesCollected(tradingFee, "open");
    }

    /**
     * @notice Close a position
     * @param positionId ID of the position to close
     */
    function closePosition(uint256 positionId) public nonReentrant whenNotPaused {
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
        uint256 closingFee = TradingMath.calculateFee(positionValue, tradingFeeBps);

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
     * @notice Close a portion of a position (Partial Close)
     * @param positionId ID of the position to close
     * @param closeRatioBps Percentage to close in basis points (1 = 0.01%, 10000 = 100%)
     */
    function closePositionPartial(uint256 positionId, uint256 closeRatioBps) external nonReentrant whenNotPaused {
        require(closeRatioBps > 0, "CountryTrading: Ratio must be > 0");
        require(closeRatioBps <= 10000, "CountryTrading: Ratio must be <= 100%");

        // If 100%, redirect to full close
        if (closeRatioBps == 10000) {
            closePosition(positionId);
            return;
        }

        Position storage position = positions[msg.sender][positionId];
        require(position.entryPrice > 0, "CountryTrading: Position does not exist");

        // Apply funding rate first
        _applyFundingRate(msg.sender, positionId);

        // Get current price
        (uint256 currentPrice,) = countryRegistry.getCountryPrice(position.countryCode);

        // Calculate P&L for the ENTIRE position first
        int256 totalPnl = TradingMath.calculatePnL(position.isLong, position.positionSize, position.entryPrice, currentPrice);

        // Calculate portions to close
        // If closeRatio is 5000 (50%), we take 50% of collateral and 50% of the P&L
        uint256 collateralToClose = (position.collateralAmount * closeRatioBps) / 10000;
        uint256 sizeToClose = (position.positionSize * closeRatioBps) / 10000;
        int256 pnlToRealize = (totalPnl * int256(closeRatioBps)) / 10000;

        // Ensure we don't leave dust
        require(position.positionSize - sizeToClose >= MIN_POSITION_SIZE, "CountryTrading: Remaining position too small");

        // Calculate trading fee only for the closed portion
        // Value of closed portion = Collateral + PnL (Unrealized)
        uint256 closedPortionValue = TradingMath.calculatePositionValue(collateralToClose, pnlToRealize);
        uint256 closingFee = TradingMath.calculateFee(closedPortionValue, tradingFeeBps);

        // --- P&L DISTRIBUTION (Similar to full close logic but proportional) ---
        uint256 amountToUser;
        
        if (pnlToRealize >= 0) {
            // Profit scenario
            uint256 profit = uint256(pnlToRealize);
            uint256 totalReturn = collateralToClose + profit;

            // Cap fee at total return
            if (closingFee > totalReturn) {
                closingFee = totalReturn;
                amountToUser = 0;
            } else {
                amountToUser = totalReturn - closingFee;
            }

            // Internal accounting: Return collateral portion to balance
            collateralBalances[msg.sender] += collateralToClose; // Add purely the principal
            totalCollateral += collateralToClose;

            // Handle Profit & Fee payment
            
            // Fee logic
            uint256 feeFromCollateral = closingFee > collateralToClose ? collateralToClose : closingFee;
            uint256 feeFromProfit = closingFee - feeFromCollateral;

            if (feeFromCollateral > 0) {
                collateralBalances[msg.sender] -= feeFromCollateral;
                totalCollateral -= feeFromCollateral;
                collateralToken.safeTransfer(address(liquidityPool), feeFromCollateral);
                liquidityPool.receiveTradingFee(feeFromCollateral);
            }

            uint256 profitToPay = profit > feeFromProfit ? profit - feeFromProfit : 0;
            if (profitToPay > 0) {
                liquidityPool.payProfit(msg.sender, profitToPay);
            }

        } else {
            // Loss scenario
            uint256 loss = uint256(-pnlToRealize);
            
            // Cap loss at collateral (cannot lose more than collateral)
            uint256 actualLoss = loss > collateralToClose ? collateralToClose : loss;
            
            // Remove loss from collateral
            uint256 remainingCollateralAfterLoss = collateralToClose - actualLoss;

            // Send loss to pool
            if (actualLoss > 0) {
                 collateralToken.safeTransfer(address(liquidityPool), actualLoss);
                 liquidityPool.receiveLoss(actualLoss);
            }

            // Fee logic on the remaining value
            if (closingFee > remainingCollateralAfterLoss) {
                closingFee = remainingCollateralAfterLoss;
                amountToUser = 0;
                // All remainder goes to fee
                 collateralToken.safeTransfer(address(liquidityPool), remainingCollateralAfterLoss);
                 liquidityPool.receiveTradingFee(remainingCollateralAfterLoss);
            } else {
                 amountToUser = remainingCollateralAfterLoss - closingFee;
                 // Send fee to pool
                 collateralToken.safeTransfer(address(liquidityPool), closingFee);
                 liquidityPool.receiveTradingFee(closingFee);
                 
                 // Return remainder to user balance
                 collateralBalances[msg.sender] += amountToUser;
                 totalCollateral += amountToUser;
            }
        }

        protocolFees += closingFee;

        // --- UPDATE STATE ---
        // Reduce the position size and collateral by the CLOSED portion
        position.collateralAmount -= collateralToClose;
        position.positionSize -= sizeToClose;
        
        // Note: entryPrice DOES NOT CHANGE. This is key for Partial Close.

        emit PositionPartiallyClosed(
            msg.sender,
            position.countryCode,
            positionId,
            closeRatioBps,
            amountToUser, // Realized Amount (Principal + Profit - Fee) returned to balance
            position.collateralAmount,
            position.positionSize
        );
        
        emit ProtocolFeesCollected(closingFee, "close-partial");
    }

    /**
     * @notice Increase collateral for an existing position
     * @param positionId Position ID to top up
     * @param amount Amount of collateral to add
     */
    function increaseCollateral(uint256 positionId, uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "CountryTrading: Amount must be greater than 0");
        Position storage position = positions[msg.sender][positionId];
        require(position.entryPrice > 0, "CountryTrading: Position does not exist");

        // Transfer collateral from user
        collateralToken.safeTransferFrom(msg.sender, address(this), amount);
        
        // Update position collateral
        position.collateralAmount += amount;
        
        // Update user balances
        collateralBalances[msg.sender] += amount;
        totalCollateral += amount;

        emit CollateralIncreased(msg.sender, positionId, amount, position.collateralAmount);
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
    function liquidatePosition(address user, uint256 positionId) external nonReentrant whenNotPaused {
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
            
            // Calculate protocol fee from the pool's share
            uint256 protocolFee = (poolAmount * 100) / 10000;
            if (protocolFee > 0) {
                protocolFees += protocolFee;
                poolAmount -= protocolFee; // Keep fee in contract, send rest to pool
            }

            // Transfer liquidator bonus
            if (liquidatorBonus > 0) {
                collateralToken.safeTransfer(msg.sender, liquidatorBonus);
            }

            // Rest goes to pool (loss)
            if (poolAmount > 0) {
                collateralToken.safeTransfer(address(liquidityPool), poolAmount);
                liquidityPool.receiveLoss(poolAmount);
            }
            
            emit ProtocolFeesCollected(protocolFee, "liquidation");
        }

        emit PositionLiquidated(user, position.countryCode, positionId, liquidationAmount);
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

    // --- Admin Setter Functions ---

    event TradingFeeUpdated(uint256 oldFee, uint256 newFee);
    event LiquidationThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);

    /**
     * @notice Update trading fee
     * @param _tradingFeeBps New trading fee in basis points
     */
    function setTradingFee(uint256 _tradingFeeBps) external onlyOwner {
        require(_tradingFeeBps <= 500, "CountryTrading: Fee too high"); // Max 5%
        emit TradingFeeUpdated(tradingFeeBps, _tradingFeeBps);
        tradingFeeBps = _tradingFeeBps;
    }

    /**
     * @notice Update liquidation threshold
     * @param _liquidationThresholdBps New threshold in basis points
     */
    function setLiquidationThreshold(uint256 _liquidationThresholdBps) external onlyOwner {
        require(_liquidationThresholdBps >= 5000, "CountryTrading: Threshold too low"); // Min 50%
        require(_liquidationThresholdBps <= 9500, "CountryTrading: Threshold too high"); // Max 95%
        emit LiquidationThresholdUpdated(liquidationThresholdBps, _liquidationThresholdBps);
        liquidationThresholdBps = _liquidationThresholdBps;
    }

    // --- End Admin Setter Functions ---

    /**
     * @notice Pause the contract (Emergency only)
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the contract
     */
    function unpause() external onlyOwner {
        _unpause();
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

        return TradingMath.canLiquidate(position.collateralAmount, pnl, liquidationThresholdBps);
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
