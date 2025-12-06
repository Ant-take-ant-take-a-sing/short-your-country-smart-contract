// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {CountryRegistry} from "../src/CountryRegistry.sol";

/**
 * @title AddCountriesScript
 * @notice Script to add countries to CountryRegistry
 *
 * PLACEHOLDER: Add your countries here
 *
 * Usage:
 * forge script script/AddCountries.s.sol:AddCountriesScript --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
 */
contract AddCountriesScript is Script {
    function run() external {
        // Load from .env file
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address registryAddress = vm.envAddress("COUNTRY_REGISTRY_ADDRESS");

        CountryRegistry registry = CountryRegistry(registryAddress);

        vm.startBroadcast(deployerPrivateKey);

        // PLACEHOLDER: Add your countries here
        // Format: registry.addCountry(keccak256("COUNTRY_CODE"), "Country Name", priceFeedAddress);
        // Price feed addresses should be loaded from .env file or set as variables

        // Example: Load price feeds from .env
        // address usPriceFeed = vm.envAddress("US_PRICE_FEED");
        // address idPriceFeed = vm.envAddress("ID_PRICE_FEED");
        // address sgPriceFeed = vm.envAddress("SG_PRICE_FEED");

        // Example: United States
        // registry.addCountry(
        //     keccak256("US"),
        //     "United States",
        //     usPriceFeed
        // );

        // Example: Indonesia
        // registry.addCountry(
        //     keccak256("ID"),
        //     "Indonesia",
        //     idPriceFeed
        // );

        // Example: Singapore
        // registry.addCountry(
        //     keccak256("SG"),
        //     "Singapore",
        //     sgPriceFeed
        // );

        console.log("Countries added successfully!");
        console.log("CountryRegistry:", address(registry));

        vm.stopBroadcast();
    }
}

