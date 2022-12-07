//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "../../src/libraries/SignedMathLib.sol";
import "../../src/dependencies/Uniswap.sol";

contract UniswapPoolStub {
    using SafeERC20 for IERC20;
    using SignedMathLib for int256;

    event UniswapPoolStubCreated(
        IERC20 token0, IERC20 token1, AggregatorV3Interface oracle, bool token0QuotedOracle, int256 absoluteSpread
    );

    error MissingRepayment(uint256 expected, uint256 actual, int256 diff);

    IERC20 public immutable token0;
    IERC20 public immutable token1;
    AggregatorV3Interface public immutable oracle;
    bool public immutable token0QuotedOracle;
    int256 public immutable absoluteSpread;

    constructor(
        IERC20 _token0,
        IERC20 _token1,
        AggregatorV3Interface _oracle,
        bool _token0QuotedOracle,
        int256 _absoluteSpread
    ) {
        token0 = _token0;
        token1 = _token1;
        oracle = _oracle;
        token0QuotedOracle = _token0QuotedOracle;
        absoluteSpread = _absoluteSpread;

        emit UniswapPoolStubCreated(token0, token1, oracle, token0QuotedOracle, absoluteSpread);
    }

    function swap(address recipient, bool zeroForOne, int256 amountSpecified, uint160, bytes calldata data)
        external
        returns (int256 amount0, int256 amount1)
    {
        bool exactInput = amountSpecified > 0;

        uint256 token0Dec = IERC20Metadata(address(token0)).decimals();
        uint256 token1Dec = IERC20Metadata(address(token1)).decimals();

        int256 price;
        if (token0QuotedOracle) {
            price = zeroForOne ? peek() + absoluteSpread : peek() - absoluteSpread;
        } else {
            price = zeroForOne ? peek() - absoluteSpread : peek() + absoluteSpread;
        }

        // swap exact input token0 for token1
        // swap token1 for exact output token0
        if ((zeroForOne && exactInput) || !(zeroForOne && !exactInput)) {
            amount0 = amountSpecified; // amountSpecified in token0 precision

            if (token0QuotedOracle) {
                amount1 = (-amountSpecified * int256(10 ** token1Dec)) / price;
            } else {
                // this needs to be at token1 precision
                uint256 decOffset = token1Dec + Math.max(token0Dec, token1Dec) - Math.min(token0Dec, token1Dec);
                amount1 = (-amountSpecified * price) / int256(10 ** decOffset);
            }
        }

        // swap token0 for exact output token1
        // swap exact input token1 for token0
        if ((zeroForOne && !exactInput) || (!zeroForOne && exactInput)) {
            if (token0QuotedOracle) {
                // this needs to be at token0 precision
                uint256 decOffset = token0Dec + Math.max(token0Dec, token1Dec) - Math.min(token0Dec, token1Dec);
                amount0 = (-amountSpecified * price) / int256(10 ** decOffset);
            } else {
                amount0 = (-amountSpecified * int256(10 ** token0Dec)) / price;
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
        uint256 oracleDec = oracle.decimals();

        address quote = address(token0QuotedOracle ? token0 : token1);
        uint256 quoteDec = IERC20Metadata(quote).decimals();

        (, price,,,) = oracle.latestRoundData();
        if (oracleDec > quoteDec) {
            price = price / int256(10 ** (oracleDec - quoteDec));
        } else if (oracleDec < quoteDec) {
            price = price * int256(10 ** (quoteDec - oracleDec));
        }
    }
}
