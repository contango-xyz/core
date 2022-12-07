//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./WithYieldFixtures.sol";

contract YieldArbitrumCollateralManagementDAITest is
    WithYieldFixtures(constants.yETHDAI2212, constants.FYETH2212, constants.FYDAI2212)
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
        (PositionId positionId,) = _openPosition(2 ether);

        // Add collateral
        _modifyCollateral({positionId: positionId, collateral: 500e18});

        // Close position
        _closePosition(positionId);
    }

    function testRemoveCollateralOnPosition() public {
        // Open position
        (PositionId positionId,) = _openPosition(2 ether, 2000e18);

        // Remove collateral
        _modifyCollateral({positionId: positionId, collateral: -500e18});

        // Close position
        _closePosition(positionId);
    }
}

contract YieldArbitrumCollateralManagementETHTest is
    WithYieldFixtures(constants.yUSDCETH2212, constants.FYUSDC2212, constants.FYETH2212)
{
    using SignedMath for int256;
    using SafeCast for int256;
    using YieldUtils for PositionId;

    function testAddCollateralToPosition() public {
        // Open position
        (PositionId positionId,) = _openPosition(10_000e6);

        // Add collateral
        _modifyCollateral({positionId: positionId, collateral: 0.5 ether});

        // Close position
        _closePosition(positionId);
    }

    function testRemoveCollateralOnPosition() public {
        // Open position
        (PositionId positionId,) = _openPosition(10_000e6, 4 ether);

        // Remove collateral
        _modifyCollateral({positionId: positionId, collateral: -0.5 ether});

        // Close position
        _closePosition(positionId);
    }
}

contract YieldArbitrumCollateralManagementUSDCTest is
    WithYieldFixtures(constants.yETHUSDC2212, constants.FYETH2212, constants.FYUSDC2212)
{
    using SignedMath for int256;
    using SafeCast for int256;
    using YieldUtils for PositionId;

    function testAddCollateralToPosition() public {
        // Open position
        (PositionId positionId,) = _openPosition(2 ether);

        // Add collateral
        _modifyCollateral({positionId: positionId, collateral: 500e6});

        // Close position
        _closePosition(positionId);
    }

    function testRemoveCollateralOnPosition() public {
        // Open position
        (PositionId positionId,) = _openPosition(2 ether, 2000e6);

        // Remove collateral
        _modifyCollateral({positionId: positionId, collateral: -500e6});

        // Close position
        _closePosition(positionId);
    }
}
