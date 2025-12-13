// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockUSDC
 * @notice Mock USDC token untuk testing di Mantle Testnet
 * @dev Uses 6 decimals (sama seperti USDC asli)
 */
contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "mUSDC") {
        // Mint 10,000,000 tokens (10M) dengan 6 decimals
        _mint(msg.sender, 10_000_000 * 10 ** 6);
    }

    /**
     * @notice Override decimals to 6 (USDC standard)
     */
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /**
     * @notice Mint additional tokens (untuk testing)
     * @param to Address to mint to
     * @param amount Amount to mint (in 6 decimals)
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title DeployMockUSDC
 * @notice Script untuk deploy Mock USDC di Mantle Testnet
 * @dev Recommended untuk testing karena menggunakan 6 decimals seperti USDC asli
 */
contract DeployMockUSDC is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        MockUSDC mockUSDC = new MockUSDC();

        console.log("\n=== Mock USDC Deployment ===");
        console.log("Mock USDC Address:", address(mockUSDC));
        console.log("Decimals: 6 (same as real USDC)");
        console.log("Deployer Balance:", mockUSDC.balanceOf(msg.sender) / 1e6, "mUSDC");
        console.log("\nUpdate .env with:");
        console.log("COLLATERAL_TOKEN_ADDRESS=", address(mockUSDC));
        console.log("\nOr for Mantle Mainnet, use real USDC:");
        console.log("COLLATERAL_TOKEN_ADDRESS=0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9");

        vm.stopBroadcast();
    }
}

