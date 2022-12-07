//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./WithYieldFixtures.sol";
import {IOraclePoolStub} from "../../../stub/IOraclePoolStub.sol";

contract YieldLowLiquidityETHUSDCTest is
    WithYieldFixtures(constants.yETHUSDC2212, constants.FYETH2212, constants.FYUSDC2212)
{
    using SignedMath for int256;
    using SafeCast for int256;
    using SignedMathLib for int256;
    using YieldUtils for PositionId;
    using TestUtils for *;

    uint256 baseMaxFYTokenOut = 250e18;
    uint256 quoteMaxFYTokenOut = 250_000e6;
    uint256 quoteMaxBaseIn = 226_250e6; // 250000 * .905

    function setUp() public override {
        super.setUp();

        stubPriceWETHUSDC(700e6, 1e6);

        vm.etch(address(yieldInstrument.basePool), getCode(address(new IPoolStub(yieldInstrument.basePool))));
        vm.etch(address(yieldInstrument.quotePool), getCode(address(new IPoolStub(yieldInstrument.quotePool))));

        IPoolStub(address(yieldInstrument.basePool)).setBidAsk(0.945e18, 0.955e18);
        IPoolStub(address(yieldInstrument.quotePool)).setBidAsk(0.895e6, 0.905e6);

        DataTypes.Debt memory debt = cauldron.debt({baseId: constants.USDC_ID, ilkId: constants.FYETH2212});

        uint96 maxDebt = uint96(debt.sum / 1e6) + 10_000; // Set max debt to 10.000 USDC over the current debt, so the available debt is always 10k

        vm.prank(yieldTimelock);
        ICauldronExt(address(cauldron)).setDebtLimits({
            baseId: constants.USDC_ID,
            ilkId: constants.FYETH2212,
            max: maxDebt,
            min: 100, // Set min debt to 100 USDC
            dec: 6
        });

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

        // High liquidity by default, tests will override whatever is necessary
        _setPoolStubLiquidity({pool: yieldInstrument.basePool, borrowing: 1_000 ether, lending: baseMaxFYTokenOut});
        _setPoolStubLiquidity({pool: yieldInstrument.quotePool, borrowing: 1_000_000e6, lending: quoteMaxFYTokenOut});
    }

    // Can open a position with low quote (borrowing) liquidity above min debt (req collateral will grow to compensate)
    function testCreate1() public {
        // Given
        _setPoolStubLiquidity({pool: yieldInstrument.quotePool, borrowing: 100e6, lending: baseMaxFYTokenOut});
        uint256 quantity = 2 ether;

        ModifyCostResult memory result =
            contangoQuoter.openingCostForPosition(OpeningCostParams(symbol, quantity, 0, collateralSlippage));

        assertFalse(result.insufficientLiquidity, "insufficientLiquidity");
        // Flag is false as the req collateral grew to accommodate the low liq
        assertEq(result.baseLendingLiquidity, baseMaxFYTokenOut, "baseLendingLiquidity");
        assertEq(result.quoteLendingLiquidity, 0, "quoteLendingLiquidity");
        assertEqDecimal(result.cost, -1350.496496e6, quoteDecimals, "cost");
        // Collateral is almost the cost, collateral grew to accommodate the low liq
        assertEqDecimal(result.collateralUsed, 1240.148911e6, quoteDecimals, "collateralUsed");

        PositionId positionId = _createPosition(quantity, result);

        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        // Enough debt to consume the available borrowing liquidity
        assertApproxEqAbsDecimal(balances.art, 110.347586e6, Yield.BORROWING_BUFFER, quoteDecimals, "art");

        // Pool is empty
        assertApproxEqAbsDecimal(
            yieldInstrument.quotePool.maxBaseOut(), 1.23891e6, Yield.BORROWING_BUFFER, quoteDecimals, "pool liq"
        );
    }

    // Can't open a position with low quote (borrowing) liquidity below min debt
    function testCreate2() public {
        // Given
        // 100 * 0.895 = 89.5
        _setPoolStubLiquidity({pool: yieldInstrument.quotePool, borrowing: 89.49e6, lending: quoteMaxFYTokenOut});
        uint256 quantity = 2 ether;

        ModifyCostResult memory result =
            contangoQuoter.openingCostForPosition(OpeningCostParams(symbol, quantity, 0, collateralSlippage));

        // The quoter warns that the trade is not possible
        assertTrue(result.insufficientLiquidity, "insufficientLiquidity");
        assertEq(result.baseLendingLiquidity, 0, "baseLendingLiquidity");
        assertEq(result.quoteLendingLiquidity, 0, "quoteLendingLiquidity");

        // The trade is effectively not possible
        vm.expectRevert("Not enough liquidity");
        vm.prank(trader);
        contango.createPosition(
            symbol,
            trader,
            quantity,
            result.cost.slippage(),
            result.collateralUsed.abs(),
            trader,
            result.baseLendingLiquidity
        );
    }

    // Can open a position with low base (lending) liquidity (will mint 1:1)
    function testCreate3() public {
        // Given
        baseMaxFYTokenOut = 1e18;
        _setPoolStubLiquidity({pool: yieldInstrument.basePool, borrowing: 100 ether, lending: baseMaxFYTokenOut});
        uint256 quantity = 2 ether;

        ModifyCostResult memory result =
            contangoQuoter.openingCostForPosition(OpeningCostParams(symbol, quantity, 0, collateralSlippage));

        assertFalse(result.insufficientLiquidity, "insufficientLiquidity");
        assertEq(result.baseLendingLiquidity, baseMaxFYTokenOut, "baseLendingLiquidity");
        assertEq(result.quoteLendingLiquidity, 0, "quoteLendingLiquidity");
        assertEqDecimal(result.cost, -1469.618445e6, quoteDecimals, "cost");
        assertEqDecimal(result.collateralUsed, 525.20468e6, quoteDecimals, "collateralUsed");

        PositionId positionId = _createPosition(quantity, result);

        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertApproxEqAbsDecimal(balances.art, 944.413766e6, Yield.BORROWING_BUFFER, quoteDecimals, "art");

        // Pool is empty
        assertEq(yieldInstrument.basePool.maxFYTokenOut(), 0);
    }

    // Can open a position with no base (lending) liquidity (will mint 1:1)
    function testCreate4() public {
        // Given
        baseMaxFYTokenOut = 0;
        _setPoolStubLiquidity({pool: yieldInstrument.basePool, borrowing: 100 ether, lending: baseMaxFYTokenOut});
        uint256 quantity = 2 ether;

        ModifyCostResult memory result =
            contangoQuoter.openingCostForPosition(OpeningCostParams(symbol, quantity, 0, collateralSlippage));

        assertFalse(result.insufficientLiquidity, "insufficientLiquidity");
        assertEq(result.baseLendingLiquidity, baseMaxFYTokenOut, "baseLendingLiquidity");
        assertEq(result.quoteLendingLiquidity, 0, "quoteLendingLiquidity");
        assertEqDecimal(result.cost, -1501.159744e6, quoteDecimals, "cost");
        assertEqDecimal(result.collateralUsed, 556.781225e6, quoteDecimals, "collateralUsed");

        PositionId positionId = _createPosition(quantity, result);

        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertApproxEqAbsDecimal(balances.art, 944.37852e6, Yield.BORROWING_BUFFER, quoteDecimals, "art");

        // Pool is empty
        assertEq(yieldInstrument.basePool.maxFYTokenOut(), 0);
    }

    // Can open a position when global debt levels are close to the debt ceiling, debt to take is above min debt (req collateral will grow to compensate)
    function testCreate5() public {
        // Given
        uint256 quantity = 200 ether;

        ModifyCostResult memory result =
            contangoQuoter.openingCostForPosition(OpeningCostParams(symbol, quantity, 0, collateralSlippage));

        assertFalse(result.insufficientLiquidity, "insufficientLiquidity");
        // Flag is false as the req collateral grew to accommodate the low liq
        assertEq(result.baseLendingLiquidity, baseMaxFYTokenOut, "baseLendingLiquidity");
        assertEq(result.quoteLendingLiquidity, 0, "quoteLendingLiquidity");
        assertEqDecimal(result.cost, -134926.313844e6, quoteDecimals, "cost");
        // Collateral is close to the cost as we could only borrow up to 10k
        // 134926.313844 - 125066.181991 = 9860.131853
        assertEqDecimal(result.collateralUsed, 125066.181991e6, quoteDecimals, "collateralUsed");

        _createPosition(quantity, result);
    }

    // Can't open a position when global debt levels are close to the debt ceiling, debt to take is below min debt
    function testCreate6() public {
        _openPosition({quantity: 21 ether, collateral: 0});
        DataTypes.Debt memory debt = cauldron.debt(constants.USDC_ID, constants.FYETH2212);
        assertApproxEqAbsDecimal(debt.sum, 10612.983613e6, Yield.BORROWING_BUFFER, quoteDecimals, "total debt");

        uint256 quantity = 20 ether;
        ModifyCostResult memory result =
            contangoQuoter.openingCostForPosition(OpeningCostParams(symbol, quantity, 0, collateralSlippage));

        // The quoter warns that the trade is not possible
        assertTrue(result.insufficientLiquidity, "insufficientLiquidity");
        assertEq(result.baseLendingLiquidity, 0, "baseLendingLiquidity");
        assertEq(result.quoteLendingLiquidity, 0, "quoteLendingLiquidity");

        dealAndApprove(address(USDC), trader, result.collateralUsed.abs(), address(contango));

        // The trade is effectively not possible
        vm.expectRevert("Max debt exceeded");
        vm.prank(trader);
        contango.createPosition(
            symbol,
            trader,
            quantity,
            result.cost.abs(),
            result.collateralUsed.abs(),
            trader,
            result.baseLendingLiquidity
        );
    }

    // Can add more collateral (burn debt) than the available quote (lending) liquidity (will mint 1:1)
    function testCollateralManagement1() public {
        (PositionId positionId,) = _openPosition({quantity: 2 ether, collateral: 800e6});
        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertApproxEqAbsDecimal(balances.art, 602.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "art");

        _setPoolStubLiquidity({pool: yieldInstrument.quotePool, borrowing: 100_000e6, lending: 100e6});
        quoteMaxBaseIn = 90.5e6; // 100 * .905

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: 0,
            collateral: 200e6,
            collateralSlippage: collateralSlippage
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPosition(modifyParams);

        assertFalse(result.insufficientLiquidity, "insufficientLiquidity");
        assertEq(result.quoteLendingLiquidity, quoteMaxBaseIn, "quoteLendingLiquidity");
        assertEq(result.baseLendingLiquidity, 0, "baseLendingLiquidity");

        dealAndApprove(address(USDC), trader, modifyParams.collateral.abs(), address(contango));

        vm.prank(trader);
        contango.modifyCollateral(
            positionId, modifyParams.collateral, result.debtDelta.abs(), trader, result.quoteLendingLiquidity
        );

        balances = cauldron.balances(positionId.toVaultId());
        assertApproxEqAbsDecimal(balances.art, 392.634079e6, Yield.BORROWING_BUFFER, quoteDecimals, "art");
    }

    // Can't withdraw more collateral (take debt) than the available quote (borrowing) liquidity
    function testCollateralManagement2() public {
        (PositionId positionId,) = _openPosition({quantity: 2 ether, collateral: 800e6});
        _setPoolStubLiquidity({pool: yieldInstrument.quotePool, borrowing: 100e6, lending: quoteMaxFYTokenOut});

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: 0,
            collateral: -100.01e6,
            collateralSlippage: collateralSlippage
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPosition(modifyParams);

        // The quoter warns that the trade is not possible
        assertTrue(result.insufficientLiquidity, "insufficientLiquidity");
        assertEq(result.quoteLendingLiquidity, 0, "quoteLendingLiquidity");
        assertEq(result.baseLendingLiquidity, 0, "baseLendingLiquidity");

        vm.expectRevert("Not enough liquidity");
        vm.prank(trader);
        contango.modifyCollateral(positionId, modifyParams.collateral, result.debtDelta.abs(), trader, 0);
    }

    // Can increase a position with low quote (borrowing) liquidity (req collateral will grow to compensate)
    function testIncreasePosition1() public {
        uint256 quantity = 2 ether;
        (PositionId positionId,) = _openPosition({quantity: quantity, collateral: 800e6});
        _setPoolStubLiquidity({pool: yieldInstrument.quotePool, borrowing: 100e6, lending: quoteMaxFYTokenOut});

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: 2 ether,
            collateral: 0,
            collateralSlippage: collateralSlippage
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPosition(modifyParams);

        assertFalse(result.insufficientLiquidity, "insufficientLiquidity");
        assertEq(result.baseLendingLiquidity, baseMaxFYTokenOut - quantity, "baseLendingLiquidity");
        assertEq(result.quoteLendingLiquidity, 0, "lendingLiquidity");
        assertEqDecimal(result.cost, -1350.496496e6, quoteDecimals, "cost");
        // Collateral is almost the cost, collateral grew to accommodate the low liq
        assertEqDecimal(result.collateralUsed, 1240.148911e6, quoteDecimals, "collateralUsed");

        _modifyPosition(positionId, 2 ether, result);

        // Pool is empty
        assertApproxEqAbsDecimal(
            yieldInstrument.quotePool.maxBaseOut(),
            1.23891e6,
            Yield.BORROWING_BUFFER,
            quoteDecimals,
            "quote pool balance"
        );
    }

    // Can increase a position with low quote (borrowing) liquidity below min debt (req collateral will grow to compensate)
    function testIncreasePosition2() public {
        uint256 quantity = 2 ether;
        (PositionId positionId,) = _openPosition({quantity: quantity, collateral: 800e6});
        // 100 * 0.895 = 89.5
        _setPoolStubLiquidity({pool: yieldInstrument.quotePool, borrowing: 89.49e6, lending: quoteMaxFYTokenOut});

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: 2 ether,
            collateral: 0,
            collateralSlippage: collateralSlippage
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPosition(modifyParams);

        assertFalse(result.insufficientLiquidity, "insufficientLiquidity");
        assertEq(result.baseLendingLiquidity, baseMaxFYTokenOut - quantity, "baseLendingLiquidity");
        assertEq(result.quoteLendingLiquidity, 0, "lendingLiquidity");
        assertEqDecimal(result.cost, -1349.262246e6, quoteDecimals, "cost");
        // Collateral is almost the cost, collateral grew to accommodate the low liq
        assertEqDecimal(result.collateralUsed, 1250.669421e6, quoteDecimals, "collateralUsed");

        _modifyPosition(positionId, 2 ether, result);

        // Pool is empty
        assertApproxEqAbsDecimal(
            yieldInstrument.quotePool.maxBaseOut(),
            1.24942e6,
            Yield.BORROWING_BUFFER,
            quoteDecimals,
            "quote pool balance"
        );
    }

    // Can increase a position with low base (lending) liquidity (will mint 1:1)
    function testIncreasePosition3() public {
        uint256 quantity = 2 ether;
        (PositionId positionId,) = _openPosition({quantity: quantity, collateral: 800e6});
        baseMaxFYTokenOut = 1e18;
        _setPoolStubLiquidity({pool: yieldInstrument.basePool, borrowing: 100 ether, lending: baseMaxFYTokenOut});

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: 2 ether,
            collateral: 0,
            collateralSlippage: collateralSlippage
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPosition(modifyParams);

        assertFalse(result.insufficientLiquidity, "insufficientLiquidity");
        assertEq(result.baseLendingLiquidity, baseMaxFYTokenOut, "baseLendingLiquidity");
        assertEq(result.quoteLendingLiquidity, 0, "quoteLendingLiquidity");

        _modifyPosition(positionId, 2 ether, result);

        // Pool is empty
        assertEq(yieldInstrument.basePool.maxFYTokenOut(), 0);
    }

    // Can increase a position with no base (lending) liquidity (will mint 1:1)
    function testIncreasePosition4() public {
        uint256 quantity = 2 ether;
        (PositionId positionId,) = _openPosition({quantity: quantity, collateral: 800e6});
        baseMaxFYTokenOut = 0;
        _setPoolStubLiquidity({pool: yieldInstrument.basePool, borrowing: 100 ether, lending: baseMaxFYTokenOut});

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: 2 ether,
            collateral: 0,
            collateralSlippage: collateralSlippage
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPosition(modifyParams);

        assertFalse(result.insufficientLiquidity, "insufficientLiquidity");
        assertEq(result.baseLendingLiquidity, baseMaxFYTokenOut, "baseLendingLiquidity");
        assertEq(result.quoteLendingLiquidity, 0, "quoteLendingLiquidity");

        _modifyPosition(positionId, 2 ether, result);

        // Pool is empty
        assertEq(yieldInstrument.basePool.maxFYTokenOut(), 0);
    }

    // Can increase a position AND deposit extra collateral with low base (lending) liquidity (will mint 1:1)
    function testIncreasePosition7() public {
        (PositionId positionId,) = _openPosition({quantity: 2 ether, collateral: 800e6});
        baseMaxFYTokenOut = 1e18;
        _setPoolStubLiquidity({pool: yieldInstrument.basePool, borrowing: 100 ether, lending: baseMaxFYTokenOut});

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: 3 ether,
            collateral: 2500e6,
            collateralSlippage: collateralSlippage
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPosition(modifyParams);

        assertFalse(result.insufficientLiquidity, "insufficientLiquidity");
        assertEq(result.baseLendingLiquidity, baseMaxFYTokenOut, "baseLendingLiquidity");
        assertEq(result.quoteLendingLiquidity, 226794.931345e6, "quoteLendingLiquidity");
        assertTrue(result.needsBatchedCall, "needsBatchedCall");

        _modifyPosition(positionId, 3 ether, result);

        // Pool is empty
        assertEq(yieldInstrument.basePool.maxFYTokenOut(), 0);
    }

    // Can increase a position AND deposit extra collateral with no base (lending) liquidity (will mint 1:1)
    function testIncreasePosition8() public {
        (PositionId positionId,) = _openPosition({quantity: 2 ether, collateral: 800e6});
        baseMaxFYTokenOut = 0;
        _setPoolStubLiquidity({pool: yieldInstrument.basePool, borrowing: 100 ether, lending: baseMaxFYTokenOut});

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: 3 ether,
            collateral: 2500e6,
            collateralSlippage: collateralSlippage
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPosition(modifyParams);

        assertFalse(result.insufficientLiquidity, "insufficientLiquidity");
        assertEq(result.baseLendingLiquidity, baseMaxFYTokenOut, "baseLendingLiquidity");
        assertEq(result.quoteLendingLiquidity, 226794.931345e6, "quoteLendingLiquidity");
        assertTrue(result.needsBatchedCall, "needsBatchedCall");

        _modifyPosition(positionId, 3 ether, result);

        // Pool is empty
        assertEq(yieldInstrument.basePool.maxFYTokenOut(), 0);
    }

    // Can increase a position AND deposit extra collateral
    // Low base (lending) liquidity (will mint 1:1)
    // Low quote (lending) liquidity (will mint 1:1)
    function testIncreasePosition9() public {
        (PositionId positionId,) = _openPosition({quantity: 2 ether, collateral: 800e6});
        baseMaxFYTokenOut = 1e18;
        _setPoolStubLiquidity({pool: yieldInstrument.basePool, borrowing: 100 ether, lending: baseMaxFYTokenOut});
        quoteMaxFYTokenOut = 100e6;
        _setPoolStubLiquidity({pool: yieldInstrument.quotePool, borrowing: 1_000_000e6, lending: quoteMaxFYTokenOut});
        quoteMaxBaseIn = 90.5e6; // 100 * .905

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: 3 ether,
            collateral: 2500e6,
            collateralSlippage: collateralSlippage
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPosition(modifyParams);

        assertFalse(result.insufficientLiquidity, "insufficientLiquidity");
        assertEq(result.baseLendingLiquidity, baseMaxFYTokenOut, "baseLendingLiquidity");
        assertEq(result.quoteLendingLiquidity, quoteMaxBaseIn, "quoteLendingLiquidity");
        assertTrue(result.needsBatchedCall, "needsBatchedCall");

        _modifyPosition(positionId, 3 ether, result);

        // Pool is empty
        assertEq(yieldInstrument.basePool.maxFYTokenOut(), 0);
    }

    // Can increase a position AND deposit extra collateral
    // No base (lending) liquidity (will mint 1:1)
    // No quote (lending) liquidity (will mint 1:1)
    function testIncreasePosition10() public {
        (PositionId positionId,) = _openPosition({quantity: 2 ether, collateral: 800e6});
        baseMaxFYTokenOut = 0;
        _setPoolStubLiquidity({pool: yieldInstrument.basePool, borrowing: 100 ether, lending: baseMaxFYTokenOut});
        quoteMaxFYTokenOut = 0;
        _setPoolStubLiquidity({pool: yieldInstrument.quotePool, borrowing: 1_000_000e6, lending: quoteMaxFYTokenOut});
        quoteMaxBaseIn = 0;

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: 3 ether,
            collateral: 2500e6,
            collateralSlippage: collateralSlippage
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPosition(modifyParams);

        assertFalse(result.insufficientLiquidity, "insufficientLiquidity");
        assertEq(result.baseLendingLiquidity, baseMaxFYTokenOut, "baseLendingLiquidity");
        assertEq(result.quoteLendingLiquidity, quoteMaxBaseIn, "quoteLendingLiquidity");
        assertTrue(result.needsBatchedCall, "needsBatchedCall");

        _modifyPosition(positionId, 3 ether, result);

        // Pool is empty
        assertEq(yieldInstrument.basePool.maxFYTokenOut(), 0);
    }

    // Can increase a position when global debt levels are close to the debt ceiling (req collateral will grow to compensate)
    function testIncreasePosition5() public {
        _openPosition({quantity: 19 ether, collateral: 0});

        (PositionId positionId,) = _openPosition({quantity: 2 ether, collateral: 0});
        DataTypes.Debt memory debt = cauldron.debt(constants.USDC_ID, constants.FYETH2212);
        assertApproxEqAbs(debt.max, 10696, Yield.BORROWING_BUFFER * 2, "max debt");
        assertApproxEqAbsDecimal(debt.sum, 10612.983614e6, Yield.BORROWING_BUFFER * 2, quoteDecimals, "total debt");

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: 2 ether,
            collateral: 0,
            collateralSlippage: collateralSlippage
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPosition(modifyParams);

        assertFalse(result.insufficientLiquidity, "insufficientLiquidity");
        assertEq(result.baseLendingLiquidity, baseMaxFYTokenOut - 21 ether, "baseLendingLiquidity");
        assertEq(result.quoteLendingLiquidity, 0 ether, "lendingLiquidity");
        assertApproxEqAbsDecimal(result.cost, -1347.478358e6, Yield.BORROWING_BUFFER * 2, quoteDecimals, "cost");
        // Collateral is almost the cost, as collateral grew to accommodate the low liq
        assertApproxEqAbsDecimal(
            result.collateralUsed, 1265.874945e6, Yield.BORROWING_BUFFER * 2, quoteDecimals, "collateralUsed"
        );

        _modifyPosition(positionId, 2 ether, result);
    }

    // Can increase a position when global debt levels are close to the debt ceiling (req collateral will grow to compensate)
    function testIncreasePosition6() public {
        _openPosition({quantity: 20 ether, collateral: 0});

        (PositionId positionId,) = _openPosition({quantity: 2 ether, collateral: 0});
        DataTypes.Debt memory debt = cauldron.debt(constants.USDC_ID, constants.FYETH2212);
        assertApproxEqAbs(debt.max, 10696, Yield.BORROWING_BUFFER * 2, "max debt");
        assertApproxEqAbsDecimal(debt.sum, 10695.059253e6, Yield.BORROWING_BUFFER, quoteDecimals, "total debt");

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: 2 ether,
            collateral: 0,
            collateralSlippage: collateralSlippage
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPosition(modifyParams);

        assertFalse(result.insufficientLiquidity, "insufficientLiquidity");
        assertFalse(result.needsBatchedCall, "needsBatchedCall");
        assertEq(result.baseLendingLiquidity, baseMaxFYTokenOut - 22 ether, "baseLendingLiquidity");
        assertEq(result.quoteLendingLiquidity, 0 ether, "quoteLendingLiquidity");
        assertApproxEqAbsDecimal(result.cost, -1338.91e6, Yield.BORROWING_BUFFER, quoteDecimals, "cost");
        // Collateral is the cost, as collateral grew to accommodate the low liq
        assertApproxEqAbsDecimal(
            result.collateralUsed, 1338.91e6, Yield.BORROWING_BUFFER, quoteDecimals, "collateralUsed"
        );

        _modifyPosition(positionId, 2 ether, result);
    }

    // Can decrease a position with low quote (lending) liquidity (will mint 1:1)
    function testDecreasePosition1() public {
        uint256 quantity = 2 ether;
        (PositionId positionId,) = _openPosition({quantity: quantity, collateral: 800e6});
        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertApproxEqAbsDecimal(balances.art, 602.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "art");
        quoteMaxFYTokenOut = 100e6;
        _setPoolStubLiquidity({pool: yieldInstrument.quotePool, borrowing: 100_000e6, lending: quoteMaxFYTokenOut});
        quoteMaxBaseIn = 90.5e6; // 100 * .905

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: -0.25 ether,
            collateral: 0,
            collateralSlippage: collateralSlippage
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPosition(modifyParams);

        assertFalse(result.insufficientLiquidity, "insufficientLiquidity");
        assertEq(result.quoteLendingLiquidity, quoteMaxBaseIn, "quoteLendingLiquidity");
        assertEq(result.baseLendingLiquidity, 0, "baseLendingLiquidity");
        assertEqDecimal(result.cost, 174.63875e6, quoteDecimals, "cost");

        _modifyPosition(positionId, -0.25 ether, result);

        assertEqDecimal(
            cauldron.balances(positionId.toVaultId()).art, balances.art - result.cost.abs(), quoteDecimals, "art"
        );

        // Pool is empty
        assertEq(yieldInstrument.quotePool.maxFYTokenOut(), 0);
    }

    // Can decrease a position with no quote (lending) liquidity (will mint 1:1)
    function testDecreasePosition2() public {
        (PositionId positionId,) = _openPosition({quantity: 2 ether, collateral: 800e6});
        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertApproxEqAbsDecimal(balances.art, 602.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "art");
        _setPoolStubLiquidity({pool: yieldInstrument.quotePool, borrowing: 100_000e6, lending: 0});

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: -0.25 ether, // .25 * .945 = 0.23625
            collateral: 0,
            collateralSlippage: collateralSlippage
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPosition(modifyParams);

        assertFalse(result.insufficientLiquidity, "insufficientLiquidity");
        assertEq(result.quoteLendingLiquidity, 0, "quoteLendingLiquidity");
        assertEq(result.baseLendingLiquidity, 0, "baseLendingLiquidity");
        // 0.23625*699 = 165.138750
        assertEqDecimal(result.cost, 165.13875e6, quoteDecimals, "cost");

        _modifyPosition(positionId, -0.25 ether, result);

        assertEqDecimal(
            cauldron.balances(positionId.toVaultId()).art, balances.art - result.cost.abs(), quoteDecimals, "art"
        );

        // Pool is empty
        assertEq(yieldInstrument.quotePool.maxFYTokenOut(), 0);
    }

    // Can't decrease a position with low base (borrowing) liquidity
    function testDecreasePosition3() public {
        (PositionId positionId,) = _openPosition({quantity: 2 ether, collateral: 800e6});
        // 0.25 * 0.945 = 0.23625
        _setPoolStubLiquidity({pool: yieldInstrument.basePool, borrowing: 0.236 ether, lending: 100e18});

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: -0.25 ether,
            collateral: 0,
            collateralSlippage: collateralSlippage
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPosition(modifyParams);

        // The quoter warns that the trade is not possible
        assertTrue(result.insufficientLiquidity, "insufficientLiquidity");
        assertEq(result.quoteLendingLiquidity, 0, "quoteLendingLiquidity");
        assertEq(result.baseLendingLiquidity, 0, "baseLendingLiquidity");

        vm.expectRevert("Not enough liquidity");
        vm.prank(trader);
        contango.modifyPosition(
            positionId,
            modifyParams.quantity,
            result.cost.abs(),
            result.collateralUsed,
            trader,
            result.quoteLendingLiquidity
        );
    }

    // Can decrease a position when debt must to be burnt and the quote (lending) is low (will mint 1:1)
    function testDecreasePosition4() public {
        (PositionId positionId,) = _openPosition({quantity: 2 ether, collateral: 0});
        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertApproxEqAbsDecimal(balances.art, 944.449012e6, Yield.BORROWING_BUFFER, quoteDecimals, "art");

        assertEqDecimal(USDC.balanceOf(trader), 0, quoteDecimals, "trader balance before");

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: -0.5 ether,
            collateral: 0,
            collateralSlippage: collateralSlippage
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPosition(modifyParams);

        assertFalse(result.insufficientLiquidity, "insufficientLiquidity");
        assertEq(result.quoteLendingLiquidity, 227104.726359e6, "quoteLendingLiquidity");
        assertEq(result.baseLendingLiquidity, 0, "baseLendingLiquidity");

        _setPoolStubLiquidity({pool: yieldInstrument.quotePool, borrowing: 100_000e6, lending: 100e6});
        quoteMaxBaseIn = 90.5e6; // 100 * .905
        result = contangoQuoter.modifyCostForPosition(modifyParams);

        assertFalse(result.insufficientLiquidity, "insufficientLiquidity");
        assertEq(result.quoteLendingLiquidity, quoteMaxBaseIn, "quoteLendingLiquidity");
        assertEq(result.baseLendingLiquidity, 0, "baseLendingLiquidity");

        _modifyPosition(positionId, -0.5 ether, result);

        assertEqDecimal(USDC.balanceOf(trader), 0, quoteDecimals, "trader balance after");
        assertEqDecimal(USDC.balanceOf(address(contango)), 0, quoteDecimals, "contango balance after");

        assertEqDecimal(
            cauldron.balances(positionId.toVaultId()).art, balances.art - result.cost.abs(), quoteDecimals, "art"
        );

        // Pool is empty
        assertEq(yieldInstrument.quotePool.maxFYTokenOut(), 0);
    }

    // Can decrease a position with excessQuote when the quote (lending) liquidity is low (will mint 1:1)
    function testDecreasePosition5() public {
        (PositionId positionId,) = _openPosition({quantity: 2 ether, collateral: 800e6});
        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertApproxEqAbsDecimal(balances.art, 602.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "art");
        stubPriceWETHUSDC(1400e6, 1e6);

        assertEqDecimal(USDC.balanceOf(trader), 0, quoteDecimals, "trader balance before");

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: -1 ether,
            collateral: 0,
            collateralSlippage: collateralSlippage
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPosition(modifyParams);

        assertFalse(result.insufficientLiquidity, "insufficientLiquidity");
        assertEq(result.quoteLendingLiquidity, 226794.931345e6, "quoteLendingLiquidity");
        assertEq(result.baseLendingLiquidity, 0, "baseLendingLiquidity");
        assertApproxEqAbsDecimal(
            result.maxCollateral, -868.491282e6, Yield.BORROWING_BUFFER, quoteDecimals, "maxCollateral"
        );
        assertApproxEqAbsDecimal(
            result.collateralUsed, -868.491282e6, Yield.BORROWING_BUFFER, quoteDecimals, "collateralUsed"
        );

        _setPoolStubLiquidity({pool: yieldInstrument.quotePool, borrowing: 100_000e6, lending: 100e6});
        quoteMaxBaseIn = 90.5e6; // 100 * .905
        result = contangoQuoter.modifyCostForPosition(modifyParams);

        assertFalse(result.insufficientLiquidity, "insufficientLiquidity");
        assertEq(result.quoteLendingLiquidity, quoteMaxBaseIn, "quoteLendingLiquidity");
        assertEq(result.baseLendingLiquidity, 0, "baseLendingLiquidity");
        assertApproxEqAbsDecimal(
            result.maxCollateral, -830.250341e6, Yield.BORROWING_BUFFER, quoteDecimals, "maxCollateral"
        );
        // Collateral to get is lower as I didn't recovered too much interest from lending on the pool
        assertApproxEqAbsDecimal(
            result.collateralUsed, -830.250341e6, Yield.BORROWING_BUFFER, quoteDecimals, "collateralUsed"
        );

        _modifyPosition(positionId, -1 ether, result);

        assertEqDecimal(USDC.balanceOf(trader), result.collateralUsed.abs(), quoteDecimals, "trader balance after");
        assertEqDecimal(USDC.balanceOf(address(contango)), 0, quoteDecimals, "contango balance after");

        // Pool is empty
        assertEq(yieldInstrument.quotePool.maxFYTokenOut(), 0);
    }

    // Can close a position with low quote (lending) liquidity (will mint 1:1)
    function testClosePosition1() public {
        (PositionId positionId,) = _openPosition({quantity: 2 ether, collateral: 800e6});
        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertApproxEqAbsDecimal(balances.art, 602.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "art");
        quoteMaxFYTokenOut = 100e6;
        _setPoolStubLiquidity({pool: yieldInstrument.quotePool, borrowing: 100_000e6, lending: quoteMaxFYTokenOut});

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: -2 ether,
            collateral: 0,
            collateralSlippage: collateralSlippage
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPosition(modifyParams);

        assertFalse(result.insufficientLiquidity, "insufficientLiquidity");
        assertEq(result.quoteLendingLiquidity, quoteMaxFYTokenOut, "quoteLendingLiquidity");
        assertEq(result.baseLendingLiquidity, 0, "baseLendingLiquidity");
        assertEqDecimal(result.cost, 1330.61e6, quoteDecimals, "cost");

        _closePosition(positionId);

        // Pool is empty
        assertEq(yieldInstrument.quotePool.maxFYTokenOut(), 0);
    }

    // Can close a position with no quote (lending) liquidity (will mint 1:1)
    function testClosePosition2() public {
        (PositionId positionId,) = _openPosition({quantity: 2 ether, collateral: 800e6});
        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertApproxEqAbsDecimal(balances.art, 602.134079e6, Yield.BORROWING_BUFFER, quoteDecimals, "art");
        quoteMaxFYTokenOut = 0;
        _setPoolStubLiquidity({pool: yieldInstrument.quotePool, borrowing: 100_000e6, lending: quoteMaxFYTokenOut});

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: -2 ether,
            collateral: 0,
            collateralSlippage: collateralSlippage
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPosition(modifyParams);

        assertFalse(result.insufficientLiquidity, "insufficientLiquidity");
        assertEq(result.quoteLendingLiquidity, quoteMaxFYTokenOut, "quoteLendingLiquidity");
        assertEq(result.baseLendingLiquidity, 0, "baseLendingLiquidity");
        assertEqDecimal(result.cost, 1321.11e6, quoteDecimals, "cost");

        _closePosition(positionId);

        // Pool is empty
        assertEq(yieldInstrument.quotePool.maxFYTokenOut(), 0);
    }

    // Can't close a position with low base (borrowing) liquidity
    function testClosePosition3() public {
        (PositionId positionId,) = _openPosition({quantity: 2 ether, collateral: 800e6});
        // 2 * 0.945 = 1.89
        _setPoolStubLiquidity({pool: yieldInstrument.basePool, borrowing: 1.889 ether, lending: 100e18});

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: -2 ether,
            collateral: 0,
            collateralSlippage: collateralSlippage
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPosition(modifyParams);

        // The quoter warns that the trade is not possible
        assertTrue(result.insufficientLiquidity, "insufficientLiquidity");
        assertEq(result.quoteLendingLiquidity, 0, "quoteLendingLiquidity");
        assertEq(result.baseLendingLiquidity, 0, "baseLendingLiquidity");

        vm.expectRevert("Not enough liquidity");
        vm.prank(trader);
        contango.modifyPosition(
            positionId,
            modifyParams.quantity,
            result.cost.abs(),
            result.collateralUsed,
            trader,
            result.quoteLendingLiquidity
        );
    }
}
