// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockUSDT
 * @notice Mock USDT token untuk testing di Mantle Testnet
 */
contract MockUSDT is ERC20 {
    constructor() ERC20("Mock USDT", "mUSDT") {
        // Mint 10,000,000 tokens (10M) untuk deployer
        _mint(msg.sender, 10_000_000 * 10 ** 18);
    }

    /**
     * @notice Mint additional tokens (untuk testing)
     * @param to Address to mint to
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title DeployMockUSDT
 * @notice Script untuk deploy Mock USDT di Mantle Testnet
 */
contract DeployMockUSDT is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        MockUSDT mockUSDT = new MockUSDT();

        console.log("\n=== Mock USDT Deployment ===");
        console.log("Mock USDT Address:", address(mockUSDT));
        console.log("Deployer Balance:", mockUSDT.balanceOf(msg.sender) / 1e18, "mUSDT");
        console.log("\nUpdate .env with:");
        console.log("USDT_ADDRESS=", address(mockUSDT));

        vm.stopBroadcast();
    }
}

