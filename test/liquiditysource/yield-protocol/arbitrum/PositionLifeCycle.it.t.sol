//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../fixtures/integration/PositionLifeCycleFixtures.sol";
import "./WithYieldFixtures.sol";

contract YieldArbitrumPositionLifeCycleDAIETHTest is
    ArbitrumPositionLifeCycleDAIETHFixtures,
    WithYieldFixtures(constants.yDAIETH2212, constants.FYDAI2212, constants.FYETH2212)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldArbitrumPositionLifeCycleETHUSDCTest is
    ArbitrumPositionLifeCycleETHUSDCFixtures,
    WithYieldFixtures(constants.yETHUSDC2212, constants.FYETH2212, constants.FYUSDC2212)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldArbitrumPositionLifeCycleETHDAITest is
    ArbitrumPositionLifeCycleETHDAIFixtures,
    WithYieldFixtures(constants.yETHDAI2212, constants.FYETH2212, constants.FYDAI2212)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

abstract contract YieldArbitrumPositionLifeCycle2303Test is WithYieldFixtures {
    constructor(Symbol _symbol, bytes6 _baseSeriesId, bytes6 _quoteSeriesId)
        WithYieldFixtures(_symbol, _baseSeriesId, _quoteSeriesId)
    {
        blockNo = 30967553;
    }
}

contract YieldArbitrumPositionLifeCycleETHUSDC2303Test is
    ArbitrumPositionLifeCycleETHUSDCFixtures,
    YieldArbitrumPositionLifeCycle2303Test(constants.yETHUSDC2303, constants.FYETH2303, constants.FYUSDC2303)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
        feeModel = IFeeModel(address(0));
    }
}

contract YieldArbitrumPositionLifeCycleDAIETH2303Test is
    ArbitrumPositionLifeCycleDAIETHFixtures,
    YieldArbitrumPositionLifeCycle2303Test(constants.yDAIETH2303, constants.FYDAI2303, constants.FYETH2303)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldArbitrumPositionLifeCycleETHDAI2303Test is
    ArbitrumPositionLifeCycleETHDAIFixtures,
    WithYieldFixtures(constants.yETHDAI2303, constants.FYETH2303, constants.FYDAI2303)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

abstract contract YieldArbitrumPositionLifeCycle2306Test is WithYieldFixtures {
    constructor(Symbol _symbol, bytes6 _baseSeriesId, bytes6 _quoteSeriesId)
        WithYieldFixtures(_symbol, _baseSeriesId, _quoteSeriesId)
    {
        blockNo = 53513476;
    }
}

contract YieldArbitrumPositionLifeCycleETHUSDC2306Test is
    ArbitrumPositionLifeCycleETHUSDCFixtures,
    YieldArbitrumPositionLifeCycle2306Test(constants.yETHUSDC2306, constants.FYETH2306, constants.FYUSDC2306)
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
    YieldArbitrumPositionLifeCycle2306Test(constants.yETHDAI2306, constants.FYETH2306, constants.FYDAI2306)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}
