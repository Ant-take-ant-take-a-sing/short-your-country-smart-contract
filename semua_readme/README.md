# Test Files

## Overview

Test files untuk semua contract utama di project Country Trading.

## Test Files

### 1. `CountryTrading.t.sol`
Test untuk main trading contract. Mencakup:
- ✅ Deposit & Withdraw
- ✅ Open Long/Short Position
- ✅ Close Position
- ✅ Liquidation
- ✅ Error cases (revert tests)
- ✅ Helper functions (getPositionPnL, getProtocolMetrics)
- ✅ Edge cases

### 2. `CountryRegistry.t.sol`
Test untuk country registry contract. Mencakup:
- ✅ Add Country
- ✅ Remove Country
- ✅ Update Price Feed
- ✅ Get Country Price
- ✅ Get All Countries
- ✅ Access control (onlyOwner)

### 3. `TradingMath.t.sol`
Test untuk TradingMath library. Mencakup:
- ✅ P&L Calculation (Long/Short, Profit/Loss)
- ✅ Fee Calculation
- ✅ Position Value Calculation
- ✅ Liquidation Check

## Running Tests

### Run all tests:
```bash
forge test
```

### Run specific test file:
```bash
forge test --match-path test/CountryTrading.t.sol
```

### Run with verbosity:
```bash
forge test -vvv
```

### Run specific test function:
```bash
forge test --match-test test_Deposit
```

## Test Coverage

Untuk melihat test coverage:
```bash
forge coverage
```

## Adding More Tests

Saat menambah fitur baru, pastikan untuk:
1. ✅ Test happy path (normal flow)
2. ✅ Test error cases (revert scenarios)
3. ✅ Test edge cases (boundary conditions)
4. ✅ Test access control (onlyOwner, etc.)

## Mock Contracts

Test menggunakan mock contracts:
- `MockERC20` - Mock token untuk testing
- `MockChainlinkOracle` - Mock Chainlink price feed

## Notes

- Semua test menggunakan Foundry's `Test` contract
- Mock contracts ada di `src/mocks/` dan `test/`
- Test menggunakan `vm.prank()` untuk simulate different users

