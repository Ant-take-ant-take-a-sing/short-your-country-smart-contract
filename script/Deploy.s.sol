// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {CountryRegistry} from "../src/CountryRegistry.sol";
import {CountryTrading} from "../src/CountryTrading.sol";
import {LiquidityPool} from "../src/LiquidityPool.sol";

/**
 * @title DeployScript
 * @notice Script to deploy CountryRegistry and CountryTrading contracts
 *
 * Usage:
 * forge script script/Deploy.s.sol:DeployScript --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
 */
contract DeployScript is Script {
    function run() external {
        // Load from .env file
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Support both USDT_ADDRESS (legacy) and COLLATERAL_TOKEN_ADDRESS
        address collateralToken;
        try vm.envAddress("COLLATERAL_TOKEN_ADDRESS") returns (address addr) {
            collateralToken = addr;
        } catch {
            // Fallback to USDT_ADDRESS for backward compatibility
            collateralToken = vm.envAddress("USDT_ADDRESS");
        }

        vm.startBroadcast(deployerPrivateKey);

        // Deploy CountryRegistry
        CountryRegistry registry = new CountryRegistry();
        console.log("CountryRegistry deployed at:", address(registry));

        // Deploy LiquidityPool
        LiquidityPool pool = new LiquidityPool(collateralToken);
        console.log("LiquidityPool deployed at:", address(pool));

        // Deploy CountryTrading
        CountryTrading trading = new CountryTrading(collateralToken, address(registry), address(pool));
        console.log("CountryTrading deployed at:", address(trading));

        // Set trading contract in pool (authorized caller)
        pool.setTradingContract(address(trading));
        console.log("LiquidityPool trading contract set to CountryTrading");

        vm.stopBroadcast();

        // Print deployment info
        console.log("\n=== Deployment Summary ===");
        console.log("CountryRegistry:", address(registry));
        console.log("LiquidityPool:", address(pool));
        console.log("CountryTrading:", address(trading));
        console.log("Collateral Token Address:", collateralToken);
        console.log("\nNext steps:");
        console.log("1. Deposit liquidity to LiquidityPool");
        console.log("2. Add countries to CountryRegistry using addCountry()");
        console.log("3. Approve collateral token spending for CountryTrading contract");
        console.log("4. Start trading!");
    }
}
