//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../fixtures/integration/PhysicalDeliveryFixtures.sol";
import "./WithYieldFixtures.sol";

contract YieldArbitrumPhysicalDeliveryETHDAITest is
    ArbitrumPhysicalDeliveryETHDAIFixtures,
    WithYieldFixtures(constants.yETHDAI2303, constants.FYETH2303, constants.FYDAI2303)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldArbitrumPhysicalDeliveryUSDCETHTest is
    ArbitrumPhysicalDeliveryUSDCETHFixtures,
    WithYieldFixtures(constants.yUSDCETH2303, constants.FYUSDC2303, constants.FYETH2303)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldArbitrumPhysicalDeliveryETHUSDCTest is
    ArbitrumPhysicalDeliveryETHUSDCFixtures,
    WithYieldFixtures(constants.yETHUSDC2303, constants.FYETH2303, constants.FYUSDC2303)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }
}

contract YieldArbitrumPhysicalDeliveryDAIUSDCTest is
    ArbitrumPhysicalDeliveryDAIUSDCFixtures,
    WithYieldFixtures(constants.yDAIUSDC2303, constants.FYDAI2303, constants.FYUSDC2303)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();

        // 0.05% DAI / USDC pool is the most liquid in arbitrum
        uniswapFee = 500;
    }
}
