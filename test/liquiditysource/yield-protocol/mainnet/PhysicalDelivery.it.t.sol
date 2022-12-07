//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./WithYieldFixtures.sol";

contract YieldMainnetPhysicalDeliveryDAITest is
    WithYieldFixtures(constants.yETHDAI2303, constants.FYETH2303, constants.FYDAI2303)
{
    uint256 private seriesMaturity;

    function setUp() public override {
        super.setUp();
        seriesMaturity = cauldron.series(constants.FYDAI2303).maturity;
    }

    function testDeliverPosition() public {
        // Given
        (PositionId positionId,) = _openPosition(20 ether);

        // When
        vm.warp(seriesMaturity);

        // Then
        _deliverPosition(positionId);
    }
}

contract YieldMainnetPhysicalDeliveryETHTest is
    WithYieldFixtures(constants.yUSDCETH2303, constants.FYUSDC2303, constants.FYETH2303)
{
    uint256 private seriesMaturity;

    function setUp() public override {
        super.setUp();
        seriesMaturity = cauldron.series(constants.FYETH2303).maturity;
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

contract YieldMainnetPhysicalDeliveryUSDCTest is
    WithYieldFixtures(constants.yETHUSDC2303, constants.FYETH2303, constants.FYUSDC2303)
{
    using YieldUtils for PositionId;

    uint256 private seriesMaturity;

    function setUp() public override {
        super.setUp();
        seriesMaturity = cauldron.series(constants.FYUSDC2303).maturity;
        contangoQuoter = new ContangoYieldQuoter(positionNFT, contangoYield, cauldron, quoter);
    }

    function testDeliverPosition() public {
        // Given
        (PositionId positionId,) = _openPosition(20 ether);

        // When
        vm.warp(seriesMaturity);

        // Then
        _deliverPosition(positionId);
    }
}
