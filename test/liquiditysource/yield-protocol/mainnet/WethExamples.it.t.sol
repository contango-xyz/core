//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../fixtures/integration/WethExamplesFixtures.sol";
import "./WithYieldFixtures.sol";

contract YieldMainnetWethExamplesUSDCETHFixtures is
    MainnetWethExamplesUSDCETHFixtures,
    WithYieldFixtures(constants.yUSDCETH2303, constants.FYUSDC2303, constants.FYETH2303)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldMainnetWethExamplesETHUSDCFixtures is
    MainnetWethExamplesETHUSDCFixtures,
    WithYieldFixtures(constants.yETHUSDC2303, constants.FYETH2303, constants.FYUSDC2303)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}
