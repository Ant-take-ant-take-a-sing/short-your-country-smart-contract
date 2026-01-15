// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ICountryRegistry} from "./interfaces/ICountryRegistry.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title CountryRegistry
 * @notice Manages country tokens and their Chainlink price feeds
 * @dev This contract allows adding/removing countries and fetching prices
 */
contract CountryRegistry is ICountryRegistry, Ownable {
    mapping(bytes32 => Country) private countries;
    bytes32[] private countryCodes;

    constructor() Ownable(msg.sender) {}

    /**
     * @notice Add a new country with its price feed
     * @param countryCode Country code (e.g., keccak256("US"), keccak256("ID"))
     * @param name Country name
     * @param priceFeed Address of Chainlink price feed
     *
     * PLACEHOLDER: Add your countries here by calling this function
     * Example countries you might want to add:
     * - US (United States)
     * - ID (Indonesia)
     * - SG (Singapore)
     * - JP (Japan)
     * - etc.
     */
    function addCountry(bytes32 countryCode, string memory name, address priceFeed) external onlyOwner {
        require(countryCode != bytes32(0), "CountryRegistry: Invalid country code");
        require(priceFeed != address(0), "CountryRegistry: Invalid price feed");
        require(!countries[countryCode].isActive, "CountryRegistry: Country already exists");

        // Verify price feed is valid
        AggregatorV3Interface feed = AggregatorV3Interface(priceFeed);
        try feed.decimals() returns (uint8) {}
        catch {
            revert("CountryRegistry: Invalid price feed contract");
        }

        countries[countryCode] = Country({countryCode: countryCode, name: name, priceFeed: priceFeed, isActive: true});

        countryCodes.push(countryCode);
        emit CountryAdded(countryCode, name, priceFeed);
    }

    /**
     * @notice Remove a country (deactivate it)
     * @param countryCode Country code to remove
     */
    function removeCountry(bytes32 countryCode) external onlyOwner {
        require(countries[countryCode].isActive, "CountryRegistry: Country does not exist");
        countries[countryCode].isActive = false;
        emit CountryRemoved(countryCode);
    }

    /**
     * @notice Update price feed for a country
     * @param countryCode Country code
     * @param newPriceFeed New price feed address
     */
    function updateCountryPriceFeed(bytes32 countryCode, address newPriceFeed) external onlyOwner {
        require(countries[countryCode].isActive, "CountryRegistry: Country does not exist");
        require(newPriceFeed != address(0), "CountryRegistry: Invalid price feed");

        // Verify price feed is valid
        AggregatorV3Interface feed = AggregatorV3Interface(newPriceFeed);
        try feed.decimals() returns (uint8) {}
        catch {
            revert("CountryRegistry: Invalid price feed contract");
        }

        countries[countryCode].priceFeed = newPriceFeed;
        emit CountryUpdated(countryCode, newPriceFeed);
    }

    /**
     * @notice Get country information
     * @param countryCode Country code
     * @return Country struct
     */
    function getCountry(bytes32 countryCode) external view returns (Country memory) {
        return countries[countryCode];
    }

    /**
     * @notice Check if country is active
     * @param countryCode Country code
     * @return Whether country is active
     */
    function isCountryActive(bytes32 countryCode) external view returns (bool) {
        return countries[countryCode].isActive;
    }

    /**
     * @notice Get current price for a country from Chainlink
     * @param countryCode Country code
     * @return price Current price (scaled by 10^8 for Chainlink feeds)
     * @return timestamp Last update timestamp
     */
    function getCountryPrice(bytes32 countryCode) external view returns (uint256 price, uint256 timestamp) {
        require(countries[countryCode].isActive, "CountryRegistry: Country does not exist");

        AggregatorV3Interface priceFeed = AggregatorV3Interface(countries[countryCode].priceFeed);
        (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) = priceFeed.latestRoundData();

        require(answer > 0, "CountryRegistry: Invalid price");
        require(updatedAt > 0, "CountryRegistry: Price feed not updated");
        require(answeredInRound >= roundId, "CountryRegistry: Incomplete round");

        // Check price staleness (max 1 hour old)
        uint256 maxStaleness = 3600; // 1 hour in seconds
        require(block.timestamp - updatedAt <= maxStaleness, "CountryRegistry: Price feed stale");

        // Chainlink prices are typically in 8 decimals, we'll scale to 18 decimals
        price = uint256(answer) * 1e10; // Scale from 8 to 18 decimals
        timestamp = updatedAt;
    }

    /**
     * @notice Get all registered countries
     * @return Array of all countries
     */
    function getAllCountries() external view returns (Country[] memory) {
        Country[] memory activeCountries = new Country[](countryCodes.length);
        uint256 count = 0;

        for (uint256 i = 0; i < countryCodes.length; i++) {
            if (countries[countryCodes[i]].isActive) {
                activeCountries[count] = countries[countryCodes[i]];
                count++;
            }
        }

        // Resize array
        assembly {
            mstore(activeCountries, count)
        }

        return activeCountries;
    }
}
