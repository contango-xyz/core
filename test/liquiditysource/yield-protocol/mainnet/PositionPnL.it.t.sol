//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./WithYieldFixtures.sol";

import "src/dependencies/Uniswap.sol";

contract YieldMainnetPnLUSDCTest is
    WithYieldFixtures(constants.yETHUSDC2303, constants.FYETH2303, constants.FYUSDC2303)
{
    using SignedMath for int256;
    using SafeCast for int256;
    using YieldUtils for PositionId;

    function setUp() public override {
        super.setUp();
        stubPrice({_base: WETH9, _quote: USDC, baseUsdPrice: 1000e6, quoteUsdPrice: 1e6, uniswapFee: uniswapFee});
    }

    function testOpenAndCloseProfitableLongUSDC() public {
        (PositionId positionId,) = _openPosition(20 ether);

        // Move the market
        skip(4.5 days);
        _update(instrument.basePool);
        skip(0.5 days);
        stubPrice({_base: WETH9, _quote: USDC, baseUsdPrice: 1500e6, quoteUsdPrice: 1e6, uniswapFee: uniswapFee});

        // Close position
        _closePosition(positionId);
    }

    function testOpenAndCloseLossMakingLongUSDC() public {
        (PositionId positionId,) = _openPosition(20 ether);

        // Move the market
        skip(4.5 days);
        _update(instrument.basePool);
        skip(0.5 days);
        stubPrice({_base: WETH9, _quote: USDC, baseUsdPrice: 960e6, quoteUsdPrice: 1e6, uniswapFee: uniswapFee});

        // Close position
        _closePosition(positionId);
    }

    // The version of the code is different from what's deployed, so we need to hack a bit to call the old function
    function _update(IPool pool) internal {
        (bool success,) = address(poolOracle).call(abi.encodeWithSelector(0x7b46c54f, address(pool)));
        assertTrue(success, "PoolOracle#updatePool");
    }
}
