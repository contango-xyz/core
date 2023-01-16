//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../fixtures/integration/PhysicalDeliveryFixtures.sol";
import "./WithYieldFixtures.sol";

contract YieldMainnetPhysicalDeliveryETHDAITest is
    MainnetPhysicalDeliveryETHDAIFixtures,
    WithYieldFixtures(constants.yETHDAI2303, constants.FYETH2303, constants.FYDAI2303)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldMainnetPhysicalDeliveryUSDCETHTest is
    MainnetPhysicalDeliveryUSDCETHFixtures,
    WithYieldFixtures(constants.yUSDCETH2303, constants.FYUSDC2303, constants.FYETH2303)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldMainnetPhysicalDeliveryETHUSDCTest is
    MainnetPhysicalDeliveryETHUSDCFixtures,
    WithYieldFixtures(constants.yETHUSDC2303, constants.FYETH2303, constants.FYUSDC2303)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldMainnetPhysicalDeliveryDAIUSDCTest is
    MainnetPhysicalDeliveryDAIUSDCFixtures,
    WithYieldFixtures(constants.yDAIUSDC2303, constants.FYDAI2303, constants.FYUSDC2303)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();

        // 0.01% DAI / USDC pool is the most liquid in mainnet
        uniswapFee = 100;
    }
}
