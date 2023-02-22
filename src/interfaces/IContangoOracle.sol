// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "src/libraries/DataTypes.sol";

interface IContangoOracle {
    function closingCost(PositionId positionId, uint24 uniswapFee, uint32 uniswapPeriod)
        external
        returns (uint256 cost);
}
