//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../fixtures/integration/WethExamplesFixtures.sol";
import "./WithYieldFixtures.sol";

contract YieldArbitrumWethExamplesUSDCETH2309Test is
    ArbitrumWethExamplesUSDCETHFixtures,
    WithYieldFixtures(constants.yUSDCETH2309, constants.FYUSDC2309, constants.FYETH2309)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldArbitrumWethExamplesETHUSDC2309Test is
    ArbitrumWethExamplesETHUSDCFixtures,
    WithYieldFixtures(constants.yETHUSDC2309, constants.FYETH2309, constants.FYUSDC2309)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldArbitrumWethExamplesETHUSDT2309Test is
    ArbitrumWethExamplesETHUSDTFixtures,
    WithYieldFixtures(constants.yETHUSDT2309, constants.FYETH2309, constants.FYUSDT2309)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}
