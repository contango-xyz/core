//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./WithYieldFixtures.sol";

contract YieldMainnetPositionLifeCycleDAIETH2212Test is
    WithYieldFixtures(constants.yDAIETH2212, constants.FYDAI2212, constants.FYETH2212)
{
    using SignedMath for int256;
    using SafeCast for int256;
    using YieldUtils for PositionId;

    constructor() {
        addLiquidity = true;
    }

    function testOpenAndCloseLong() public {
        // Open position
        (PositionId positionId,) = _openPosition(100_000e18);

        // Close position
        _closePosition(positionId);
    }

    function testOpenReduceAndCloseLong() public {
        // Open position
        (PositionId positionId,) = _openPosition(100_000e18);

        // Reduce position
        _modifyPosition({positionId: positionId, quantity: -1000e18, collateral: 0});

        // Close position
        _closePosition(positionId);
    }

    function testOpenIncreaseAndCloseLong() public {
        // Open position
        (PositionId positionId,) = _openPosition(100_000e18);

        // Increase position
        _modifyPosition({positionId: positionId, quantity: 5_000e18, collateral: 2.5 ether});

        // Close position
        _closePosition(positionId);
    }

    function testOpenReduceDepositMaxAndCloseLongPosition() public {
        // Open position
        (PositionId positionId,) = _openPosition(100_000e18);

        // Reduce position
        _modifyPosition({positionId: positionId, quantity: -1_000e18, collateral: type(int256).max});

        // Close position
        _closePosition(positionId);
    }
}

contract YieldMainnetPositionLifeCycleETHUSDC2212Test is
    WithYieldFixtures(constants.yETHUSDC2212, constants.FYETH2212, constants.FYUSDC2212)
{
    using SafeCast for int256;
    using SignedMath for int256;
    using YieldUtils for PositionId;

    constructor() {
        addLiquidity = true;
    }

    function testOpenAndCloseLong() public {
        // Open position
        (PositionId positionId,) = _openPosition(20 ether);

        // Close position
        _closePosition(positionId);
    }

    function testOpenReduceAndCloseLong() public {
        // Open position
        (PositionId positionId,) = _openPosition(20 ether);

        // Reduce position
        _modifyPosition({positionId: positionId, quantity: -0.5 ether, collateral: 0});

        // Close position
        _closePosition(positionId);
    }

    function testOpenIncreaseAndCloseLong() public {
        // Open position
        (PositionId positionId,) = _openPosition(20 ether);

        // Increase position
        _modifyPosition({positionId: positionId, quantity: 0.5 ether, collateral: 300e6});

        // Close position
        _closePosition(positionId);
    }

    function testOpenReduceDepositMaxAndCloseLongPosition() public {
        // Open position
        (PositionId positionId,) = _openPosition(20 ether);

        // Reduce position
        _modifyPosition({positionId: positionId, quantity: -0.25 ether, collateral: type(int256).max});

        // Close position
        _closePosition(positionId);
    }
}

contract YieldMainnetPositionLifeCycleETHDAI2212Test is
    WithYieldFixtures(constants.yETHDAI2212, constants.FYETH2212, constants.FYDAI2212)
{
    using SignedMath for int256;
    using SafeCast for int256;
    using YieldUtils for PositionId;

    constructor() {
        addLiquidity = true;
    }

    function testOpenAndCloseLong() public {
        // Open position
        (PositionId positionId,) = _openPosition(20 ether);

        // Close position
        _closePosition(positionId);
    }

    function testOpenReduceAndCloseLong() public {
        // Open position
        (PositionId positionId,) = _openPosition(20 ether);

        // Reduce position
        _modifyPosition({positionId: positionId, quantity: -0.5 ether, collateral: 0});

        // Close position
        _closePosition(positionId);
    }

    function testOpenIncreaseAndCloseLong() public {
        // Open position
        (PositionId positionId,) = _openPosition(20 ether);

        // Increase position
        _modifyPosition({positionId: positionId, quantity: 0.5 ether, collateral: 300e18});

        // Close position
        _closePosition(positionId);
    }

    function testOpenReduceDepositMaxAndCloseLongPosition() public {
        // Open position
        (PositionId positionId,) = _openPosition(20 ether);

        // Reduce position
        _modifyPosition({positionId: positionId, quantity: -0.5 ether, collateral: type(int256).max});

        // Close position
        _closePosition(positionId);
    }
}

