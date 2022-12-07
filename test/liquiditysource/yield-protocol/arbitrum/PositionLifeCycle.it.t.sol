//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./WithYieldFixtures.sol";

contract YieldArbitrumPositionLifeCycleDAIETHTest is
    WithYieldFixtures(constants.yDAIETH2212, constants.FYDAI2212, constants.FYETH2212)
{
    using SignedMath for int256;
    using SafeCast for int256;
    using YieldUtils for PositionId;

    function setUp() public override {
        super.setUp();

        vm.prank(contangoTimelock);
        contango.setInstrumentUniswapFee(symbol, 3000);
    }

    function testOpenAndCloseLong() public {
        // Open position
        (PositionId positionId,) = _openPosition(10_000e18);

        // Close position
        _closePosition(positionId);
    }

    function testOpenReduceAndCloseLong() public {
        // Open position
        (PositionId positionId,) = _openPosition(10_000e18);

        // Reduce position
        _modifyPosition({positionId: positionId, quantity: -2_500e18, collateral: 0});

        // Close position
        _closePosition(positionId);
    }

    function testOpenIncreaseAndCloseLong() public {
        // Open position
        (PositionId positionId,) = _openPosition(10_000e18);

        // Increase position
        _modifyPosition({positionId: positionId, quantity: 2_500e18, collateral: 1.5 ether});

        // Close position
        _closePosition(positionId);
    }

    function testOpenReduceDepositMaxAndCloseLongPosition() public {
        // Open position
        (PositionId positionId,) = _openPosition(10_000e18);

        // Reduce position
        _modifyPosition({positionId: positionId, quantity: -2_500e18, collateral: type(int256).max});

        // Close position
        _closePosition(positionId);
    }
}

contract YieldArbitrumPositionLifeCycleETHUSDCTest is
    WithYieldFixtures(constants.yETHUSDC2212, constants.FYETH2212, constants.FYUSDC2212)
{
    using SafeCast for int256;
    using SignedMath for int256;
    using YieldUtils for PositionId;

    function testOpenAndCloseLong() public {
        // Open position
        (PositionId positionId,) = _openPosition(2 ether);

        // Close position
        _closePosition(positionId);
    }

    function testOpenReduceAndCloseLong() public {
        // Open position
        (PositionId positionId,) = _openPosition(2 ether);

        // Reduce position
        _modifyPosition({positionId: positionId, quantity: -0.25 ether, collateral: 0});

        // Close position
        _closePosition(positionId);
    }

    function testOpenIncreaseAndCloseLong() public {
        // Open position
        (PositionId positionId,) = _openPosition(2 ether);

        // Increase position
        _modifyPosition({positionId: positionId, quantity: 0.25 ether, collateral: 300e6});

        // Close position
        _closePosition(positionId);
    }

    function testOpenReduceDepositMaxAndCloseLongPosition() public {
        // Open position
        (PositionId positionId,) = _openPosition(2 ether);

        // Reduce position
        _modifyPosition({positionId: positionId, quantity: -0.25 ether, collateral: type(int256).max});

        // Close position
        _closePosition(positionId);
    }
}

contract YieldArbitrumPositionLifeCycleETHDAITest is
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

    function testOpenAndCloseLong() public {
        // Open position
        (PositionId positionId,) = _openPosition(2 ether);

        // Close position
        _closePosition(positionId);
    }

    function testOpenReduceAndCloseLong() public {
        // Open position
        (PositionId positionId,) = _openPosition(2 ether);

        // Reduce position
        _modifyPosition({positionId: positionId, quantity: -0.25 ether, collateral: 0});

        // Close position
        _closePosition(positionId);
    }

    function testOpenIncreaseAndCloseLong() public {
        // Open position
        (PositionId positionId,) = _openPosition(2 ether);

        // Increase position
        _modifyPosition({positionId: positionId, quantity: 0.25 ether, collateral: 300e18});

        // Close position
        _closePosition(positionId);
    }

    function testOpenReduceDepositMaxAndCloseLongPosition() public {
        // Open position
        (PositionId positionId,) = _openPosition(2 ether);

        // Reduce position
        _modifyPosition({positionId: positionId, quantity: -0.25 ether, collateral: type(int256).max});

        // Close position
        _closePosition(positionId);
    }
}

