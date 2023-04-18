//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../fixtures/integration/PositionLifeCycleFixtures.sol";
import "./WithYieldFixtures.sol";

abstract contract YieldArbitrumPositionLifeCycle2306Test is WithYieldFixtures {
    constructor(Symbol _symbol, bytes6 _baseSeriesId, bytes6 _quoteSeriesId)
        WithYieldFixtures(_symbol, _baseSeriesId, _quoteSeriesId)
    {}
}

contract YieldArbitrumPositionLifeCycleETHUSDC2306Test is
    ArbitrumPositionLifeCycleETHUSDCFixtures,
    YieldArbitrumPositionLifeCycle2306Test(constants.yETHUSDC2306, constants.FYETH2306, constants.FYUSDC2306)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldArbitrumPositionLifeCycleETHUSDT2306Test is
    ArbitrumPositionLifeCycleETHUSDTFixtures,
    YieldArbitrumPositionLifeCycle2306Test(constants.yETHUSDT2306, constants.FYETH2306, constants.FYUSDT2306)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldArbitrumPositionLifeCycleDAIETH2306Test is
    ArbitrumPositionLifeCycleDAIETHFixtures,
    YieldArbitrumPositionLifeCycle2306Test(constants.yDAIETH2306, constants.FYDAI2306, constants.FYETH2306)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldArbitrumPositionLifeCycleETHDAI2306Test is
    ArbitrumPositionLifeCycleETHDAIFixtures,
    WithYieldFixtures(constants.yETHDAI2306, constants.FYETH2306, constants.FYDAI2306)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

abstract contract YieldArbitrumPositionLifeCycle2309Test is WithYieldFixtures {
    constructor(Symbol _symbol, bytes6 _baseSeriesId, bytes6 _quoteSeriesId)
        WithYieldFixtures(_symbol, _baseSeriesId, _quoteSeriesId)
    {}
}

contract YieldArbitrumPositionLifeCycleETHUSDC2309Test is
    ArbitrumPositionLifeCycleETHUSDCFixtures,
    YieldArbitrumPositionLifeCycle2309Test(constants.yETHUSDC2309, constants.FYETH2309, constants.FYUSDC2309)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldArbitrumPositionLifeCycleETHUSDT2309Test is
    ArbitrumPositionLifeCycleETHUSDTFixtures,
    YieldArbitrumPositionLifeCycle2309Test(constants.yETHUSDT2309, constants.FYETH2309, constants.FYUSDT2309)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldArbitrumPositionLifeCycleDAIETH2309Test is
    ArbitrumPositionLifeCycleDAIETHFixtures,
    YieldArbitrumPositionLifeCycle2309Test(constants.yDAIETH2309, constants.FYDAI2309, constants.FYETH2309)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldArbitrumPositionLifeCycleETHDAI2309Test is
    ArbitrumPositionLifeCycleETHDAIFixtures,
    YieldArbitrumPositionLifeCycle2309Test(constants.yETHDAI2309, constants.FYETH2309, constants.FYDAI2309)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}
