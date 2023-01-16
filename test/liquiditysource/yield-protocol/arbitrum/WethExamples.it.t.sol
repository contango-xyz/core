//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../fixtures/integration/WethExamplesFixtures.sol";
import "./WithYieldFixtures.sol";

contract YieldArbitrumWethExamplesUSDCETHFixtures is
    ArbitrumWethExamplesUSDCETHFixtures,
    WithYieldFixtures(constants.yUSDCETH2212, constants.FYUSDC2212, constants.FYETH2212)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldArbitrumWethExamplesETHUSDCFixtures is
    ArbitrumWethExamplesETHUSDCFixtures,
    WithYieldFixtures(constants.yETHUSDC2212, constants.FYETH2212, constants.FYUSDC2212)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}
