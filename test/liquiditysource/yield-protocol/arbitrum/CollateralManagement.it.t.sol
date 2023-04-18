//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../fixtures/integration/CollateralManagementFixtures.sol";
import "./WithYieldFixtures.sol";

contract YieldArbitrumCollateralManagementETHDAI2306Test is
    ArbitrumCollateralManagementETHDAIFixtures,
    WithYieldFixtures(constants.yETHDAI2306, constants.FYETH2306, constants.FYDAI2306)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldArbitrumCollateralManagementUSDCETH2306Test is
    ArbitrumCollateralManagementUSDCETHFixtures,
    WithYieldFixtures(constants.yUSDCETH2306, constants.FYUSDC2306, constants.FYETH2306)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldArbitrumCollateralManagementETHUSDC2306Test is
    ArbitrumCollateralManagementETHUSDCFixtures,
    WithYieldFixtures(constants.yETHUSDC2306, constants.FYETH2306, constants.FYUSDC2306)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldArbitrumCollateralManagementETHUSDT2306Test is
    ArbitrumCollateralManagementETHUSDTFixtures,
    WithYieldFixtures(constants.yETHUSDT2306, constants.FYETH2306, constants.FYUSDT2306)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

abstract contract YieldArbitrumCollateralManagement2309Test is WithYieldFixtures {
    constructor(Symbol _symbol, bytes6 _baseSeriesId, bytes6 _quoteSeriesId)
        WithYieldFixtures(_symbol, _baseSeriesId, _quoteSeriesId)
    {}
}

contract YieldArbitrumCollateralManagementETHDAI2309Test is
    ArbitrumCollateralManagementETHDAIFixtures,
    YieldArbitrumCollateralManagement2309Test(constants.yETHDAI2309, constants.FYETH2309, constants.FYDAI2309)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldArbitrumCollateralManagementUSDCETH2309Test is
    ArbitrumCollateralManagementUSDCETHFixtures,
    YieldArbitrumCollateralManagement2309Test(constants.yUSDCETH2309, constants.FYUSDC2309, constants.FYETH2309)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldArbitrumCollateralManagementETHUSDC2309Test is
    ArbitrumCollateralManagementETHUSDCFixtures,
    YieldArbitrumCollateralManagement2309Test(constants.yETHUSDC2309, constants.FYETH2309, constants.FYUSDC2309)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldArbitrumCollateralManagementETHUSDT2309Test is
    ArbitrumCollateralManagementETHUSDTFixtures,
    YieldArbitrumCollateralManagement2309Test(constants.yETHUSDT2309, constants.FYETH2309, constants.FYUSDT2309)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}
