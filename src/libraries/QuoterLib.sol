//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {IQuoter} from "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";
import "../interfaces/IContangoView.sol";
import "../ContangoPositionNFT.sol";
import "./StorageDataTypes.sol";

library QuoterLib {
    function spot(IQuoter quoter, address base, address quote, int256 baseAmount, uint24 uniswapFee)
        internal
        returns (uint256)
    {
        if (baseAmount > 0) {
            return quoter.quoteExactInputSingle({
                tokenIn: base,
                tokenOut: quote,
                fee: uniswapFee,
                amountIn: uint256(baseAmount),
                sqrtPriceLimitX96: 0
            });
        } else {
            return quoter.quoteExactOutputSingle({
                tokenIn: quote,
                tokenOut: base,
                fee: uniswapFee,
                amountOut: uint256(-baseAmount),
                sqrtPriceLimitX96: 0
            });
        }
    }

    function fee(
        IContangoView contango,
        ContangoPositionNFT positionNFT,
        PositionId positionId,
        Symbol symbol,
        uint256 cost
    ) internal view returns (uint256) {
        address trader = PositionId.unwrap(positionId) == 0 ? msg.sender : positionNFT.positionOwner(positionId);
        IFeeModel feeModel = contango.feeModel(symbol);
        return address(feeModel) != address(0) ? feeModel.calculateFee(trader, positionId, cost) : 0;
    }
}
