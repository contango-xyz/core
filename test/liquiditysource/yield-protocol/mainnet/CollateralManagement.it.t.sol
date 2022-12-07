//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./WithYieldFixtures.sol";

contract YieldMainnetCollateralManagementDAITest is
    WithYieldFixtures(constants.yETHDAI2303, constants.FYETH2303, constants.FYDAI2303)
{
    using SignedMath for int256;
    using SafeCast for int256;
    using YieldUtils for PositionId;

    function setUp() public override {
        super.setUp();

        vm.prank(contangoTimelock);
        contango.setInstrumentUniswapFee(symbol, 3000);
    }

    function testAddCollateralToPosition() public {
        // Open position
        (PositionId positionId,) = _openPosition(20 ether);

        // Add collateral
        _modifyCollateral({positionId: positionId, collateral: 500e18});

        // Close position
        _closePosition(positionId);
    }

    function testRemoveCollateralOnPosition() public {
        // Open position
        (PositionId positionId,) = _openPosition(20 ether, 20000e18);

        // Remove collateral
        _modifyCollateral({positionId: positionId, collateral: -500e18});

        // Close position
        _closePosition(positionId);
    }
}

contract YieldMainnetCollateralManagementETHTest is
    WithYieldFixtures(constants.yUSDCETH2303, constants.FYUSDC2303, constants.FYETH2303)
{
    using SignedMath for int256;
    using SafeCast for int256;
    using YieldUtils for PositionId;

    function testAddCollateralToPosition() public {
        // Open position
        (PositionId positionId,) = _openPosition(30_000e6);

        // Add collateral
        _modifyCollateral({positionId: positionId, collateral: 0.5 ether});

        // Close position
        _closePosition(positionId);
    }

    function testRemoveCollateralOnPosition() public {
        // Open position
        (PositionId positionId,) = _openPosition(30_000e6, 12 ether);

        // Remove collateral
        _modifyCollateral({positionId: positionId, collateral: -0.5 ether});

        // Close position
        _closePosition(positionId);
    }
}

contract YieldMainnetCollateralManagementUSDCTest is
    WithYieldFixtures(constants.yETHUSDC2303, constants.FYETH2303, constants.FYUSDC2303)
{
    using SignedMath for int256;
    using SafeCast for int256;
    using YieldUtils for PositionId;

    function testAddCollateralToPosition() public {
        // Open position
        (PositionId positionId,) = _openPosition(20 ether);

        // Add collateral
        _modifyCollateral({positionId: positionId, collateral: 500e6});

        // Close position
        _closePosition(positionId);
    }

    function testRemoveCollateralOnPosition() public {
        // Open position
        (PositionId positionId,) = _openPosition(20 ether, 20000e6);

        // Remove collateral
        _modifyCollateral({positionId: positionId, collateral: -500e6});

        // Close position
        _closePosition(positionId);
    }
}
