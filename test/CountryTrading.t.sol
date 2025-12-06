// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {CountryTrading} from "../src/CountryTrading.sol";
import {CountryRegistry} from "../src/CountryRegistry.sol";
import {LiquidityPool} from "../src/LiquidityPool.sol";
import {MockChainlinkOracle} from "../src/mocks/MockChainlinkOracle.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title CountryTradingTest
 * @notice Comprehensive tests for CountryTrading contract
 */
contract CountryTradingTest is Test {
    CountryTrading public trading;
    CountryRegistry public registry;
    LiquidityPool public pool;
    MockERC20 public collateralToken;
    MockChainlinkOracle public priceFeed;

    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public owner = address(this);

    bytes32 public constant US_CODE = keccak256("US");
    bytes32 public constant ID_CODE = keccak256("ID");

    uint256 public constant INITIAL_BALANCE = 100000 * 1e18;
    uint256 public constant LARGE_BALANCE = 5_000_000 * 1e18; // For large position tests

    function setUp() public {
        // Deploy mock collateral token
        collateralToken = new MockERC20("Test USDT", "TUSDT");
        collateralToken.mint(owner, LARGE_BALANCE);
        collateralToken.mint(user1, INITIAL_BALANCE);
        collateralToken.mint(user2, INITIAL_BALANCE);

        // Deploy mock price feed
        priceFeed = new MockChainlinkOracle(3000 * 10 ** 8); // $3000

        // Deploy CountryRegistry
        registry = new CountryRegistry();

        // Add country to registry
        registry.addCountry(US_CODE, "United States", address(priceFeed));

        // Deploy LiquidityPool
        pool = new LiquidityPool(address(collateralToken));

        // Deposit initial liquidity to pool
        collateralToken.approve(address(pool), type(uint256).max);
        pool.deposit(50000 * 1e18); // 50k tokens to pool

        // Deploy CountryTrading
        trading = new CountryTrading(address(collateralToken), address(registry), address(pool));

        // Set trading contract in pool (authorized caller)
        pool.setTradingContract(address(trading));

        // Approve spending
        collateralToken.approve(address(trading), type(uint256).max);
        vm.prank(user1);
        collateralToken.approve(address(trading), type(uint256).max);
        vm.prank(user2);
        collateralToken.approve(address(trading), type(uint256).max);
    }

    function test_Deposit() public {
        uint256 amount = 1000 * 1e18;

        trading.deposit(amount);

        assertEq(trading.getCollateralBalance(owner), amount);
        assertEq(collateralToken.balanceOf(address(trading)), amount);
    }

    function test_Withdraw() public {
        uint256 depositAmount = 1000 * 1e18;
        uint256 withdrawAmount = 500 * 1e18;

        trading.deposit(depositAmount);
        trading.withdraw(withdrawAmount);

        assertEq(trading.getCollateralBalance(owner), depositAmount - withdrawAmount);
    }

    function test_OpenLongPosition() public {
        uint256 depositAmount = 10000 * 1e18;
        uint256 collateralAmount = 1000 * 1e18;

        trading.deposit(depositAmount);
        uint256 positionId = trading.openLongPosition(US_CODE, collateralAmount);

        assertEq(positionId, 0);
        assertEq(trading.getUserPositionCount(owner), 1);
    }

    function test_OpenShortPosition() public {
        uint256 depositAmount = 10000 * 1e18;
        uint256 collateralAmount = 1000 * 1e18;

        trading.deposit(depositAmount);
        uint256 positionId = trading.openShortPosition(US_CODE, collateralAmount);

        assertEq(positionId, 0);
        assertEq(trading.getUserPositionCount(owner), 1);
    }

    function test_ClosePosition() public {
        uint256 depositAmount = 10000 * 1e18;
        uint256 collateralAmount = 1000 * 1e18;

        trading.deposit(depositAmount);
        uint256 positionId = trading.openLongPosition(US_CODE, collateralAmount);

        // Update price to simulate profit
        priceFeed.updatePrice(3500 * 10 ** 8); // Price up to $3500

        trading.closePosition(positionId);

        assertEq(trading.getUserPositionCount(owner), 0);
    }

    function test_Liquidation() public {
        uint256 depositAmount = 10000 * 1e18;
        uint256 collateralAmount = 1000 * 1e18;

        vm.prank(user1);
        trading.deposit(depositAmount);

        vm.prank(user1);
        uint256 positionId = trading.openLongPosition(US_CODE, collateralAmount);

        // Update price to cause liquidation (price drops significantly)
        priceFeed.updatePrice(2000 * 10 ** 8); // Price down to $2000 (33% drop)

        // Check if can liquidate
        assertTrue(trading.canLiquidate(user1, positionId));

        // Liquidate
        trading.liquidatePosition(user1, positionId);

        assertEq(trading.getUserPositionCount(user1), 0);
    }

    function test_Revert_OpenPositionWithoutDeposit() public {
        vm.expectRevert("CountryTrading: Insufficient collateral");
        trading.openLongPosition(US_CODE, 1000 * 1e18);
    }

    function test_Revert_OpenPositionTooSmall() public {
        trading.deposit(10000 * 1e18);
        vm.expectRevert("CountryTrading: Position too small");
        trading.openLongPosition(US_CODE, 0.5 * 1e18); // Less than MIN_POSITION_SIZE
    }

    function test_Revert_OpenPositionTooLarge() public {
        // MAX_POSITION_SIZE is 1_000_000 * 1e18, so use amount larger than that
        uint256 largeAmount = 1_000_001 * 1e18; // Just over the limit
        uint256 fee = (largeAmount * 10) / 10000; // 0.1% fee
        trading.deposit(largeAmount + fee);

        vm.expectRevert("CountryTrading: Position too large");
        trading.openLongPosition(US_CODE, largeAmount); // More than MAX_POSITION_SIZE
    }

    function test_Revert_WithdrawInsufficientBalance() public {
        vm.expectRevert("CountryTrading: Insufficient balance");
        trading.withdraw(1000 * 1e18);
    }

    function test_GetPositionPnL() public {
        uint256 depositAmount = 10000 * 1e18;
        uint256 collateralAmount = 1000 * 1e18;

        trading.deposit(depositAmount);
        uint256 positionId = trading.openLongPosition(US_CODE, collateralAmount);

        // Update price
        priceFeed.updatePrice(3500 * 10 ** 8);

        (int256 pnl, uint256 currentPrice) = trading.getPositionPnL(owner, positionId);

        assertGt(pnl, 0); // Should be profit
        assertEq(currentPrice, 3500 * 1e18); // Scaled to 18 decimals
    }

    function test_GetProtocolMetrics() public {
        uint256 depositAmount = 10000 * 1e18;
        uint256 collateralAmount = 1000 * 1e18;

        trading.deposit(depositAmount);
        trading.openLongPosition(US_CODE, collateralAmount);

        (uint256 totalCollateral, uint256 protocolFees) = trading.getProtocolMetrics();

        assertGt(totalCollateral, 0);
        assertGt(protocolFees, 0);
    }

    function test_GetCurrentFundingRate() public {
        int256 fundingRate = trading.getCurrentFundingRate();
        // Initially should be 0 (no positions)
        assertEq(fundingRate, 0);
    }
}

/**
 * @title MockERC20
 * @notice Mock ERC20 token for testing
 */
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

