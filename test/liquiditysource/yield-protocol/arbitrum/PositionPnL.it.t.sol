//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./WithYieldFixtures.sol";
import "src/dependencies/Uniswap.sol";

contract YieldArbitrumPnLUSDC2309Test is
    WithYieldFixtures(constants.yETHUSDC2309, constants.FYETH2309, constants.FYUSDC2309)
{
    using SignedMath for int256;
    using SafeCast for int256;
    using YieldUtils for PositionId;

    function setUp() public override {
        super.setUp();
        stubPrice({_base: WETH9, _quote: USDC, baseUsdPrice: 1000e6, quoteUsdPrice: 1e6, uniswapFee: uniswapFee});
    }

    function testOpenAndCloseProfitableLongUSDC() public {
        (PositionId positionId,) = _openPosition(2 ether);

        // Move the market
        skip(4.5 days);
        poolOracle.updatePool(instrument.basePool);
        skip(0.5 days);
        stubPrice({_base: WETH9, _quote: USDC, baseUsdPrice: 1500e6, quoteUsdPrice: 1e6, uniswapFee: uniswapFee});

        // Close position
        _closePosition(positionId);
    }

    function testOpenAndCloseLossMakingLongUSDC() public {
        (PositionId positionId,) = _openPosition(2 ether);

        // Move the market
        skip(4.5 days);
        poolOracle.updatePool(instrument.basePool);
        skip(0.5 days);
        stubPrice({_base: WETH9, _quote: USDC, baseUsdPrice: 960e6, quoteUsdPrice: 1e6, uniswapFee: uniswapFee});

        // Close position
        _closePosition(positionId);
    }

    function testOpenAndCloseProfitableLongUSDT() public {
        (PositionId positionId,) = _openPosition(2 ether);

        // Move the market
        skip(4.5 days);
        poolOracle.updatePool(instrument.basePool);
        skip(0.5 days);
        stubPrice({_base: WETH9, _quote: USDT, baseUsdPrice: 1500e6, quoteUsdPrice: 1e6, uniswapFee: uniswapFee});

        // Close position
        _closePosition(positionId);
    }

    function testOpenAndCloseLossMakingLongUSDT() public {
        (PositionId positionId,) = _openPosition(2 ether);

        // Move the market
        skip(4.5 days);
        poolOracle.updatePool(instrument.basePool);
        skip(0.5 days);
        stubPrice({_base: WETH9, _quote: USDT, baseUsdPrice: 960e6, quoteUsdPrice: 1e6, uniswapFee: uniswapFee});

        // Close position
        _closePosition(positionId);
    }
}
