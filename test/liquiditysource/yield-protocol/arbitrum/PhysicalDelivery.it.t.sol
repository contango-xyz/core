//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./WithYieldFixtures.sol";

contract YieldArbitrumYieldPhysicalDeliveryDAITest is
    WithYieldFixtures(constants.yETHDAI2212, constants.FYETH2212, constants.FYDAI2212)
{
    uint256 private seriesMaturity;

    function setUp() public override {
        super.setUp();
        seriesMaturity = cauldron.series(constants.FYDAI2212).maturity;
    }

    function testDeliverPosition() public {
        // Given
        (PositionId positionId,) = _openPosition(2 ether);

        // When
        vm.warp(seriesMaturity);

        // Then
        _deliverPosition(positionId);
    }
}

contract YieldArbitrumYieldPhysicalDeliveryETHTest is
    WithYieldFixtures(constants.yUSDCETH2212, constants.FYUSDC2212, constants.FYETH2212)
{
    uint256 private seriesMaturity;

    function setUp() public override {
        super.setUp();
        seriesMaturity = cauldron.series(constants.FYETH2212).maturity;
    }

    function testDeliverPosition() public {
        // Given
        (PositionId positionId,) = _openPosition(10_000e6);

        // When
        vm.warp(seriesMaturity);

        // Then
        _deliverPosition(positionId);
    }
}

contract YieldArbitrumYieldPhysicalDeliveryUSDCTest is
    WithYieldFixtures(constants.yETHUSDC2212, constants.FYETH2212, constants.FYUSDC2212)
{
    using YieldUtils for PositionId;

    uint256 private seriesMaturity;

    function setUp() public override {
        super.setUp();
        seriesMaturity = cauldron.series(constants.FYUSDC2212).maturity;
        contangoQuoter = new ContangoYieldQuoter(positionNFT, contangoYield, cauldron, quoter);
    }

    function testDeliverPosition() public {
        // Given
        (PositionId positionId,) = _openPosition(2 ether);

        // When
        vm.warp(seriesMaturity);

        // Then
        _deliverPosition(positionId);
    }
}