contract YieldArbitrumPositionLifeCycleETHUSDC2303Test is
    WithYieldFixtures(constants.yETHUSDC2303, constants.FYETH2303, constants.FYUSDC2303)
{
    using SafeCast for int256;
    using SignedMath for int256;
    using YieldUtils for PositionId;

    constructor() {
        blockNo = 30967553;
    }

    function setUp() public override {
        super.setUp();
        feeModel = IFeeModel(address(0));
    }

    function testOpenAndCloseLong() public {
        // Open position
        (PositionId positionId,) = _openPosition(2 ether);

        // Close position
        _closePosition(positionId);
    }

    function testOpenReduceAndCloseLong() public {
        // Open position
        (PositionId positionId,) = _openPosition(2 ether);

        // Reduce position
        _modifyPosition({positionId: positionId, quantity: -0.25 ether, collateral: 0});

        // Close position
        _closePosition(positionId);
    }

    function testOpenIncreaseAndCloseLong() public {
        // Open position
        (PositionId positionId,) = _openPosition(2 ether);

        // Increase position
        _modifyPosition({positionId: positionId, quantity: 0.25 ether, collateral: 300e6});

        // Close position
        _closePosition(positionId);
    }

    function testOpenReduceDepositMaxAndCloseLongPosition() public {
        // Open position
        (PositionId positionId,) = _openPosition(2 ether);

        // Reduce position
        _modifyPosition({positionId: positionId, quantity: -0.25 ether, collateral: type(int256).max});

        // Close position
        _closePosition(positionId);
    }
}

contract YieldArbitrumPositionLifeCycleDAIETH2303Test is
    WithYieldFixtures(constants.yDAIETH2303, constants.FYDAI2303, constants.FYETH2303)
{
    using SignedMath for int256;
    using SafeCast for int256;
    using YieldUtils for PositionId;

    constructor() {
        blockNo = 30967553;
    }

    function setUp() public override {
        super.setUp();

        vm.prank(contangoTimelock);
        contango.setInstrumentUniswapFee(symbol, 3000);
    }

    function testOpenAndCloseLong() public {
        // Open position
        (PositionId positionId,) = _openPosition(10_000e18);

        // Close position
        _closePosition(positionId);
    }

    function testOpenReduceAndCloseLong() public {
        // Open position
        (PositionId positionId,) = _openPosition(10_000e18);

        // Reduce position
        _modifyPosition({positionId: positionId, quantity: -2_500e18, collateral: 0});

        // Close position
        _closePosition(positionId);
    }

    function testOpenIncreaseAndCloseLong() public {
        // Open position
        (PositionId positionId,) = _openPosition(10_000e18);

        // Increase position
        _modifyPosition({positionId: positionId, quantity: 2_500e18, collateral: 1.5 ether});

        // Close position
        _closePosition(positionId);
    }

    function testOpenReduceDepositMaxAndCloseLongPosition() public {
        // Open position
        (PositionId positionId,) = _openPosition(10_000e18);

        // Reduce position
        _modifyPosition({positionId: positionId, quantity: -2_500e18, collateral: type(int256).max});

        // Close position
        _closePosition(positionId);
    }
}

contract YieldArbitrumPositionLifeCycleETHDAI2303Test is
    WithYieldFixtures(constants.yETHDAI2303, constants.FYETH2303, constants.FYDAI2303)
{
    using SignedMath for int256;
    using SafeCast for int256;
    using YieldUtils for PositionId;

    constructor() {
        blockNo = 30967553;
    }

    function setUp() public override {
        super.setUp();

        vm.prank(contangoTimelock);
        contango.setInstrumentUniswapFee(symbol, 3000);
    }

    function testOpenAndCloseLong() public {
        // Open position
        (PositionId positionId,) = _openPosition(2 ether);

        // Close position
        _closePosition(positionId);
    }

    function testOpenReduceAndCloseLong() public {
        // Open position
        (PositionId positionId,) = _openPosition(2 ether);

        // Reduce position
        _modifyPosition({positionId: positionId, quantity: -0.25 ether, collateral: 0});

        // Close position
        _closePosition(positionId);
    }

    function testOpenIncreaseAndCloseLong() public {
        // Open position
        (PositionId positionId,) = _openPosition(2 ether);

        // Increase position
        _modifyPosition({positionId: positionId, quantity: 0.25 ether, collateral: 300e18});

        // Close position
        _closePosition(positionId);
    }

    function testOpenReduceDepositMaxAndCloseLongPosition() public {
        // Open position
        (PositionId positionId,) = _openPosition(2 ether);

        // Reduce position
        _modifyPosition({positionId: positionId, quantity: -0.25 ether, collateral: type(int256).max});

        // Close position
        _closePosition(positionId);
    }
}
