//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../fixtures/integration/PositionLifeCycleFixtures.sol";
import "./WithYieldFixtures.sol";

contract YieldMainnetPositionLifeCycleTest is WithYieldFixtures {
    constructor(Symbol _symbol, bytes6 _baseSeriesId, bytes6 _quoteSeriesId)
        WithYieldFixtures(_symbol, _baseSeriesId, _quoteSeriesId)
    {
        addLiquidity = true;
    }
}

contract YieldMainnetPositionLifeCycleDAIETH2303Test is
    MainnetPositionLifeCycleDAIETHFixtures,
    YieldMainnetPositionLifeCycleTest(constants.yDAIETH2303, constants.FYDAI2303, constants.FYETH2303)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldMainnetPositionLifeCycleETHUSDC2303Test is
    MainnetPositionLifeCycleETHUSDCFixtures,
    YieldMainnetPositionLifeCycleTest(constants.yETHUSDC2303, constants.FYETH2303, constants.FYUSDC2303)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldMainnetPositionLifeCycleETHDAI2303Test is
    MainnetPositionLifeCycleETHDAIFixtures,
    YieldMainnetPositionLifeCycleTest(constants.yETHDAI2303, constants.FYETH2303, constants.FYDAI2303)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

abstract contract YieldMainnetPositionLifeCycle2306Test is WithYieldFixtures {
    constructor(Symbol _symbol, bytes6 _baseSeriesId, bytes6 _quoteSeriesId)
        WithYieldFixtures(_symbol, _baseSeriesId, _quoteSeriesId)
    {
        chain = "https://rpc.tenderly.co/fork/203fc4ca-66e4-40a2-b372-713a35097581";
        chainId = 1;
        blockNo = 0;
    }
}

contract YieldMainnetPositionLifeCycleETHUSDC2306Test is
    MainnetPositionLifeCycleETHUSDCFixtures,
    YieldMainnetPositionLifeCycle2306Test(constants.yETHUSDC2306, constants.FYETH2306, constants.FYUSDC2306)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldMainnetPositionLifeCycleDAIETH2306Test is
    MainnetPositionLifeCycleDAIETHFixtures,
    YieldMainnetPositionLifeCycle2306Test(constants.yDAIETH2306, constants.FYDAI2306, constants.FYETH2306)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldMainnetPositionLifeCycleETHDAI2306Test is
    MainnetPositionLifeCycleETHDAIFixtures,
    YieldMainnetPositionLifeCycle2306Test(constants.yETHDAI2306, constants.FYETH2306, constants.FYDAI2306)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}
