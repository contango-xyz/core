//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "src/interfaces/IContangoOracle.sol";
import "src/interfaces/IContango.sol";
import "src/interfaces/IContangoQuoter.sol";

contract IContangoOracleStub is IContangoOracle {
    IContango public immutable contango;
    IContangoQuoter public immutable quoter;

    constructor(IContango _contango, IContangoQuoter _quoter) {
        contango = _contango;
        quoter = _quoter;
    }

    function closingCost(PositionId positionId, uint24 uniswapFee, uint32 /* uniswapPeriod */ )
        external
        override
        returns (uint256 cost)
    {
        Position memory position = contango.position(positionId);

        ModifyCostResult memory result = quoter.modifyCostForPositionWithLeverage(
            ModifyCostParams(positionId, -int256(position.openQuantity), 0, uniswapFee), 0
        );

        cost = uint256(result.cost);
    }
}
