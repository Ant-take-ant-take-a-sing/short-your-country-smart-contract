// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title LiquidityPool
 * @notice Manages liquidity pool for trading protocol
 * @dev Pool receives losses, pays profits, and collects fees
 */
contract LiquidityPool is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // State variables
    IERC20 public immutable collateralToken;
    uint256 public poolBalance;
    address public tradingContract; // Authorized trading contract

    // Open interest tracking
    uint256 public totalLongOpenInterest;
    uint256 public totalShortOpenInterest;

    // Events
    event PoolDeposit(address indexed provider, uint256 amount);
    event PoolWithdraw(address indexed provider, uint256 amount);
    event ProfitPaid(address indexed trader, uint256 amount);
    event LossReceived(uint256 amount);
    event FundingFeeReceived(uint256 amount);
    event TradingFeeReceived(uint256 amount);

    constructor(address _collateralToken) Ownable(msg.sender) {
        require(_collateralToken != address(0), "LiquidityPool: Invalid token");
        collateralToken = IERC20(_collateralToken);
    }

    /**
     * @notice Deposit liquidity to pool (only owner for now, can be extended for LP tokens)
     * @param amount Amount to deposit
     */
    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "LiquidityPool: Amount must be greater than 0");

        collateralToken.safeTransferFrom(msg.sender, address(this), amount);
        poolBalance += amount;

        emit PoolDeposit(msg.sender, amount);
    }

    /**
     * @notice Withdraw liquidity from pool (only owner for now)
     * @param amount Amount to withdraw
     */
    function withdraw(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "LiquidityPool: Amount must be greater than 0");
        require(poolBalance >= amount, "LiquidityPool: Insufficient pool balance");

        poolBalance -= amount;
        collateralToken.safeTransfer(owner(), amount);

        emit PoolWithdraw(owner(), amount);
    }

    /**
     * @notice Set trading contract (only owner)
     * @param _tradingContract Address of trading contract
     */
    function setTradingContract(address _tradingContract) external onlyOwner {
        require(_tradingContract != address(0), "LiquidityPool: Invalid address");
        tradingContract = _tradingContract;
    }

    /**
     * @notice Pay profit to trader (called by trading contract)
     * @param trader Trader address
     * @param amount Profit amount
     */
    function payProfit(address trader, uint256 amount) external {
        require(msg.sender == tradingContract, "LiquidityPool: Only trading contract");
        require(amount > 0, "LiquidityPool: Invalid amount");
        require(poolBalance >= amount, "LiquidityPool: Insufficient pool balance");

        poolBalance -= amount;
        collateralToken.safeTransfer(trader, amount);

        emit ProfitPaid(trader, amount);
    }

    /**
     * @notice Receive loss from trader (called by trading contract)
     * @param amount Loss amount
     */
    function receiveLoss(uint256 amount) external {
        require(msg.sender == tradingContract, "LiquidityPool: Only trading contract");
        require(amount > 0, "LiquidityPool: Invalid amount");

        // Loss is already in the contract (from trader's collateral)
        // Just update pool balance
        poolBalance += amount;

        emit LossReceived(amount);
    }

    /**
     * @notice Receive funding fees (called by trading contract)
     * @param amount Funding fee amount
     */
    function receiveFundingFee(uint256 amount) external {
        require(msg.sender == tradingContract, "LiquidityPool: Only trading contract");
        if (amount > 0) {
            poolBalance += amount;
            emit FundingFeeReceived(amount);
        }
    }

    /**
     * @notice Receive trading fees (called by trading contract)
     * @param amount Trading fee amount
     */
    function receiveTradingFee(uint256 amount) external {
        require(msg.sender == tradingContract, "LiquidityPool: Only trading contract");
        if (amount > 0) {
            poolBalance += amount;
            emit TradingFeeReceived(amount);
        }
    }

    /**
     * @notice Update open interest (called by trading contract)
     * @param isLong Whether position is long
     * @param amount Amount to add (positive) or subtract (negative via int256)
     */
    function updateOpenInterest(bool isLong, int256 amount) external {
        require(msg.sender == tradingContract, "LiquidityPool: Only trading contract");

        if (isLong) {
            if (amount > 0) {
                totalLongOpenInterest += uint256(amount);
            } else {
                totalLongOpenInterest -= uint256(-amount);
            }
        } else {
            if (amount > 0) {
                totalShortOpenInterest += uint256(amount);
            } else {
                totalShortOpenInterest -= uint256(-amount);
            }
        }
    }

    /**
     * @notice Get pool metrics
     * @return poolBalance_ Current pool balance
     * @return longOI Total long open interest
     * @return shortOI Total short open interest
     */
    function getPoolMetrics() external view returns (uint256 poolBalance_, uint256 longOI, uint256 shortOI) {
        return (poolBalance, totalLongOpenInterest, totalShortOpenInterest);
    }
}

