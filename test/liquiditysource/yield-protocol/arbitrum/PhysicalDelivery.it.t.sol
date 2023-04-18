//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../fixtures/integration/PhysicalDeliveryFixtures.sol";
import "./WithYieldFixtures.sol";

contract YieldArbitrumPhysicalDeliveryETHDAITest is
    ArbitrumPhysicalDeliveryETHDAIFixtures,
    WithYieldFixtures(constants.yETHDAI2306, constants.FYETH2306, constants.FYDAI2306)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldArbitrumPhysicalDeliveryUSDCETHTest is
    ArbitrumPhysicalDeliveryUSDCETHFixtures,
    WithYieldFixtures(constants.yUSDCETH2306, constants.FYUSDC2306, constants.FYETH2306)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldArbitrumPhysicalDeliveryETHUSDCTest is
    ArbitrumPhysicalDeliveryETHUSDCFixtures,
    WithYieldFixtures(constants.yETHUSDC2306, constants.FYETH2306, constants.FYUSDC2306)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldArbitrumPhysicalDeliveryETHUSDTTest is
    ArbitrumPhysicalDeliveryETHUSDTFixtures,
    WithYieldFixtures(constants.yETHUSDT2306, constants.FYETH2306, constants.FYUSDT2306)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldArbitrumPhysicalDeliveryDAIUSDCTest is
    ArbitrumPhysicalDeliveryDAIUSDCFixtures,
    WithYieldFixtures(constants.yDAIUSDC2306, constants.FYDAI2306, constants.FYUSDC2306)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();

        // 0.05% DAI / USDC pool is the most liquid in arbitrum
        uniswapFee = 500;
    }
}
