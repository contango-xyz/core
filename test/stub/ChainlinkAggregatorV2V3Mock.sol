//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";

contract ChainlinkAggregatorV2V3Mock is AggregatorV2V3Interface {
    uint8 public immutable override decimals;
    uint8 public immutable tokenDecimals;
    int256 public price;
    uint256 public timestamp;

    constructor(uint8 _decimals, IERC20Metadata token) {
        decimals = _decimals;
        tokenDecimals = token.decimals();
    }

    function set(int256 _price) external {
        if (tokenDecimals > decimals) {
            price = _price / int256(10 ** (tokenDecimals - decimals));
        } else if (decimals > tokenDecimals) {
            price = _price * int256(10 ** (decimals - tokenDecimals));
        } else {
            price = _price;
        }
        timestamp = block.timestamp;
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
