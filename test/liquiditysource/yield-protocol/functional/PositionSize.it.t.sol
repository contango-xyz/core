//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./WithYieldFixtures.sol";
import {IOraclePoolStub} from "../../../stub/IOraclePoolStub.sol";

contract YieldPositionSizeTest is
    WithYieldFixtures(constants.yETHUSDC2212, constants.FYETH2212, constants.FYUSDC2212)
{
    using SignedMath for int256;
    using SafeCast for int256;

    error PositionIsTooSmall(uint256 openCost, uint256 minCost);

    function setUp() public override {
        super.setUp();

        stubPriceWETHUSDC(1400e6, 1e6);

        vm.etch(address(yieldInstrument.basePool), getCode(address(new IPoolStub(yieldInstrument.basePool))));
        vm.etch(address(yieldInstrument.quotePool), getCode(address(new IPoolStub(yieldInstrument.quotePool))));

        IPoolStub(address(yieldInstrument.basePool)).setBidAsk(0.945e18, 0.955e18);
        IPoolStub(address(yieldInstrument.quotePool)).setBidAsk(0.895e6, 0.905e6);

        symbol = Symbol.wrap("yETHUSDC2212-2");
        vm.prank(contangoTimelock);
        (instrument, yieldInstrument) = contangoYield.createYieldInstrument(
            symbol, constants.FYETH2212, constants.FYUSDC2212, constants.FEE_0_05, feeModel
        );

        vm.startPrank(yieldTimelock);
        ICompositeMultiOracle compositeOracle = ICompositeMultiOracle(0x750B3a18115fe090Bc621F9E4B90bd442bcd02F2);
        compositeOracle.setSource(
            constants.FYETH2212,
            constants.ETH_ID,
            new IOraclePoolStub(IPoolStub(address(yieldInstrument.basePool)), constants.FYETH2212)
        );
        vm.stopPrank();

        _setPoolStubLiquidity(yieldInstrument.basePool, 1_000 ether);
        _setPoolStubLiquidity(yieldInstrument.quotePool, 1_000_000e6);
    }

    function testCanNotOpenSmallPosition() public {
        OpeningCostParams memory params = OpeningCostParams({
            symbol: symbol,
            quantity: 0.1 ether,
            collateral: 0,
            collateralSlippage: collateralSlippage
        });
        ModifyCostResult memory result = contangoQuoter.openingCostForPosition(params);

        assertEqDecimal(result.spotCost, -140.1e6, 6);
        assertEqDecimal(result.cost, -143.712225e6, 6);

        dealAndApprove(address(USDC), trader, result.collateralUsed.toUint256(), address(contango));

        vm.expectRevert(
            abi.encodeWithSelector(PositionIsTooSmall.selector, result.cost.abs() + Yield.BORROWING_BUFFER + 1, 200e6)
        );
        vm.prank(trader);
        contango.createPosition(
            symbol,
            trader,
            params.quantity,
            result.cost.abs() + Yield.BORROWING_BUFFER + 1,
            result.collateralUsed.toUint256(),
            trader,
            HIGH_LIQUIDITY
        );
    }

    function testCanNotReducePositionSizeIfItWouldEndUpTooSmall() public {
        (PositionId positionId,) = _openPosition(0.2 ether);

        // Reduce position
        ModifyCostResult memory result =
            contangoQuoter.modifyCostForPosition(ModifyCostParams(positionId, -0.08 ether, 0, collateralSlippage));

        vm.expectRevert(
            abi.encodeWithSelector(PositionIsTooSmall.selector, 171.761074e6 + Yield.BORROWING_BUFFER, 200e6)
        );
        vm.prank(trader);
        contango.modifyPosition(positionId, -0.08 ether, result.cost.abs(), 0, trader, result.quoteLendingLiquidity);
    }
}

contract YieldDebtLimitsTest is WithYieldFixtures(constants.yETHUSDC2212, constants.FYETH2212, constants.FYUSDC2212) {
    function testDebtLimit() public {
        // positions borrow USDC
        DataTypes.Series memory series = cauldron.series(yieldInstrument.quoteId);

        // open position
        (PositionId positionId,) = _openPosition(9 ether);

        // initial debt state
        DataTypes.Debt memory debt = cauldron.debt(series.baseId, yieldInstrument.baseId);

        // checks increase would fail
        dealAndApprove(address(USDC), trader, 6000e6, address(contango));
        vm.expectRevert("Max debt exceeded");
        vm.prank(trader);
        contango.modifyPosition(positionId, 10 ether, type(uint256).max, 6000e6, trader, 0);

        // assert unchanged debt limits
        DataTypes.Debt memory debtAfter = cauldron.debt(series.baseId, yieldInstrument.baseId);
        assertEq(debt.sum, debtAfter.sum);
    }

    function testCanNotRemoveCollateral_openPositionOnDebtLimit() public {
        // positions borrow USDC
        DataTypes.Series memory series = cauldron.series(yieldInstrument.quoteId);

        // open position
        (PositionId positionId,) = _openPosition(9.2 ether);

        // initial debt state
        DataTypes.Debt memory debt = cauldron.debt(series.baseId, yieldInstrument.baseId);
        uint256 remainingDebt = uint256(debt.max) * 10 ** debt.dec - debt.sum;

        // checks realise profit would fail
        vm.expectRevert("Max debt exceeded");
        vm.prank(trader);
        contango.modifyCollateral(positionId, -int256(remainingDebt + 1), type(uint256).max, trader, 0);
    }
}
