// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title ICountryRegistry
 * @notice Interface for Country Registry Contract
 */
interface ICountryRegistry {
    struct Country {
        bytes32 countryCode;
        string name;
        address priceFeed;
        bool isActive;
    }

    event CountryAdded(bytes32 indexed countryCode, string name, address priceFeed);
    event CountryRemoved(bytes32 indexed countryCode);
    event CountryUpdated(bytes32 indexed countryCode, address newPriceFeed);

    function addCountry(bytes32 countryCode, string memory name, address priceFeed) external;
    function removeCountry(bytes32 countryCode) external;
    function updateCountryPriceFeed(bytes32 countryCode, address newPriceFeed) external;
    function getCountry(bytes32 countryCode) external view returns (Country memory);
    function isCountryActive(bytes32 countryCode) external view returns (bool);
    function getCountryPrice(bytes32 countryCode) external view returns (uint256 price, uint256 timestamp);
    function getAllCountries() external view returns (Country[] memory);
}

