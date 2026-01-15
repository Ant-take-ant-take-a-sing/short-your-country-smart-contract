// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {CountryTrading} from "../src/CountryTrading.sol";
import {CountryRegistry} from "../src/CountryRegistry.sol";
import {LiquidityPool} from "../src/LiquidityPool.sol";
import {MockChainlinkOracle} from "../src/mocks/MockChainlinkOracle.sol";
import {ICountryTrading} from "../src/interfaces/ICountryTrading.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PartialCloseTest is Test {
    CountryTrading trading;
    CountryRegistry registry;
    LiquidityPool pool;
    MockERC20 usdt;
    MockChainlinkOracle ethFeed;

    address owner = address(this);
    address user = address(0x1);
    bytes32 countryCode = "ID"; // Indonesia

    function setUp() public {
        // Deploy Mock USDT
        usdt = new MockERC20("Test USDT", "TUSDT");

        // Deploy Registry
        registry = new CountryRegistry();

        // Deploy Liquidity Pool
        pool = new LiquidityPool(address(usdt));

        // Deploy CountryTrading
        trading = new CountryTrading(address(usdt), address(registry), address(pool));

        // Setup Pool
        pool.setTradingContract(address(trading));

        // Add Country
        ethFeed = new MockChainlinkOracle(2000 * 1e8); // Initial Price $2,000
        registry.addCountry(countryCode, "Indonesia", address(ethFeed));

        // Setup Liquidity
        usdt.mint(owner, 1_000_000 * 1e18);
        usdt.approve(address(pool), 1_000_000 * 1e18);
        pool.deposit(1_000_000 * 1e18); // Pool has $1M tracked balance

        // Setup User
        usdt.mint(user, 10_000 * 1e18);
        vm.startPrank(user);
        usdt.approve(address(trading), type(uint256).max);
        trading.deposit(1000 * 1e18); // User deposits $1,000
        vm.stopPrank();
    }

    function test_PartialClose_Profit() public {
        vm.startPrank(user);

        // 1. Open Long Position: $100 Collateral -> $100 Size (1x Leverage)
        // Entry Price: $2,000
        uint256 collateral = 100 * 1e18;
        uint256 posId = trading.openLongPosition(countryCode, collateral);

        // 2. Price Increases by 10% -> $2,200
        // Profit should be 10% of Size ($100) = $10
        ethFeed.updatePrice(2200 * 1e8);

        // Record balances before close
        uint256 internalBalanceBefore = trading.getCollateralBalance(user);
        uint256 walletBalanceBefore = usdt.balanceOf(user);

        // 3. Partial Close 50% (5000 bps)
        trading.closePositionPartial(posId, 5000);

        // 4. Verification steps
        uint256 internalBalanceAfter = trading.getCollateralBalance(user);
        uint256 walletBalanceAfter = usdt.balanceOf(user);

        uint256 receivedCollateral = internalBalanceAfter - internalBalanceBefore;
        uint256 receivedProfit = walletBalanceAfter - walletBalanceBefore;

        console.log("Internal Collateral Received:", receivedCollateral);
        console.log("Wallet Profit Received:", receivedProfit);

        // Fee is ~0.1% of $55 = $0.055.
        // Logic: Fee is deducted from Collateral first.
        // FeeFromCollateral = $0.055.
        // Returned Collateral = $50 - $0.055 = $49.945.
        // Profit Paid = $5 (Full).

        // Check Collateral Return (~$49.945)
        assertGt(receivedCollateral, 49 * 1e18);
        assertLt(receivedCollateral, 50 * 1e18);

        // Check Profit Return ($5)
        assertEq(receivedProfit, 5 * 1e18);

        // Check Remaining Position
        ICountryTrading.Position memory pos = trading.getPosition(user, posId);

        // Remaining Collateral should be $50
        assertEq(pos.collateralAmount, 50 * 1e18);

        // Remaining Size should be $50
        assertEq(pos.positionSize, 50 * 1e18);

        // Entry Price MUST remain $2,000
        assertEq(pos.entryPrice, 2000 * 1e18);

        vm.stopPrank();
    }

    function test_PartialClose_Loss() public {
        vm.startPrank(user);

        // 1. Open Long Position: $100 Collateral
        // Entry Price: $2,000
        uint256 collateral = 100 * 1e18;
        uint256 posId = trading.openLongPosition(countryCode, collateral);

        // 2. Price Decreases by 20% -> $1,600
        // Loss should be 20% of Size ($100) = -$20 (Unrealized)
        ethFeed.updatePrice(1600 * 1e8);

        // Record balance before close
        uint256 balanceBefore = trading.getCollateralBalance(user);

        // 3. Partial Close 50% (5000 bps) (Cut Loss)
        // User should Realize 50% of Loss = -$10
        // Portion of Collateral to close: $50
        // Less Realized Loss: -$10
        // Net Return: $40
        // Less Fee: ~$0.04
        // Final to User: ~$39.96
        trading.closePositionPartial(posId, 5000);

        uint256 balanceAfter = trading.getCollateralBalance(user);
        uint256 received = balanceAfter - balanceBefore;

        console.log("Received after partial cut loss:", received);

        assertGt(received, 39 * 1e18);
        assertLt(received, 40 * 1e18);

        // Check Remaining Position
        ICountryTrading.Position memory pos = trading.getPosition(user, posId);

        // Remaining Collateral should be $50
        assertEq(pos.collateralAmount, 50 * 1e18);

        // Remaining Size should be $50
        assertEq(pos.positionSize, 50 * 1e18);

        vm.stopPrank();
    }
}

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
