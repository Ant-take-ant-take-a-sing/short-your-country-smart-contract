// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MockChainlinkOracle} from "../src/mocks/MockChainlinkOracle.sol";

/**
 * @title DeployMockOracle
 * @notice Script untuk deploy Mock Chainlink Oracle di Mantle Testnet
 *
 * Usage:
 * forge script script/DeployMockOracle.s.sol:DeployMockOracle --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
 */
contract DeployMockOracle is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy mock oracles dengan initial prices
        // Prices dalam 8 decimals (Chainlink format)
        // Contoh: $3000 = 3000 * 10^8 = 300000000000

        // US Price Feed (contoh: $3000)
        int256 usPrice = 3000 * 10 ** 8;
        MockChainlinkOracle usOracle = new MockChainlinkOracle(usPrice);

        // ID Price Feed (contoh: $15000 untuk IDR/USD, atau bisa disesuaikan)
        int256 idPrice = 15000 * 10 ** 8;
        MockChainlinkOracle idOracle = new MockChainlinkOracle(idPrice);

        // SG Price Feed (contoh: $1350 untuk SGD/USD)
        int256 sgPrice = 1350 * 10 ** 8;
        MockChainlinkOracle sgOracle = new MockChainlinkOracle(sgPrice);

        console.log("\n=== Mock Oracle Deployment ===");
        console.log("US Price Feed (Mock):", address(usOracle));
        console.log("  Initial Price: $3000");
        console.log("ID Price Feed (Mock):", address(idOracle));
        console.log("  Initial Price: $15000");
        console.log("SG Price Feed (Mock):", address(sgOracle));
        console.log("  Initial Price: $1350");
        console.log("\nUpdate .env with:");
        console.log("US_PRICE_FEED=", address(usOracle));
        console.log("ID_PRICE_FEED=", address(idOracle));
        console.log("SG_PRICE_FEED=", address(sgOracle));
        console.log("\nTo update prices later, use:");
        console.log(
            "cast send",
            address(usOracle),
            '"updatePrice(int256)" <price_in_8_decimals> --rpc-url $RPC_URL --private-key $PRIVATE_KEY'
        );

        vm.stopBroadcast();
    }
}

