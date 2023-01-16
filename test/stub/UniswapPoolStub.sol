//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "solmate/src/utils/SafeTransferLib.sol";
import "solmate/src/tokens/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "../../src/dependencies/Uniswap.sol";

contract UniswapPoolStub {
    using SafeTransferLib for ERC20;

    event UniswapPoolStubCreated(
        ERC20 token0,
        ERC20 token1,
        AggregatorV3Interface token0Oracle,
        AggregatorV3Interface token1Oracle,
        bool token0Quoted,
        int256 absoluteSpread
    );

    error MissingRepayment(uint256 expected, uint256 actual, int256 diff);

    ERC20 public immutable token0;
    ERC20 public immutable token1;
    AggregatorV3Interface public immutable token0Oracle;
    AggregatorV3Interface public immutable token1Oracle;
    bool public immutable token0Quoted;
    int256 public immutable absoluteSpread;

    constructor(
        ERC20 _token0,
        ERC20 _token1,
        AggregatorV3Interface _token0Oracle,
        AggregatorV3Interface _token1Oracle,
        bool _token0Quoted,
        int256 _absoluteSpread
    ) {
        token0 = _token0;
        token1 = _token1;
        token0Oracle = _token0Oracle;
        token1Oracle = _token1Oracle;
        token0Quoted = _token0Quoted;
        absoluteSpread = _absoluteSpread;

        emit UniswapPoolStubCreated(token0, token1, token0Oracle, token1Oracle, token0Quoted, absoluteSpread);
    }

    function swap(address recipient, bool zeroForOne, int256 amountSpecified, uint160, bytes calldata data)
        external
        returns (int256 amount0, int256 amount1)
    {
        bool oneForZero = !zeroForOne;
        bool exactInput = amountSpecified > 0;
        bool exactOutput = amountSpecified < 0;

        int256 token0Precision = int256(10 ** token0.decimals());
        int256 token1Precision = int256(10 ** token1.decimals());

        int256 oraclePrice = peek();
        int256 price;
        if (token0Quoted) {
            price = zeroForOne ? oraclePrice + absoluteSpread : oraclePrice - absoluteSpread;
        } else {
            price = zeroForOne ? oraclePrice - absoluteSpread : oraclePrice + absoluteSpread;
        }

        // swap exact input token0 for token1
        // swap token1 for exact output token0
        if ((zeroForOne && exactInput) || (oneForZero && exactOutput)) {
            amount0 = amountSpecified;

            if (token0Quoted) {
                // amountSpecified: token0 precision
                // price: token0 precision
                // amount1: token1 precision
                amount1 = (-amountSpecified * token1Precision) / price;
            } else {
                // amountSpecified: token0 precision
                // price: token1 precision
                // amount1: token1 precision
                amount1 = (-amountSpecified * price) / token0Precision;
            }
        }

        // swap token0 for exact output token1
        // swap exact input token1 for token0
        if ((zeroForOne && exactOutput) || (oneForZero && exactInput)) {
            if (token0Quoted) {
                // amountSpecified: token1 precision
                // price: token0 precision
                // amount0: token0 precision
                amount0 = (-amountSpecified * price) / token1Precision;
            } else {
                // amountSpecified: token1 precision
                // price: token1 precision
                // amount0: token0 precision
                amount0 = (-amountSpecified * token0Precision) / price;
            }

            amount1 = amountSpecified; // amountSpecified in token1 precision
        }

        if (amount0 < 0) {
            token0.safeTransfer(recipient, uint256(-amount0));
            uint256 expected = token1.balanceOf(address(this)) + uint256(amount1);
            IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amount0, amount1, data);
            uint256 actual = token1.balanceOf(address(this));
            if (actual < expected) {
                revert MissingRepayment(expected, actual, int256(expected) - int256(actual));
            }
        } else {
            token1.safeTransfer(recipient, uint256(-amount1));
            uint256 expected = token0.balanceOf(address(this)) + uint256(amount0);
            IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amount0, amount1, data);
            uint256 actual = token0.balanceOf(address(this));
            if (actual < expected) {
                revert MissingRepayment(expected, actual, int256(expected) - int256(actual));
            }
        }
    }

    function peek() internal view returns (int256 price) {
        AggregatorV3Interface baseOracle = token0Quoted ? token1Oracle : token0Oracle;
        AggregatorV3Interface quoteOracle = token0Quoted ? token0Oracle : token1Oracle;

        int256 baseOraclePrecision = int256(10 ** baseOracle.decimals());
        int256 quoteOraclePrecision = int256(10 ** quoteOracle.decimals());

        (, int256 basePrice,,,) = baseOracle.latestRoundData();
        (, int256 quotePrice,,,) = quoteOracle.latestRoundData();

        address quote = address(token0Quoted ? token0 : token1);
        int256 quotePrecision = int256(10 ** ERC20(quote).decimals());

        price = (basePrice * quoteOraclePrecision * quotePrecision) / (quotePrice * baseOraclePrecision);
    }
}
