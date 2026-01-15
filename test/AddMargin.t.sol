// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/CountryTrading.sol";
import "../src/CountryRegistry.sol";
import "../src/LiquidityPool.sol";
import "forge-std/console.sol";

// Mock ERC20
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDT is ERC20 {
    constructor() ERC20("Mock USDT", "USDT") {
        _mint(msg.sender, 1_000_000 * 1e18);
    }
}

contract MockAggregator {
    function decimals() external pure returns (uint8) {
        return 8;
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (0, 100 * 1e8, 0, block.timestamp, 0); // Price 100 USD (8 decimals)
    }
}

contract AddMarginTest is Test {
    CountryTrading trading;
    CountryRegistry registry;
    LiquidityPool pool;
    MockUSDT usdt;
    MockAggregator oracle;

    address user = address(0x123);
    bytes32 constant ID = keccak256("ID");

    function setUp() public {
        usdt = new MockUSDT();
        registry = new CountryRegistry();
        pool = new LiquidityPool(address(usdt));
        trading = new CountryTrading(address(usdt), address(registry), address(pool));
        oracle = new MockAggregator();

        pool.setTradingContract(address(trading));
        registry.addCountry(ID, "Test Country", address(oracle));

        usdt.transfer(user, 1000 * 1e18);

        vm.prank(user);
        usdt.approve(address(trading), type(uint256).max);
    }

    function test_IncreaseCollateral() public {
        vm.startPrank(user);
        trading.deposit(500 * 1e18); // Deposit sufficient collateral first
        uint256 posId = trading.openLongPosition(ID, 100 * 1e18);

        uint256 initialCollateral = trading.getCollateralBalance(user);

        // 2. Increase Collateral (+50)
        // Note: Initial approval was infinite, so no need to approve again unless simulation context changed

        trading.increaseCollateral(posId, 50 * 1e18);

        // 3. Verify Position
        ICountryTrading.Position memory pos = trading.getPosition(user, posId);
        assertEq(pos.collateralAmount, 150 * 1e18);

        // 4. Verify Balance
        uint256 newCollateral = trading.getCollateralBalance(user);
        assertEq(newCollateral, initialCollateral + 50 * 1e18);

        vm.stopPrank();
    }

    function test_CannotIncreaseCollateralForInvalidPosition() public {
        vm.startPrank(user);
        vm.expectRevert(bytes("CountryTrading: Position does not exist"));
        trading.increaseCollateral(999, 50 * 1e18);
        vm.stopPrank();
    }
}
