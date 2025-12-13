// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title ICountryTrading
 * @notice Interface for Country Trading Contract
 */
interface ICountryTrading {
    // Events
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event PositionOpened(
        address indexed user,
        bytes32 indexed countryCode,
        uint256 positionId,
        bool isLong,
        uint256 collateralAmount,
        uint256 positionSize,
        uint256 entryPrice
    );
    event PositionClosed(
        address indexed user,
        bytes32 indexed countryCode,
        uint256 positionId,
        bool isLong,
        uint256 collateralAmount,
        uint256 positionSize,
        uint256 entryPrice,
        uint256 exitPrice,
        int256 pnl
    );
    event PositionLiquidated(
        address indexed user, bytes32 indexed countryCode, uint256 positionId, uint256 liquidatedAmount
    );
    event PositionPartiallyClosed(
        address indexed user,
        bytes32 indexed countryCode,
        uint256 positionId,
        uint256 closeRatioBps, // Basis points (5000 = 50%)
        uint256 realizedPnl,
        uint256 remainingCollateral,
        uint256 remainingSize
    );
    event CountryAdded(bytes32 indexed countryCode, address priceFeed);
    event CountryRemoved(bytes32 indexed countryCode);
    event ProtocolFeesCollected(uint256 amount, string source);
    event ProtocolFeesWithdrawn(address indexed owner, uint256 amount);
    event CollateralIncreased(address indexed user, uint256 positionId, uint256 amount, uint256 newCollateralAmount);

    // Structs
    struct Position {
        bytes32 countryCode;
        bool isLong;
        uint256 collateralAmount;
        uint256 positionSize;
        uint256 entryPrice;
        uint256 entryTimestamp;
        uint256 lastFundingTimestamp;
    }

    // Functions
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function openLongPosition(bytes32 countryCode, uint256 collateralAmount) external returns (uint256 positionId);
    function openShortPosition(bytes32 countryCode, uint256 collateralAmount) external returns (uint256 positionId);
    function closePosition(uint256 positionId) external;
    function liquidatePosition(address user, uint256 positionId) external;
    function increaseCollateral(uint256 positionId, uint256 amount) external;
    function closePositionPartial(uint256 positionId, uint256 closeRatioBps) external;
    function getPosition(address user, uint256 positionId) external view returns (Position memory);
    function getUserPositions(address user) external view returns (uint256[] memory);
    function getCollateralBalance(address user) external view returns (uint256);
    function getPositionValue(address user, uint256 positionId) external view returns (uint256);
    function canLiquidate(address user, uint256 positionId) external view returns (bool);
    function protocolFees() external view returns (uint256);
    function getPositionPnL(address user, uint256 positionId) external view returns (int256 pnl, uint256 currentPrice);
    function getUserPositionCount(address user) external view returns (uint256);
    function getProtocolMetrics() external view returns (uint256 totalCollateral, uint256 protocolFees);
    function getCurrentFundingRate() external view returns (int256 fundingRate);
}