contract YieldMainnetPositionLifeCycleDAIETH2303Test is
    WithYieldFixtures(constants.yDAIETH2303, constants.FYDAI2303, constants.FYETH2303)
{
    using SignedMath for int256;
    using SafeCast for int256;
    using YieldUtils for PositionId;

    function testOpenAndCloseLong() public {
        // Open position
        (PositionId positionId,) = _openPosition(100_000e18);

        // Close position
        _closePosition(positionId);
    }

    function testOpenReduceAndCloseLong() public {
        // Open position
        (PositionId positionId,) = _openPosition(100_000e18);

        // Reduce position
        _modifyPosition({positionId: positionId, quantity: -1000e18, collateral: 0});

        // Close position
        _closePosition(positionId);
    }

    function testOpenIncreaseAndCloseLong() public {
        // Open position
        (PositionId positionId,) = _openPosition(100_000e18);

        // Increase position
        _modifyPosition({positionId: positionId, quantity: 5_000e18, collateral: 2.5 ether});

        // Close position
        _closePosition(positionId);
    }

    function testOpenReduceDepositMaxAndCloseLongPosition() public {
        // Open position
        (PositionId positionId,) = _openPosition(100_000e18);

        // Reduce position
        _modifyPosition({positionId: positionId, quantity: -1_000e18, collateral: type(int256).max});

        // Close position
        _closePosition(positionId);
    }
}

contract YieldMainnetPositionLifeCycleETHUSDC2303Test is
    WithYieldFixtures(constants.yETHUSDC2303, constants.FYETH2303, constants.FYUSDC2303)
{
    using SafeCast for int256;
    using SignedMath for int256;
    using YieldUtils for PositionId;

    function testOpenAndCloseLong() public {
        // Open position
        (PositionId positionId,) = _openPosition(20 ether);

        // Close position
        _closePosition(positionId);
    }

    function testOpenReduceAndCloseLong() public {
        // Open position
        (PositionId positionId,) = _openPosition(20 ether);

        // Reduce position
        _modifyPosition({positionId: positionId, quantity: -0.5 ether, collateral: 0});

        // Close position
        _closePosition(positionId);
    }

    function testOpenIncreaseAndCloseLong() public {
        // Open position
        (PositionId positionId,) = _openPosition(20 ether);

        // Increase position
        _modifyPosition({positionId: positionId, quantity: 0.5 ether, collateral: 300e6});

        // Close position
        _closePosition(positionId);
    }

    function testOpenReduceDepositMaxAndCloseLongPosition() public {
        // Open position
        (PositionId positionId,) = _openPosition(20 ether);

        // Reduce position
        _modifyPosition({positionId: positionId, quantity: -0.25 ether, collateral: type(int256).max});

        // Close position
        _closePosition(positionId);
    }
}

contract YieldMainnetPositionLifeCycleETHDAI2303Test is
    WithYieldFixtures(constants.yETHDAI2303, constants.FYETH2303, constants.FYDAI2303)
{
    using SignedMath for int256;
    using SafeCast for int256;
    using YieldUtils for PositionId;

    function testOpenAndCloseLong() public {
        // Open position
        (PositionId positionId,) = _openPosition(20 ether);

        // Close position
        _closePosition(positionId);
    }

    function testOpenReduceAndCloseLong() public {
        // Open position
        (PositionId positionId,) = _openPosition(20 ether);

        // Reduce position
        _modifyPosition({positionId: positionId, quantity: -0.5 ether, collateral: 0});

        // Close position
        _closePosition(positionId);
    }

    function testOpenIncreaseAndCloseLong() public {
        // Open position
        (PositionId positionId,) = _openPosition(20 ether);

        // Increase position
        _modifyPosition({positionId: positionId, quantity: 0.5 ether, collateral: 300e18});

        // Close position
        _closePosition(positionId);
    }

    function testOpenReduceDepositMaxAndCloseLongPosition() public {
        // Open position
        (PositionId positionId,) = _openPosition(20 ether);

        // Reduce position
        _modifyPosition({positionId: positionId, quantity: -0.5 ether, collateral: type(int256).max});

        // Close position
        _closePosition(positionId);
    }
}
