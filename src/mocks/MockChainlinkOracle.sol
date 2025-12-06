// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title MockChainlinkOracle
 * @notice Mock Chainlink price feed untuk testing di Mantle Testnet
 * @dev Hanya untuk testing! Jangan gunakan di production
 */
contract MockChainlinkOracle is AggregatorV3Interface {
    uint8 public constant override decimals = 8;
    string public constant override description = "Mock Price Feed";
    uint256 public constant override version = 0;

    int256 private price;
    uint256 private updatedAt;
    uint80 private currentRoundId;

    constructor(int256 _initialPrice) {
        price = _initialPrice;
        updatedAt = block.timestamp;
        currentRoundId = 1;
    }

    /**
     * @notice Update price (public untuk testing)
     * @param _newPrice New price in 8 decimals (e.g., 3000 * 10^8 for $3000)
     */
    function updatePrice(int256 _newPrice) external {
        require(_newPrice > 0, "MockChainlinkOracle: Price must be positive");
        price = _newPrice;
        updatedAt = block.timestamp;
        currentRoundId++;
    }

    function getRoundData(
        uint80 /* _roundId */
    )
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt_, uint80 answeredInRound)
    {
        return (currentRoundId, price, block.timestamp, updatedAt, currentRoundId);
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt_, uint80 answeredInRound)
    {
        return (currentRoundId, price, block.timestamp, updatedAt, currentRoundId);
    }
}

