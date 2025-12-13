// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {CountryRegistry} from "../src/CountryRegistry.sol";
import {ICountryRegistry} from "../src/interfaces/ICountryRegistry.sol";
import {MockChainlinkOracle} from "../src/mocks/MockChainlinkOracle.sol";

/**
 * @title CountryRegistryTest
 * @notice Tests for CountryRegistry contract
 */
contract CountryRegistryTest is Test {
    CountryRegistry public registry;
    MockChainlinkOracle public priceFeed;

    address public owner = address(this);
    address public nonOwner = address(0x1);

    bytes32 public constant US_CODE = keccak256("US");
    bytes32 public constant ID_CODE = keccak256("ID");

    function setUp() public {
        registry = new CountryRegistry();
        priceFeed = new MockChainlinkOracle(3000 * 10 ** 8); // $3000
    }

    function test_AddCountry() public {
        registry.addCountry(US_CODE, "United States", address(priceFeed));

        assertTrue(registry.isCountryActive(US_CODE));

        (uint256 price, uint256 timestamp) = registry.getCountryPrice(US_CODE);
        assertGt(price, 0);
        assertGt(timestamp, 0);
    }

    function test_Revert_AddCountryAsNonOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert();
        registry.addCountry(US_CODE, "United States", address(priceFeed));
    }

    function test_Revert_AddCountryWithZeroAddress() public {
        vm.expectRevert("CountryRegistry: Invalid price feed");
        registry.addCountry(US_CODE, "United States", address(0));
    }

    function test_RemoveCountry() public {
        registry.addCountry(US_CODE, "United States", address(priceFeed));
        registry.removeCountry(US_CODE);

        assertFalse(registry.isCountryActive(US_CODE));
    }

    function test_UpdateCountryPriceFeed() public {
        registry.addCountry(US_CODE, "United States", address(priceFeed));

        MockChainlinkOracle newPriceFeed = new MockChainlinkOracle(3500 * 10 ** 8);
        registry.updateCountryPriceFeed(US_CODE, address(newPriceFeed));

        assertTrue(registry.isCountryActive(US_CODE));
    }

    function test_GetAllCountries() public {
        registry.addCountry(US_CODE, "United States", address(priceFeed));

        MockChainlinkOracle idPriceFeed = new MockChainlinkOracle(15000 * 10 ** 8);
        registry.addCountry(ID_CODE, "Indonesia", address(idPriceFeed));

        ICountryRegistry.Country[] memory countries = registry.getAllCountries();

        assertEq(countries.length, 2);
    }
}

