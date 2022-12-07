//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./WithYieldFixtures.sol";
import {IOraclePoolStub} from "../../../stub/IOraclePoolStub.sol";

contract YieldPositionActionsETHUSDCTest is
    WithYieldFixtures(constants.yETHUSDC2212, constants.FYETH2212, constants.FYUSDC2212)
{
    using SignedMath for int256;
    using SafeCast for int256;
    using SignedMathLib for int256;
    using YieldUtils for PositionId;
    using TestUtils for *;

    constructor() {
        collateralSlippage = 0;
    }

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

    function testOpen() public {
        ModifyCostResult memory result = contangoQuoter.openingCostForPosition(
            OpeningCostParams({
                symbol: symbol,
                quantity: 2 ether,
                collateral: 800e6,
                collateralSlippage: collateralSlippage
            })
        );
        assertEqDecimal(result.cost, -1402.134078e6, quoteDecimals, "open result.cost");
        assertEqDecimal(result.collateralUsed, 800e6, quoteDecimals, "open result.collateralUsed");
        assertEqDecimal(result.fee, 2.103202e6, quoteDecimals, "open result.fee");

        dealAndApprove(address(USDC), trader, 800e6, address(contango));

        vm.prank(trader);
        PositionId positionId = contango.createPosition({
            symbol: symbol,
            trader: trader,
            quantity: 2 ether,
            limitCost: result.cost.slippage(),
            collateral: 800e6,
            payer: trader,
            lendingLiquidity: HIGH_LIQUIDITY
        });

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2 ether, quoteDecimals, "openQuantity");
        assertApproxEqAbsDecimal(position.openCost, 1402.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "openCost");
        assertEqDecimal(position.protocolFees, 2.103202e6, quoteDecimals, "protocolFees");
        assertApproxEqAbsDecimal(position.collateral, 797.896798e6, Yield.BORROWING_BUFFER, quoteDecimals, "collateral");
        assertEq(position.maturity, constants.MATURITY_2212);
        assertEq(address(position.feeModel), address(feeModel));

        _assertNoBalances(trader, "trader");
    }

    function testIncrease() public {
        // Open
        (PositionId positionId, ModifyCostResult memory result) = _openPosition(2 ether, 800e6);

        // Increase
        assertEqDecimal(result.underlyingDebt, 602.134078e6, quoteDecimals, "open result.underlyingDebt");

        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertEqDecimal(balances.ink, 2 ether, baseDecimals, "ink");
        assertApproxEqAbsDecimal(balances.art, 602.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "art");

        result = contangoQuoter.modifyCostForPosition(
            ModifyCostParams({
                positionId: positionId,
                quantity: 2 ether,
                collateral: 800e6,
                collateralSlippage: collateralSlippage
            })
        );
        assertEqDecimal(result.cost, -1402.134078e6, quoteDecimals, "increase result.cost");
        assertEqDecimal(result.fee, 2.103202e6, quoteDecimals, "increase result.fee");

        dealAndApprove(address(USDC), trader, 800e6, address(contango));
        vm.prank(trader);
        contango.modifyPosition({
            positionId: positionId,
            quantity: 2 ether,
            limitCost: result.cost.slippage(),
            collateral: 800e6,
            payerOrReceiver: trader,
            lendingLiquidity: HIGH_LIQUIDITY
        });

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 4 ether, quoteDecimals, "openQuantity");
        assertApproxEqAbsDecimal(
            position.openCost, 2804.268158e6, Yield.BORROWING_BUFFER * 2, quoteDecimals, "openCost"
        );
        assertEqDecimal(position.protocolFees, 4.206404e6, quoteDecimals, "protocolFees");
        assertApproxEqAbsDecimal(
            position.collateral, 1595.793596e6, Yield.BORROWING_BUFFER, quoteDecimals, "collateral"
        );
        assertEq(position.maturity, constants.MATURITY_2212);
        assertEq(address(position.feeModel), address(feeModel));

        _assertNoBalances(trader, "trader");
    }

    function testDecrease() public {
        // Open
        (PositionId positionId, ModifyCostResult memory result) = _openPosition(2 ether, 800e6);

        // Decrease
        assertEqDecimal(result.underlyingDebt, 602.134078e6, quoteDecimals, "open result.underlyingDebt");

        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertEqDecimal(balances.ink, 2 ether, baseDecimals, "ink");
        assertApproxEqAbsDecimal(balances.art, 602.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "art");

        result = contangoQuoter.modifyCostForPosition(
            ModifyCostParams({
                positionId: positionId,
                quantity: -0.5 ether,
                collateral: 0,
                collateralSlippage: collateralSlippage
            })
        );
        assertEqDecimal(result.cost, 364.947513e6, quoteDecimals, "decrease result.cost");
        assertEqDecimal(result.fee, 0.547422e6, quoteDecimals, "decrease result.fee");

        vm.prank(trader);
        contango.modifyPosition({
            positionId: positionId,
            quantity: -0.5 ether,
            limitCost: result.cost.slippage(),
            collateral: 0,
            payerOrReceiver: trader,
            lendingLiquidity: HIGH_LIQUIDITY
        });

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 1.5 ether, quoteDecimals, "openQuantity");
        // openCost - closedCost
        // 1402.134079 - (0.5 * 1402.134079) / 2
        assertApproxEqAbsDecimal(position.openCost, 1051.600559e6, Yield.BORROWING_BUFFER, quoteDecimals, "openCost");
        assertEqDecimal(position.protocolFees, 2.650624e6, quoteDecimals, "protocolFees");
        // collateral increases because we close as much debt as possible and don't remove any equity,
        // therefore recovering more cost than we close
        // collateral - fees + (cost - closedCost)
        // 800 - (2.103202 + 0.547422) + (364.947513 - (0.5 * 1402.134079) / 2)
        assertApproxEqAbsDecimal(position.collateral, 811.763369e6, Yield.BORROWING_BUFFER, quoteDecimals, "collateral");
        assertEq(position.maturity, constants.MATURITY_2212);
        assertEq(address(position.feeModel), address(feeModel));

        _assertNoBalances(trader, "trader");
    }

    function testClose() public {
        // Open
        (PositionId positionId, ModifyCostResult memory result) = _openPosition(2 ether, 800e6);

        // Close
        assertEqDecimal(result.underlyingDebt, 602.134078e6, quoteDecimals, "open result.underlyingDebt");

        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertEqDecimal(balances.ink, 2 ether, baseDecimals, "ink");
        assertApproxEqAbsDecimal(balances.art, 602.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "art");

        result = contangoQuoter.modifyCostForPosition(
            ModifyCostParams({
                positionId: positionId,
                quantity: -2 ether,
                collateral: 0,
                collateralSlippage: collateralSlippage
            })
        );
        assertEqDecimal(result.cost, 1378.312738e6, quoteDecimals, "close result.cost");
        assertEqDecimal(result.fee, 2.06747e6, quoteDecimals, "close result.fee");

        vm.prank(trader);
        contango.modifyPosition({
            positionId: positionId,
            quantity: -2 ether,
            limitCost: result.cost.slippage(),
            collateral: 0,
            payerOrReceiver: trader,
            lendingLiquidity: HIGH_LIQUIDITY
        });

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 0, quoteDecimals, "openQuantity");
        assertEqDecimal(position.openCost, 0, quoteDecimals, "openCost");
        assertEqDecimal(position.protocolFees, 0, quoteDecimals, "protocolFees");
        assertEqDecimal(position.collateral, 0, quoteDecimals, "collateral");
        assertEq(position.maturity, 0);
        assertEq(address(position.feeModel), address(0));

        // collateral + pnl - fees
        // 800 + (-1402.134079 + 1378.312738) - (2.103202 + 2.06747)
        assertApproxEqAbsDecimal(
            USDC.balanceOf(trader), 772.007986e6, Yield.BORROWING_BUFFER, quoteDecimals, "trader USDC balance"
        );
    }

    function testOpenAndCloseLongPositionSimple() public {
        (PositionId positionId,) = _openPosition(2 ether, 800e6);

        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertEqDecimal(balances.ink, 2 ether, baseDecimals, "ink");
        assertApproxEqAbsDecimal(balances.art, 602.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "art");

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(position.openCost, 1402.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "openCost");
        assertApproxEqAbsDecimal(position.collateral, 797.896798e6, Yield.BORROWING_BUFFER, quoteDecimals, "collateral");

        _closePosition(positionId);
    }

    function testCanNotOpenRightAboveMaxCollateral() public {
        ModifyCostResult memory result =
            contangoQuoter.openingCostForPosition(OpeningCostParams(symbol, 2 ether, 2000e6, collateralSlippage));
        assertEqDecimal(result.collateralUsed, 1249.41e6, quoteDecimals, "collateralUsed");
        uint256 collateral = result.collateralUsed.toUint256() + 2e6;
        dealAndApprove(cauldron.series(quoteSeriesId).fyToken.underlying(), trader, collateral, address(contango));

        vm.expectRevert("Min debt not reached");
        vm.prank(trader);
        contango.createPosition(symbol, trader, 2 ether, 1420e6, collateral, trader, HIGH_LIQUIDITY);
    }

    // function testOpenAndCloseLongPositionMaxCollateral() public {
    //     (PositionId positionId, ModifyCostResult memory result) = _openPosition(2 ether, 2000e6);
    //     assertEqDecimal(result.collateralUsed, 1248.16059e6, quoteDecimals, "collateralUsed");

    //     DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
    //     assertEqDecimal(balances.ink, 2 ether, baseDecimals, "ink");
    //     assertApproxEqAbsDecimal(balances.art, 101.395988e6, Yield.BORROWING_BUFFER, quoteDecimals, "art");

    //     Position memory position = contango.position(positionId);
    //     assertEqDecimal(position.openQuantity, 2 ether, baseDecimals, "openQuantity");
    //     assertEqDecimal(position.openCost, 1349.556578e6,6, "openCost");
    //     assertApproxEqAbsDecimal(position.collateral, 1246.136255e6, Yield.BORROWING_BUFFER, quoteDecimals, "collateral");
    //     assertEqDecimal(position.protocolFees, 2.024335e6, quoteDecimals, "fees");

    //     _closePosition(positionId);
    // }

    function testOpenAndCloseLongPositionFullCollateral() public {
        uint256 collateral = 10_000e6;
        dealAndApprove(cauldron.series(quoteSeriesId).fyToken.underlying(), trader, collateral, address(contango));

        vm.prank(trader);
        PositionId positionId =
            contango.createPosition(symbol, trader, 2 ether, 1420e6, collateral, trader, HIGH_LIQUIDITY);

        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertEqDecimal(balances.ink, 2 ether, baseDecimals, "ink");
        assertEq(balances.art, 0, "art");

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(position.openCost, 1338.91e6, Yield.BORROWING_BUFFER, quoteDecimals, "openCost");
        assertApproxEqAbsDecimal(
            position.collateral, 1336.901635e6, Yield.BORROWING_BUFFER, quoteDecimals, "collateral"
        );
        assertEqDecimal(position.protocolFees, 2.008365e6, quoteDecimals, "fees");

        assertEq(
            USDC.balanceOf(trader), collateral - uint256(position.collateral) - position.protocolFees, "user balance"
        );
    }

    function testOpenReduceAndCloseLongPosition() public {
        (PositionId positionId,) = _openPosition(2 ether, 800e6);

        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertEqDecimal(balances.ink, 2 ether, baseDecimals, "ink");
        assertApproxEqAbsDecimal(balances.art, 602.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "art");

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(position.openCost, 1402.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "openCost");
        assertApproxEqAbsDecimal(position.collateral, 797.896798e6, Yield.BORROWING_BUFFER, quoteDecimals, "collateral");
        assertEqDecimal(position.protocolFees, 2.103202e6, quoteDecimals, "fees");

        // Reduce position
        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: -0.25 ether,
            collateral: 0,
            collateralSlippage: collateralSlippage
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPosition(modifyParams);
        assertEq(result.collateralUsed, 0, "collateralUsed");
        assertEqDecimal(result.cost, 182.473756e6, quoteDecimals, "cost");

        _modifyPosition(positionId, modifyParams.quantity, result);

        balances = cauldron.balances(positionId.toVaultId());
        assertEqDecimal(balances.ink, 1.75 ether, baseDecimals, "ink");
        assertApproxEqAbsDecimal(balances.art, 419.660323e6, Yield.BORROWING_BUFFER, quoteDecimals, "art");

        position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 1.75 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(position.openCost, 1226.867319e6, Yield.BORROWING_BUFFER, quoteDecimals, "openCost");
        assertApproxEqAbsDecimal(position.collateral, 804.830083e6, Yield.BORROWING_BUFFER, quoteDecimals, "collateral");
        assertEqDecimal(position.protocolFees, 2.376913e6, quoteDecimals, "fees");

        _closePosition(positionId);
    }

    function testOpenReduceWithdrawSomeClosedFundsAndCloseLongPosition() public {
        (PositionId positionId,) = _openPosition(2 ether, 800e6);

        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertEqDecimal(balances.ink, 2 ether, baseDecimals, "ink");
        assertApproxEqAbsDecimal(balances.art, 602.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "art");

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(position.openCost, 1402.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "openCost");
        assertApproxEqAbsDecimal(position.collateral, 797.896798e6, Yield.BORROWING_BUFFER, quoteDecimals, "collateral");
        assertEqDecimal(position.protocolFees, 2.103202e6, quoteDecimals, "fees");

        // Reduce position
        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: -0.25 ether,
            collateral: -100e6, // Withdraw some of the proceeds of the reduction
            collateralSlippage: collateralSlippage
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPosition(modifyParams);
        assertEqDecimal(result.spotCost, 174.75e6, quoteDecimals, "spotCost");
        assertEqDecimal(result.collateralUsed, -100e6, quoteDecimals, "collateralUsed");
        assertEqDecimal(result.cost, 171.976519e6, quoteDecimals, "cost");

        _modifyPosition(positionId, modifyParams.quantity, result);

        uint256 traderBalance = USDC.balanceOf(trader);
        assertEq(traderBalance, uint256(-result.collateralUsed), "trader balance");
        assertEq(USDC.balanceOf(address(contango)), 0, "contango balance");

        balances = cauldron.balances(positionId.toVaultId());
        assertEqDecimal(balances.ink, 1.75 ether, baseDecimals, "ink");
        assertApproxEqAbsDecimal(balances.art, 530.15756e6, Yield.BORROWING_BUFFER, quoteDecimals, "art");

        position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 1.75 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(position.openCost, 1226.867319e6, Yield.BORROWING_BUFFER, quoteDecimals, "openCost");
        assertApproxEqAbsDecimal(position.collateral, 694.348592e6, Yield.BORROWING_BUFFER, quoteDecimals, "collateral");
        assertEqDecimal(position.protocolFees, 2.361167e6, quoteDecimals, "fees");

        _closePosition(positionId);
    }

    function testOpenReduceWithdrawAllCollateralAndCloseLongPosition() public {
        (PositionId positionId,) = _openPosition(2 ether, 800e6);

        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertEqDecimal(balances.ink, 2 ether, baseDecimals, "ink");
        assertApproxEqAbsDecimal(balances.art, 602.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "art");

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(position.openCost, 1402.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "openCost");
        assertApproxEqAbsDecimal(position.collateral, 797.896798e6, Yield.BORROWING_BUFFER, quoteDecimals, "collateral");
        assertEqDecimal(position.protocolFees, 2.103202e6, quoteDecimals, "fees");

        // Reduce position
        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: -0.25 ether,
            collateral: 0,
            collateralSlippage: collateralSlippage
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPosition(modifyParams);

        assertApproxEqAbsDecimal(
            result.minCollateral, -366.281874e6, Yield.BORROWING_BUFFER, quoteDecimals, "minCollateral 1"
        );
        modifyParams.collateral = result.minCollateral;
        result = contangoQuoter.modifyCostForPosition(modifyParams);

        assertEqDecimal(result.cost, 141.540954e6, quoteDecimals, "result.cost");
        assertEqDecimal(result.financingCost, 23.597796e6, quoteDecimals, "result.financingCost");
        assertEqDecimal(result.fee, 0.58482e6, quoteDecimals, "result.fee");

        // 1402.134079 * 0.875 + 23.597796 = 1,250.46511425
        uint256 expectedCostAfterDecrease = ((position.openCost * 0.875e18) / 1e18) + uint256(result.financingCost);

        _modifyPosition(positionId, modifyParams.quantity, result);

        uint256 traderBalance = USDC.balanceOf(trader);
        assertEq(traderBalance, uint256(-result.minCollateral), "trader balance");
        assertEq(USDC.balanceOf(address(contango)), 0, "contango balance");

        balances = cauldron.balances(positionId.toVaultId());
        assertEqDecimal(balances.ink, 1.75 ether, baseDecimals, "ink");
        assertApproxEqAbsDecimal(balances.art, 826.874999e6, Yield.BORROWING_BUFFER, quoteDecimals, "art");
        assertApproxEqAbs(cauldron.level(positionId.toVaultId()), 0, 2);

        position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 1.75 ether, baseDecimals, "openQuantity");
        assertEq(position.openCost, expectedCostAfterDecrease, "openCost");
        assertApproxEqAbsDecimal(position.collateral, 420.902093e6, Yield.BORROWING_BUFFER, quoteDecimals, "collateral");

        // previous: 2.103202
        // result.fee: 0.584820
        // expected total: ~2.688022
        assertEqDecimal(position.protocolFees, 2.688023e6, quoteDecimals, "fees");

        _closePosition(positionId);
    }

    function testOpenReduceWithdrawAllCollateralAndProfitsAndCloseLongPosition() public {
        (PositionId positionId,) = _openPosition(2 ether, 800e6);

        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertEqDecimal(balances.ink, 2 ether, baseDecimals, "ink");
        assertApproxEqAbsDecimal(balances.art, 602.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "art");

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(position.openCost, 1402.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "openCost");
        assertApproxEqAbsDecimal(position.collateral, 797.896798e6, Yield.BORROWING_BUFFER, quoteDecimals, "collateral");
        assertEqDecimal(position.protocolFees, 2.103202e6, quoteDecimals, "fees");

        stubPriceWETHUSDC(2000e6, 1e6);

        assertEq(USDC.balanceOf(trader), 0, "trader balance");

        // Reduce position
        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: -0.25 ether,
            collateral: type(int256).min,
            collateralSlippage: collateralSlippage
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPosition(modifyParams);

        assertEqDecimal(result.cost, 287.425329e6, quoteDecimals, "cost");
        assertApproxEqAbsDecimal(
            result.collateralUsed, -2047.791249e6, Yield.BORROWING_BUFFER, quoteDecimals, "collateralUsed"
        );
        assertApproxEqAbsDecimal(
            result.minCollateral, -2047.791249e6, Yield.BORROWING_BUFFER, quoteDecimals, "minCollateral"
        );
        assertApproxEqAbsDecimal(
            result.maxCollateral, -17.832409e6, Yield.BORROWING_BUFFER, quoteDecimals, "maxCollateral"
        );
        assertApproxEqAbsDecimal(result.debtDelta, 1760.36592e6, Yield.BORROWING_BUFFER, quoteDecimals, "debtDelta");
        assertEqDecimal(result.financingCost, 184.838421e6, quoteDecimals, "financingCost");
        assertTrue(result.needsBatchedCall);

        uint256 expectedCostAfterDecrease = ((position.openCost * 0.875e18) / 1e18) + uint256(result.financingCost);

        _modifyPosition(positionId, modifyParams.quantity, result);

        assertEq(USDC.balanceOf(trader), uint256(-result.collateralUsed), "trader balance");
        assertEq(USDC.balanceOf(address(contango)), 0, "contango balance");

        balances = cauldron.balances(positionId.toVaultId());
        assertEqDecimal(balances.ink, 1.75 ether, baseDecimals, "ink");
        assertApproxEqAbsDecimal(balances.art, 2362.499999e6, Yield.BORROWING_BUFFER, quoteDecimals, "art");
        assertApproxEqAbs(cauldron.level(positionId.toVaultId()), 0, 2);

        position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 1.75 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(position.openCost, 1411.70574e6, Yield.BORROWING_BUFFER, quoteDecimals, "openCost");
        assertEq(position.openCost, expectedCostAfterDecrease, "openCost (calculated)");
        assertApproxEqAbsDecimal(
            position.collateral, -956.246406e6, Yield.BORROWING_BUFFER, quoteDecimals, "collateral"
        );
        assertEqDecimal(position.protocolFees, 5.452147e6, quoteDecimals, "fees");

        _closePosition(positionId);
    }

    function testCanNotReducePositionWithoutWithdrawingExcessQuote() public {
        (PositionId positionId,) = _openPosition(2 ether, 800e6);
        clearBalance(trader, USDC);

        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertEqDecimal(balances.ink, 2 ether, baseDecimals, "ink");
        assertApproxEqAbsDecimal(balances.art, 602.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "art");

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(position.openCost, 1402.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "openCost");
        assertApproxEqAbsDecimal(position.collateral, 797.896798e6, Yield.BORROWING_BUFFER, quoteDecimals, "collateral");

        // Reduce position
        ModifyCostResult memory result =
            contangoQuoter.modifyCostForPosition(ModifyCostParams(positionId, -1.25 ether, 0, collateralSlippage));
        assertLt(result.maxCollateral, 0, "excessQuote");

        vm.expectRevert("Result below zero");
        vm.prank(trader);
        contango.modifyPosition(positionId, -1.25 ether, result.cost.abs(), 0, trader, result.quoteLendingLiquidity);
    }

    function testOpenReduceDepositAndCloseLongPosition() public {
        (PositionId positionId,) = _openPosition(2 ether, 800e6);

        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertEqDecimal(balances.ink, 2 ether, baseDecimals, "ink");
        assertApproxEqAbsDecimal(balances.art, 602.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "art");

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(position.openCost, 1402.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "openCost");
        assertApproxEqAbsDecimal(position.collateral, 797.896798e6, Yield.BORROWING_BUFFER, quoteDecimals, "collateral");
        assertEqDecimal(position.protocolFees, 2.103202e6, quoteDecimals, "fees");

        // Reduce position
        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: -0.25 ether,
            collateral: 100e6,
            collateralSlippage: collateralSlippage
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPosition(modifyParams);
        assertEqDecimal(result.collateralUsed, 100e6, quoteDecimals, "collateralUsed");
        assertEqDecimal(result.cost, 192.970994e6, quoteDecimals, "cost");

        _modifyPosition(positionId, modifyParams.quantity, result);

        uint256 traderBalance = USDC.balanceOf(trader);
        assertEq(traderBalance, 0, "trader balance");
        assertEq(USDC.balanceOf(address(contango)), 0, "contango balance");

        balances = cauldron.balances(positionId.toVaultId());
        assertEqDecimal(balances.ink, 1.75 ether, baseDecimals, "ink");
        assertApproxEqAbsDecimal(balances.art, 309.163085e6, Yield.BORROWING_BUFFER, quoteDecimals, "art");

        position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 1.75 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(position.openCost, 1226.867319e6, Yield.BORROWING_BUFFER, quoteDecimals, "openCost");
        assertApproxEqAbsDecimal(position.collateral, 915.311575e6, Yield.BORROWING_BUFFER, quoteDecimals, "collateral");
        assertEqDecimal(position.protocolFees, 2.392659e6, quoteDecimals, "fees");

        _closePosition(positionId);
    }

    function testOpenReduceDepositMaxAndCloseLongPosition() public {
        (PositionId positionId,) = _openPosition(2 ether, 800e6);

        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertEqDecimal(balances.ink, 2 ether, baseDecimals, "ink");
        assertApproxEqAbsDecimal(balances.art, 602.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "art");

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(position.openCost, 1402.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "openCost");
        assertApproxEqAbsDecimal(position.collateral, 797.896798e6, Yield.BORROWING_BUFFER, quoteDecimals, "collateral");
        assertEqDecimal(position.protocolFees, 2.103202e6, quoteDecimals, "fees");

        // Reduce position
        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: -0.25 ether,
            collateral: 0,
            collateralSlippage: collateralSlippage
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPosition(modifyParams);

        assertApproxEqAbsDecimal(
            result.maxCollateral, 289.292591e6, Yield.BORROWING_BUFFER, quoteDecimals, "maxCollateral"
        );

        modifyParams.collateral = result.maxCollateral;
        result = contangoQuoter.modifyCostForPosition(modifyParams);

        _modifyPosition(positionId, modifyParams.quantity, result);

        uint256 traderBalance = USDC.balanceOf(trader);
        assertEq(traderBalance, 0, "trader balance");
        assertEq(USDC.balanceOf(address(contango)), 0, "contango balance");

        balances = cauldron.balances(positionId.toVaultId());
        assertEqDecimal(balances.ink, 1.75 ether, baseDecimals, "ink");
        assertApproxEqAbsDecimal(balances.art, 100.000001e6, Yield.BORROWING_BUFFER, quoteDecimals, "art");

        position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 1.75 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(position.openCost, 1226.867319e6, Yield.BORROWING_BUFFER, quoteDecimals, "openCost");
        assertApproxEqAbsDecimal(
            position.collateral, 1124.444853e6, Yield.BORROWING_BUFFER, quoteDecimals, "collateral"
        );
        assertEqDecimal(position.protocolFees, 2.422465e6, quoteDecimals, "fees");

        _closePosition(positionId);
    }

    function testCanNotReduceAndDepositTooMuch() public {
        (PositionId positionId,) = _openPosition(2 ether, 800e6);

        // Reduce position
        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: -0.25 ether,
            collateral: 0,
            collateralSlippage: collateralSlippage
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPosition(modifyParams);

        assertApproxEqAbsDecimal(
            result.maxCollateral, 289.292591e6, Yield.BORROWING_BUFFER, quoteDecimals, "maxCollateral"
        );

        int256 collateral = result.maxCollateral + 2;

        dealAndApprove(address(USDC), trader, uint256(collateral), address(contango));

        vm.expectRevert("Min debt not reached");
        vm.prank(trader);
        contango.modifyPosition(
            positionId, modifyParams.quantity, result.cost.abs(), collateral, trader, result.quoteLendingLiquidity
        );
    }

    function testOpenIncreaseNoCollateralAndCloseLongPosition() public {
        (PositionId positionId,) = _openPosition(2 ether, 800e6);

        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertEqDecimal(balances.ink, 2 ether, baseDecimals, "ink");
        assertApproxEqAbsDecimal(balances.art, 602.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "art");

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(position.openCost, 1402.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "openCost");
        assertApproxEqAbsDecimal(position.collateral, 797.896798e6, Yield.BORROWING_BUFFER, quoteDecimals, "collateral");

        // Increase position
        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: 0.25 ether,
            collateral: 0,
            collateralSlippage: collateralSlippage
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPosition(modifyParams);

        assertEq(result.collateralUsed, 0, "collateralUsed");

        dealAndApprove(address(USDC), trader, uint256(result.collateralUsed), address(contango));
        _modifyPosition(positionId, modifyParams.quantity, result);

        balances = cauldron.balances(positionId.toVaultId());
        assertEqDecimal(balances.ink, 2.25 ether, baseDecimals, "ink");
        assertApproxEqAbsDecimal(balances.art, 789.132683e6, Yield.BORROWING_BUFFER * 2, quoteDecimals, "art");

        position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2.25 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(
            position.openCost, 1589.132683e6, Yield.BORROWING_BUFFER * 2, quoteDecimals, "openCost"
        );
        assertApproxEqAbsDecimal(position.collateral, 797.6163e6, Yield.BORROWING_BUFFER, quoteDecimals, "collateral");

        _closePosition(positionId);
    }

    function testOpenIncreaseDepositAndCloseLongPosition() public {
        (PositionId positionId,) = _openPosition(2 ether, 800e6);

        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertEqDecimal(balances.ink, 2 ether, baseDecimals, "ink");
        assertApproxEqAbsDecimal(balances.art, 602.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "art");

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(position.openCost, 1402.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "openCost");
        assertApproxEqAbsDecimal(position.collateral, 797.896798e6, Yield.BORROWING_BUFFER, quoteDecimals, "collateral");

        // Increase position
        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: 0.25 ether,
            collateral: 100e6,
            collateralSlippage: collateralSlippage
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPosition(modifyParams);

        dealAndApprove(address(USDC), trader, uint256(result.collateralUsed), address(contango));
        _modifyPosition(positionId, modifyParams.quantity, result);

        balances = cauldron.balances(positionId.toVaultId());
        assertEqDecimal(balances.ink, 2.25 ether, baseDecimals, "ink");
        assertApproxEqAbsDecimal(balances.art, 677.400839e6, Yield.BORROWING_BUFFER * 2, quoteDecimals, "art");

        position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2.25 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(
            position.openCost, 1577.400839e6, Yield.BORROWING_BUFFER * 2, quoteDecimals, "openCost"
        );
        assertApproxEqAbsDecimal(position.collateral, 897.633897e6, Yield.BORROWING_BUFFER, quoteDecimals, "collateral");

        _closePosition(positionId);
    }

    function testOpenIncreaseDepositMaxAndCloseLongPosition() public {
        (PositionId positionId,) = _openPosition(2 ether, 800e6);

        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertEqDecimal(balances.ink, 2 ether, baseDecimals, "ink");
        assertApproxEqAbsDecimal(balances.art, 602.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "art");

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(position.openCost, 1402.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "openCost");
        assertApproxEqAbsDecimal(position.collateral, 797.896798e6, Yield.BORROWING_BUFFER, quoteDecimals, "collateral");
        assertEqDecimal(position.protocolFees, 2.103202e6, quoteDecimals, "protocolFees");

        // Increase position
        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: 0.25 ether,
            collateral: 10000e6,
            collateralSlippage: collateralSlippage
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPosition(modifyParams);

        assertEqDecimal(result.cost, -119.661013e6, quoteDecimals, "cost");
        assertApproxEqAbsDecimal(
            result.collateralUsed, 621.795091e6, Yield.BORROWING_BUFFER, quoteDecimals, "collateralUsed"
        );
        assertApproxEqAbsDecimal(
            result.minCollateral, -245.223124e6, Yield.BORROWING_BUFFER, quoteDecimals, "minCollateral"
        );
        assertApproxEqAbsDecimal(
            result.maxCollateral, 621.795091e6, Yield.BORROWING_BUFFER, quoteDecimals, "maxCollateral"
        );
        assertApproxEqAbsDecimal(result.debtDelta, -502.134078e6, Yield.BORROWING_BUFFER, quoteDecimals, "debtDelta");
        assertEqDecimal(result.financingCost, -47.702737e6, quoteDecimals, "financingCost");
        assertEqDecimal(result.fee, 1.004247e6, quoteDecimals, "fee");
        assertTrue(result.needsBatchedCall);

        assertEq(result.collateralUsed, result.maxCollateral, "collateral");

        dealAndApprove(address(USDC), trader, uint256(result.collateralUsed), address(contango));
        _modifyPosition(positionId, modifyParams.quantity, result);

        balances = cauldron.balances(positionId.toVaultId());
        assertEqDecimal(balances.ink, 2.25 ether, baseDecimals, "ink");
        assertApproxEqAbsDecimal(balances.art, 100.000001e6, Yield.BORROWING_BUFFER, quoteDecimals, "art");

        position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2.25 ether, baseDecimals, "openQuantity");

        // expected: 1402.134079 + 119.661013 = 1521.795092 (previous cost + result.cost.abs())
        assertApproxEqAbsDecimal(position.openCost, 1521.795092e6, Yield.BORROWING_BUFFER, quoteDecimals, "openCost");
        // expected: 2.103202 + 1.004247 = 3.107449 (previous fees + result.fee)
        assertEqDecimal(position.protocolFees, 3.10745e6, quoteDecimals, "protocolFees 2");
        // expected: 797.896798 + 621.795091 - 1.004247 = 1418.687641
        assertApproxEqAbsDecimal(
            position.collateral, 1418.687641e6, Yield.BORROWING_BUFFER, quoteDecimals, "collateral"
        );

        _closePosition(positionId);
    }

    function testOpenIncreaseWithdrawMaxAndCloseLongPosition() public {
        (PositionId positionId,) = _openPosition(2 ether, 800e6);

        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertEqDecimal(balances.ink, 2 ether, baseDecimals, "ink");
        assertApproxEqAbsDecimal(balances.art, 602.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "art");

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(position.openCost, 1402.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "openCost");
        assertApproxEqAbsDecimal(position.collateral, 797.896798e6, Yield.BORROWING_BUFFER, quoteDecimals, "collateral");

        // Increase position
        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: 0.25 ether,
            collateral: -10_000e6,
            collateralSlippage: collateralSlippage
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPosition(modifyParams);
        // Deal with subtle precision issues right at the edge
        uint256 collateralBuffer = 4;
        modifyParams.collateral = result.collateralUsed + int256(collateralBuffer);
        result = contangoQuoter.modifyCostForPosition(modifyParams);

        assertApproxEqAbsDecimal(result.cost, -215.767796e6, collateralBuffer, quoteDecimals, "cost");
        assertApproxEqAbsDecimal(
            result.collateralUsed,
            -245.223124e6,
            Yield.BORROWING_BUFFER + collateralBuffer,
            quoteDecimals,
            "collateralUsed"
        );
        assertApproxEqAbsDecimal(
            result.minCollateral,
            -245.223124e6,
            Yield.BORROWING_BUFFER + collateralBuffer,
            quoteDecimals,
            "minCollateral"
        );
        assertApproxEqAbsDecimal(
            result.maxCollateral,
            621.795091e6,
            Yield.BORROWING_BUFFER + collateralBuffer,
            quoteDecimals,
            "maxCollateral"
        );
        assertApproxEqAbsDecimal(
            result.debtDelta, 460.99092e6, Yield.BORROWING_BUFFER + collateralBuffer, quoteDecimals, "debtDelta"
        );
        assertApproxEqAbsDecimal(result.financingCost, 48.404046e6, collateralBuffer, quoteDecimals, "financingCost");

        _modifyPosition(positionId, modifyParams.quantity, result);

        assertEq(USDC.balanceOf(trader), uint256(-result.collateralUsed), "trader balance");

        balances = cauldron.balances(positionId.toVaultId());
        assertEqDecimal(balances.ink, 2.25 ether, baseDecimals, "ink");
        // 602.134078 + 460.990920 = 1063.125000
        assertApproxEqAbsDecimal(balances.art, 1063.125e6, Yield.BORROWING_BUFFER, quoteDecimals, "art");
        assertApproxEqAbs(cauldron.level(positionId.toVaultId()), 0, 2);

        position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2.25 ether, baseDecimals, "openQuantity");
        // 1402.134079 + .25 * 0.955 * 701 + 48.404046 = 1617.901875
        assertApproxEqAbsDecimal(position.openCost, 1617.901875e6, Yield.BORROWING_BUFFER, quoteDecimals, "openCost");
        // 797.896798 - 245.223125 = 552.350022 (-fees)
        assertApproxEqAbsDecimal(
            position.collateral, 552.350022e6, Yield.BORROWING_BUFFER + collateralBuffer, quoteDecimals, "collateral"
        );

        _closePosition(positionId);
    }

    function testOpenPositionOnBehalfOfSomeoneElse() public {
        address proxy = address(0x99);

        ModifyCostResult memory result =
            contangoQuoter.openingCostForPosition(OpeningCostParams(symbol, 2 ether, 800e6, collateralSlippage));

        dealAndApprove(
            cauldron.series(quoteSeriesId).fyToken.underlying(),
            proxy,
            result.collateralUsed.toUint256(),
            address(contango)
        );

        vm.prank(proxy);
        PositionId positionId = contango.createPosition(
            symbol,
            trader,
            2 ether,
            result.cost.slippage(),
            result.collateralUsed.toUint256(),
            proxy,
            result.baseLendingLiquidity
        );

        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertEqDecimal(balances.ink, 2 ether, baseDecimals, "ink");
        assertApproxEqAbsDecimal(balances.art, 602.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "art");

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(position.openCost, 1402.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "openCost");
        assertApproxEqAbsDecimal(position.collateral, 797.896798e6, Yield.BORROWING_BUFFER, quoteDecimals, "collateral");

        _closePosition(positionId);
    }

    function _assertNoBalances(address addr, string memory label) private {
        assertEqDecimal(USDC.balanceOf(addr), 0, 6, string.concat(label, " USDC dust"));
        assertEqDecimal(WETH.balanceOf(addr), 0, 6, string.concat(label, " WETH dust"));
        assertEqDecimal(addr.balance, 0, 6, string.concat(label, " ETH dust"));
    }
}
