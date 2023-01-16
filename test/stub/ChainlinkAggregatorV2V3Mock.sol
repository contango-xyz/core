//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "solmate/src/tokens/ERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";

contract ChainlinkAggregatorV2V3Mock is AggregatorV2V3Interface {
    event PriceSet(int256 price, uint8 decimals, int256 priceParameter, uint8 priceDecimals, uint256 timestamp);

    uint8 public immutable override decimals;
    uint8 public immutable priceDecimals;
    int256 public price;
    uint256 public timestamp;

    constructor(uint8 _decimals, uint8 _priceDecimals) {
        decimals = _decimals;
        priceDecimals = _priceDecimals;
    }

    function set(int256 _price) external returns (ChainlinkAggregatorV2V3Mock) {
        if (priceDecimals > decimals) {
            price = _price / int256(10 ** (priceDecimals - decimals));
        } else if (decimals > priceDecimals) {
            price = _price * int256(10 ** (decimals - priceDecimals));
        } else {
            price = _price;
        }
        timestamp = block.timestamp;

        emit PriceSet({
            price: price,
            decimals: decimals,
            priceParameter: _price,
            priceDecimals: priceDecimals,
            timestamp: timestamp
        });

        return ChainlinkAggregatorV2V3Mock(address(this));
    }

    // V3

    function description() external pure override returns (string memory) {
        return "ChainlinkAggregatorV2V3Mock";
    }

    function version() external pure override returns (uint256) {
        return 3;
    }

    function getRoundData(uint80 _roundId)
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, price, 0, timestamp, 0);
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (0, price, 0, timestamp, 0);
    }

    // V2

    function latestAnswer() external view override returns (int256) {
        return price;
    }

    function latestTimestamp() external view override returns (uint256) {
        return timestamp;
    }

    function latestRound() external pure override returns (uint256) {
        return 0;
    }

    function getAnswer(uint256) external view override returns (int256) {
        return price;
    }

    function getTimestamp(uint256) external view override returns (uint256) {
        return timestamp;
    }
}
