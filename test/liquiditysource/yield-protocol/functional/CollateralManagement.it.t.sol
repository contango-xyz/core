//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./WithYieldFixtures.sol";
import {IOraclePoolStub} from "../../../stub/IOraclePoolStub.sol";

contract YieldCollateralManagementTest is
    WithYieldFixtures(constants.yETHUSDC2212, constants.FYETH2212, constants.FYUSDC2212)
{
    using SignedMath for int256;
    using SafeCast for int256;
    using SignedMathLib for int256;
    using YieldUtils for PositionId;

    function setUp() public override {
        super.setUp();

        stubPriceWETHUSDC(700e6, 1e6);

        vm.etch(address(yieldInstrument.basePool), getCode(address(new IPoolStub(yieldInstrument.basePool))));
        vm.etch(address(yieldInstrument.quotePool), getCode(address(new IPoolStub(yieldInstrument.quotePool))));

        IPoolStub(address(yieldInstrument.basePool)).setBidAsk(0.945e18, 0.955e18);
        IPoolStub(address(yieldInstrument.quotePool)).setBidAsk(0.895e6, 0.905e6);

        DataTypes.Debt memory debt = cauldron.debt(constants.USDC_ID, constants.FYETH2212);
        vm.prank(yieldTimelock);
        ICauldronExt(address(cauldron)).setDebtLimits(constants.USDC_ID, constants.FYETH2212, debt.max, 100, debt.dec);

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

    function testAddCollateral() public {
        // Open
        (PositionId positionId, ModifyCostResult memory result) = _openPosition(2 ether, 800e6);

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2 ether, quoteDecimals, "open openQuantity");
        assertApproxEqAbsDecimal(
            position.openCost, 1402.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "open openCost"
        );
        assertEqDecimal(position.protocolFees, 2.103202e6, quoteDecimals, "open protocolFees");
        assertEqDecimal(position.collateral, 797.896798e6, quoteDecimals, "open collateral");

        _assertNoBalances(trader, "trader");

        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertEqDecimal(balances.ink, 2 ether, 18, "ink");
        assertApproxEqAbsDecimal(balances.art, result.underlyingDebt, Yield.BORROWING_BUFFER, quoteDecimals, "art");

        // Add collateral
        result = contangoQuoter.modifyCostForPosition(
            ModifyCostParams({
                positionId: positionId,
                quantity: 0,
                collateral: 100e6,
                collateralSlippage: collateralSlippage
            })
        );
        assertEqDecimal(result.collateralUsed, 100e6, quoteDecimals, "add collateral result.collateralUsed");
        assertEqDecimal(result.cost, 10.497237e6, quoteDecimals, "add collateral result.cost");
        assertEqDecimal(result.debtDelta, -110.497237e6, quoteDecimals, "add collateral result.debtDelta");

        dealAndApprove(address(USDC), trader, uint256(result.collateralUsed), address(contango));
        vm.prank(trader);
        contango.modifyCollateral(
            positionId, result.collateralUsed, uint256(result.cost), trader, result.quoteLendingLiquidity
        );

        position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2 ether, quoteDecimals, "add collateral openQuantity");

        // open cost - cost
        // 1402.134079 - 10.497237 = 1391.636842
        assertApproxEqAbsDecimal(
            position.openCost, 1391.636842e6, Yield.BORROWING_BUFFER, quoteDecimals, "add collateral openCost"
        );

        // 0.15% debtDelta
        // 110.497237 * 0.0015 = 0.165746 fees (rounded up)
        // open fees + fees
        // 2.103202 + 0.165746 = 2.268948 (rounded up)
        assertEqDecimal(position.protocolFees, 2.268948e6, quoteDecimals, "add collateral protocolFees");

        // open collateral + collateral - fee
        // 797.896798 + 100 - 0.165746 = 897.731052
        assertEqDecimal(position.collateral, 897.731052e6, quoteDecimals, "add collateral collateral");

        _assertNoBalances(trader, "trader");
    }

    function testRemoveCollateral() public {
        // Open position
        (PositionId positionId, ModifyCostResult memory result) = _openPosition(2 ether, 800e6);

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2 ether, quoteDecimals, "open openQuantity");
        assertApproxEqAbsDecimal(
            position.openCost, 1402.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "open openCost"
        );
        assertEqDecimal(position.protocolFees, 2.103202e6, quoteDecimals, "open protocolFees");
        assertEqDecimal(position.collateral, 797.896798e6, quoteDecimals, "open collateral");

        _assertNoBalances(trader, "trader");

        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertEqDecimal(balances.ink, 2 ether, 18, "ink");
        assertApproxEqAbsDecimal(balances.art, result.underlyingDebt, Yield.BORROWING_BUFFER, quoteDecimals, "art");

        // Remove collateral
        result = contangoQuoter.modifyCostForPosition(
            ModifyCostParams({
                positionId: positionId,
                quantity: 0,
                collateral: -100e6,
                collateralSlippage: collateralSlippage
            })
        );
        assertEqDecimal(result.collateralUsed, -100e6, quoteDecimals, "remove collateral result.collateralUsed");
        assertApproxEqAbsDecimal(result.cost, -11.731843e6, 1, quoteDecimals, "remove collateral result.cost");
        assertApproxEqAbsDecimal(result.debtDelta, 111.731843e6, 1, quoteDecimals, "remove collateral result.debtDelta");

        vm.prank(trader);
        contango.modifyCollateral(positionId, result.collateralUsed, result.debtDelta.abs(), trader, 0);

        position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2 ether, quoteDecimals, "remove collateral openQuantity");

        // open cost - cost
        // 1402.134079 + 11.731843 = 1413.865922
        assertApproxEqAbsDecimal(
            position.openCost, 1413.865922e6, Yield.BORROWING_BUFFER, quoteDecimals, "remove collateral openCost"
        );

        // 0.15% debtDelta
        // 111.731843 * 0.0015 = 0.167598 fees (rounded up)
        // open fees + fees
        // 2.103202 + 0.167598 = 2.2708 (rounded up)
        assertEqDecimal(position.protocolFees, 2.2708e6, quoteDecimals, "remove collateral protocolFees");

        // open collateral + collateral - fee
        // 797.896798 - 100 - 0.167598 = 697.7292
        assertEqDecimal(position.collateral, 697.7292e6, quoteDecimals, "remove collateral collateral");

        assertEqDecimal(USDC.balanceOf(trader), 100e6, quoteDecimals, "trader USDC balance");
    }

    function _assertNoBalances(address addr, string memory label) private {
        assertEqDecimal(USDC.balanceOf(addr), 0, quoteDecimals, string.concat(label, " USDC dust"));
        assertEqDecimal(WETH.balanceOf(addr), 0, quoteDecimals, string.concat(label, " WETH dust"));
        assertEqDecimal(addr.balance, 0, quoteDecimals, string.concat(label, " ETH dust"));
    }
}
