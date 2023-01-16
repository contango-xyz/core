//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../fixtures/integration/CollateralManagementFixtures.sol";
import "./WithYieldFixtures.sol";

contract YieldArbitrumCollateralManagementETHDAI2303Test is
    ArbitrumCollateralManagementETHDAIFixtures,
    WithYieldFixtures(constants.yETHDAI2303, constants.FYETH2303, constants.FYDAI2303)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldArbitrumCollateralManagementUSDCETH2303Test is
    ArbitrumCollateralManagementUSDCETHFixtures,
    WithYieldFixtures(constants.yUSDCETH2303, constants.FYUSDC2303, constants.FYETH2303)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldArbitrumCollateralManagementETHUSDC2303Test is
    ArbitrumCollateralManagementETHUSDCFixtures,
    WithYieldFixtures(constants.yETHUSDC2303, constants.FYETH2303, constants.FYUSDC2303)
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

contract YieldArbitrumCollateralManagementETHDAI2306Test is
    ArbitrumCollateralManagementETHDAIFixtures,
    YieldArbitrumPositionLifeCycle2306Test(constants.yETHDAI2306, constants.FYETH2306, constants.FYDAI2306)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldArbitrumCollateralManagementUSDCETH2306Test is
    ArbitrumCollateralManagementUSDCETHFixtures,
    YieldArbitrumPositionLifeCycle2306Test(constants.yUSDCETH2306, constants.FYUSDC2306, constants.FYETH2306)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldArbitrumCollateralManagementETHUSDC2306Test is
    ArbitrumCollateralManagementETHUSDCFixtures,
    YieldArbitrumPositionLifeCycle2306Test(constants.yETHUSDC2306, constants.FYETH2306, constants.FYUSDC2306)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}
