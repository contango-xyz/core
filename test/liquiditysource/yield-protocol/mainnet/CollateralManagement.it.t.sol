//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../fixtures/integration/CollateralManagementFixtures.sol";
import "./WithYieldFixtures.sol";

contract YieldMainnetCollateralManagementETHDAITest is
    MainnetCollateralManagementETHDAIFixtures,
    WithYieldFixtures(constants.yETHDAI2303, constants.FYETH2303, constants.FYDAI2303)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldMainnetCollateralManagementUSDCETHTest is
    MainnetCollateralManagementUSDCETHFixtures,
    WithYieldFixtures(constants.yUSDCETH2303, constants.FYUSDC2303, constants.FYETH2303)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldMainnetCollateralManagementETHUSDCTest is
    MainnetCollateralManagementETHUSDCFixtures,
    WithYieldFixtures(constants.yETHUSDC2303, constants.FYETH2303, constants.FYUSDC2303)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

abstract contract YieldMainnetCollateralManagement2306Test is WithYieldFixtures {
    constructor(Symbol _symbol, bytes6 _baseSeriesId, bytes6 _quoteSeriesId)
        WithYieldFixtures(_symbol, _baseSeriesId, _quoteSeriesId)
    {
        chain = "https://rpc.tenderly.co/fork/203fc4ca-66e4-40a2-b372-713a35097581";
        chainId = 1;
        blockNo = 0;
    }
}

contract YieldMainnetCollateralManagementETHDAI2306Test is
    MainnetCollateralManagementETHDAIFixtures,
    YieldMainnetCollateralManagement2306Test(constants.yETHDAI2306, constants.FYETH2306, constants.FYDAI2306)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldMainnetCollateralManagementUSDCETH2306Test is
    MainnetCollateralManagementUSDCETHFixtures,
    YieldMainnetCollateralManagement2306Test(constants.yUSDCETH2306, constants.FYUSDC2306, constants.FYETH2306)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldMainnetCollateralManagementETHUSDC2306Test is
    MainnetCollateralManagementETHUSDCFixtures,
    YieldMainnetCollateralManagement2306Test(constants.yETHUSDC2306, constants.FYETH2306, constants.FYUSDC2306)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}
