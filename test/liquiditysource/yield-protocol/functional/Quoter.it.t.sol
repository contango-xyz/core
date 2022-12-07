//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./WithYieldFixtures.sol";

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {ILadle} from "@yield-protocol/vault-v2/contracts/interfaces/ILadle.sol";
import {IOraclePoolStub} from "../../../stub/IOraclePoolStub.sol";

/// @dev refer to https://docs.google.com/spreadsheets/d/1uLKQzLETTHhaYHV9x6yNq1cqU4auhcc-mK-kLkkZd60/edit#gid=0 for detailed calculations
// solhint-disable func-name-mixedcase
contract YieldQuoterTest is WithYieldFixtures(constants.yETHUSDC2212, constants.FYETH2212, constants.FYUSDC2212) {
    using SafeCast for uint256;
    using YieldUtils for *;

    TestQuoter private testQuoter;

    uint256 private baseMaxFYTokenOut = 250e18;
    uint256 private quoteMaxFYTokenOut = 250_000e6;
    uint256 private quoteMaxBaseIn = 226_250e6; // 250000 * .905

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

        testQuoter = new TestQuoter(positionNFT, contangoYield, cauldron, quoter);

        // High liquidity by default, tests will override whatever is necessary
        _setPoolStubLiquidity({pool: yieldInstrument.basePool, borrowing: 1_000 ether, lending: baseMaxFYTokenOut});
        _setPoolStubLiquidity({pool: yieldInstrument.quotePool, borrowing: 1_000_000e6, lending: quoteMaxFYTokenOut});
    }

    function testCreatePositionOpenCost() public {
        // empty account since it's a new position
        DataTypes.Balances memory balances;

        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, 2 ether, 800e6);

        // ETHUSDC: bid 699 / ask 701
        // 2 * 701 = 1402 USDC
        assertEqDecimal(result.spotCost, -1402e6, 6, "result.spotCost");

        assertEqDecimal(result.collateralUsed, 800e6, 6, "result.collateralUsed");

        // how much ETH do we need today (PV) to have 2 ETH at expiry?
        // 2 * 0.955 (ask rate) = 1.91 ETH
        // 1.91 * 701 = 1338.91 (total USDC needed)
        // 1338.91 - 800 (user collateral) = 538.91 (total USDC we need to borrow)
        // how many fUSDC do I need, so that I can acquire 538.91 real USDC?
        // 538.91 / 0.895 (bid rate) = 602.134078 (could be rounded up if underlying protocol precision is greater than quote currency)
        assertApproxEqAbsDecimal(result.underlyingDebt, 602.134078e6, 1, 6, "result.underlyingDebt");
        assertApproxEqAbsDecimal(result.debtDelta, 602.134078e6, 1, 6, "result.debtDelta");

        // sold 602.134078 fUSDC (debtDelta) - borrowed 538.91 USDC
        // 602.134078 - 538.91 = 63.224078
        assertApproxEqAbsDecimal(result.financingCost, 63.224078e6, 1, 6, "result.financingCost");

        // collateral posted 800 + debtDelta 602.134078 = 1402.134078 USDC cost
        assertApproxEqAbsDecimal(result.cost, -1402.134078e6, 1, 6, "result.cost");

        // 2 fETH valued at bid rate 0.945 = 1.89 ETH
        // 1.89 ETH valued at ETHUSD oracle price 700 = 1323 USDC
        assertEqDecimal(result.underlyingCollateral, 1323e6, 6, "result.underlyingCollateral");

        assertEqDecimal(result.liquidationRatio, 1.4e6, 6, "result.liquidationRatio");
        // underlying collateral valued at 1323 USDC
        // after applying min CR (40%): 945 USDC
        // 945 fUSDC can borrow at bid rate 0.895 = 845.775 USDC

        assertEqDecimal(result.minDebt, 100e6, 6, "result.minDebt");

        // swap cost 1338.91 - max borrowing 845.775 = 493.135 USDC min collateral
        assertEqDecimal(result.minCollateral, 493.135e6, 6, "result.minCollateral");
        // full swap payment
        // min debt 100 at bid rate 0.895 = min borrow 89.50 USDC
        // swap cost 1338.91 - min borrow 89.50 = 1249.41 USDC
        assertEqDecimal(result.maxCollateral, 1249.41e6, 6, "result.maxCollateral");

        assertFalse(result.needsBatchedCall, "result.needsBatchedCall");
        assertEq(result.baseLendingLiquidity, baseMaxFYTokenOut, "baseLendingLiquidity");
        assertEq(result.quoteLendingLiquidity, 0, "quoteLendingLiquidity");
        assertFalse(result.insufficientLiquidity, "result.insufficientLiquidity");
    }

    function testIncreasePositionCost() public {
        // values for 2 ETHUSDC with 800 collateral position - taken from testCreatePositionOpenCost() test
        DataTypes.Balances memory balances = DataTypes.Balances({art: 602.134078e6, ink: 2e18});

        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, 0.5 ether, 0);

        // ETHUSDC: bid 699 / ask 701
        // 0.5 * 701 = 350.5 USDC
        assertEqDecimal(result.spotCost, -350.5e6, 6, "result.spotCost");

        assertEqDecimal(result.collateralUsed, 0, 6, "result.collateralUsed");

        // how much ETH do we need today (PV) to have 0.5 ETH at expiry?
        // 0.5 * 0.955 (ask rate) = 0.4775 ETH
        // 0.4775 * 701 = 334.7275 (total USDC we need to borrow)
        // how many fUSDC do I need, so that I can acquire 334.7275 real USDC?
        // 334.7275 / 0.895 (bid rate) = 373.997206 (could be rounded up if underlying protocol precision is greater than quote currency)
        // existing debt + new debt
        // 602.134078 + 373.997206 = 976.131284 USDC
        assertApproxEqAbsDecimal(result.underlyingDebt, 976.131284e6, 1, 6, "result.underlyingDebt");
        assertApproxEqAbsDecimal(result.debtDelta, 373.997206e6, 1, 6, "result.debtDelta");
        assertApproxEqAbsDecimal(result.cost, -373.997206e6, 1, 6, "result.cost");

        // sold fUSDC (debtDelta) - borrowed
        // 373.997206 - 334.7275 = 39.269706
        assertApproxEqAbsDecimal(result.financingCost, 39.269706e6, 1, 6, "result.financingCost");

        // fETH valued at bid rate
        // 2.5 * 0.945 = 2.3625 ETH
        // ETH valued at ETHUSD oracle price
        // 2.3625 * 700 = 1653.75 USDC
        // TODO alfredo - check if haircut should be applied on this valuation and if it should look at bid prices
        assertEqDecimal(result.underlyingCollateral, 1653.75e6, 6, "result.underlyingCollateral");

        assertEqDecimal(result.liquidationRatio, 1.4e6, 6, "result.liquidationRatio");
        // underlying collateral valued at 1653.75 USDC
        // after applying min CR (40%): 1181.25 USDC
        // collateral value - existing debt
        // 1181.25 - 602.134078 = 579.115922 USDC max borrowing
        // fUSDC can borrow at bid rate
        // 579.115922 * 0.895 = 518.30875 USDC remaining borrowing
        assertEqDecimal(result.minDebt, 100e6, 6, "result.minDebt");

        // swap cost - remaining borrowing
        // 334.7275 - 518.30875 = -183.58125
        assertEqDecimal(result.minCollateral, -183.58125e6, 6, "result.minCollateral");
        // full swap payment + repaying existing debt
        // (existing debt - min debt) * ask rate
        // (602.134078 - 100) * 0.905 = 454.431340 USDC existing debt cost
        // swap cost + existing debt cost
        // 334.7275 + 454.431340 = 789.15884 USDC
        assertEqDecimal(result.maxCollateral, 789.15884e6, 6, "result.maxCollateral");

        assertFalse(result.needsBatchedCall, "result.needsBatchedCall");
        assertEq(result.baseLendingLiquidity, baseMaxFYTokenOut, "baseLendingLiquidity");
        assertEq(result.quoteLendingLiquidity, 0, "quoteLendingLiquidity");
        assertFalse(result.insufficientLiquidity, "result.insufficientLiquidity");

        _assertLiquidity(result);
    }

    function testDecreasePositionCost() public {
        // values for 2 ETHUSDC with 800 collateral position - taken from testCreatePositionOpenCost() test
        DataTypes.Balances memory balances = DataTypes.Balances({art: 602.134078e6, ink: 2e18});

        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, -0.5 ether, 0);

        // ETHUSDC: bid 699 / ask 701
        // 0.5 * 699 = 349.50
        assertEqDecimal(result.spotCost, 349.5e6, 6, "result.spotCost");

        assertEqDecimal(result.collateralUsed, 0, 6, "result.collateralUsed");

        // 0.5 * 0.945 (bid rate) = 0.4725 ETH
        // 0.4725 * 699 = 330.2775 (total USDC received)
        // how many fUSDC can I burn with 330.2775 USDC?
        // 330.2775 / 0.905 (ask rate) = 364.947513 fUSDC (could be rounded up if underlying protocol precision is greater than quote currency)
        // existing debt 602.134078 - burnt debt 364.947513 = 237.186565 fUSDC
        assertApproxEqAbsDecimal(result.underlyingDebt, 237.186565e6, 1, 6, "result.underlyingDebt");
        assertApproxEqAbsDecimal(result.debtDelta, -364.947513e6, 1, 6, "result.debtDelta");

        // bought 364.947513 fUSDC (debtDelta) - swapped 330.2775 USDC
        // 330.2775 - 364.947513 = -34.670013
        assertEqDecimal(result.financingCost, -34.670013e6, 6, "result.financingCost");

        // debtDelta 364.947513 USDC cost
        assertEqDecimal(result.cost, 364.947513e6, 6, "result.cost");

        // 1.5 fETH valued at bid rate 0.945 = 1.4175 ETH
        // 1.4175 ETH valued at ETHUSD oracle price 700 = 992.25 USDC
        assertEqDecimal(result.underlyingCollateral, 992.25e6, 6, "result.underlyingCollateral");

        assertEqDecimal(result.liquidationRatio, 1.4e6, 6, "result.liquidationRatio");
        // underlying collateral valued at 992.25 USDC
        // after applying min CR (40%): 708.75 USDC
        // collateral value 708.75 - existing debt 602.134078 = 106.615922 refinancing room
        // 106.615922 * 0.895 (bid rate) = 95.42125 USDC refinancing room value
        // swap cost recovered 330.2775 + refinancing room value 95.42125 = 425.69875 free collateral
        assertEqDecimal(result.minCollateral, -425.69875e6, 6, "result.minCollateral");

        assertEqDecimal(result.minDebt, 100e6, 6, "result.minDebt");
        // (existing debt 602.134078 - min debt 100) * 0.905 (ask rate) = 454.43134 USDC max debt cost
        // max debt cost 454.43134 - swap cost recovered 330.2775 = 124.15384 USDC
        assertEqDecimal(result.maxCollateral, 124.15384e6, 6, "result.maxCollateral");

        assertFalse(result.needsBatchedCall, "result.needsBatchedCall");
        assertEq(result.quoteLendingLiquidity, quoteMaxBaseIn, "quoteLendingLiquidity");
        assertEq(result.baseLendingLiquidity, 0, "baseLendingLiquidity");
        assertFalse(result.insufficientLiquidity, "result.insufficientLiquidity");

        _assertLiquidity(result);
    }

    function testClosePositionCost() public {
        // values for 2 ETHUSDC with 800 collateral position - taken from testCreatePositionOpenCost() test
        DataTypes.Balances memory balances = DataTypes.Balances({art: 602.134078e6, ink: 2e18});

        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, -2 ether, 0);

        // ETHUSDC: bid 699 / ask 701
        // 2 * 699 = 1398
        assertEqDecimal(result.spotCost, 1398e6, 6, "result.spotCost");

        // 2 * 0.945 (bid rate) = 1.89 ETH
        // 1.89 * 699 = 1321.11 (total USDC received)
        // existing debt 602.134078 * 0.905 (ask rate) = existing debt cost 544.931340 USDC
        // 1321.11 + (602.134078 - 544.931340) = 1378.312738 USDC cost
        assertEqDecimal(result.cost, 1378.312738e6, 6, "result.cost");

        // fully closes
        assertEq(result.collateralUsed, 0, "result.collateralUsed");
        assertEq(result.underlyingDebt, 0, "result.underlyingDebt");
        assertEq(result.debtDelta, 0, "result.debtDelta");
        assertEq(result.financingCost, 0, "result.financingCost");
        assertEq(result.underlyingCollateral, 0, "result.underlyingCollateral");
        assertEq(result.minCollateral, 0, "result.minCollateral");
        assertEq(result.maxCollateral, 0, "result.maxCollateral");

        assertEqDecimal(result.liquidationRatio, 1.4e6, 6, "result.liquidationRatio");
        assertEqDecimal(result.minDebt, 100e6, 6, "result.minDebt");

        assertFalse(result.needsBatchedCall, "result.needsBatchedCall");
        assertEq(result.quoteLendingLiquidity, quoteMaxFYTokenOut, "quoteLendingLiquidity");
        assertEq(result.baseLendingLiquidity, 0, "baseLendingLiquidity");
        assertFalse(result.insufficientLiquidity, "result.insufficientLiquidity");

        _assertLiquidity(result);
    }

    function testAddCollateralCost() public {
        // values for 2 ETHUSDC with 800 collateral position - taken from testCreatePositionOpenCost() test
        DataTypes.Balances memory balances = DataTypes.Balances({art: 602.134078e6, ink: 2e18});

        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, 0, 100e6);

        assertEqDecimal(result.spotCost, 0, 6, "result.spotCost");
        assertEqDecimal(result.collateralUsed, 100e6, 6, "result.collateralUsed");

        // how many fUSDC can I burn with 100 USDC?
        // 100 / 0.905 (ask rate) = 110.497237 fUSDC
        // existing debt - burnt debt
        // 602.134078 - 110.497237 = 491.636841 USDC
        assertEqDecimal(result.underlyingDebt, 491.636841e6, 6, "result.underlyingDebt");
        assertEqDecimal(result.debtDelta, -110.497237e6, 6, "result.debtDelta");

        // debtDelta + deposited collateral
        // -110.497237 + 100 = -10.497237
        assertEqDecimal(result.financingCost, -10.497237e6, 6, "result.financingCost");
        assertEqDecimal(result.cost, 10.497237e6, 6, "result.cost");

        // 2 * 0.945 (bid rate) = 1.89 ETH
        // valued at ETHUSD oracle price
        // 1.89 * 700 = 1323 USDC
        assertEqDecimal(result.underlyingCollateral, 1323e6, 6, "result.underlyingCollateral");

        assertEqDecimal(result.liquidationRatio, 1.4e6, 6, "result.liquidationRatio");
        // underlying collateral valued at 1323 USDC
        // after applying min CR (40%): 945 USDC
        // collateral value - existing debt
        // 945 - 602.134078 = 342.865922 refinancing room
        // 342.865922 * 0.895 (bid rate) = 306.865 USDC refinancing room value
        assertEqDecimal(result.minCollateral, -306.865e6, 6, "result.minCollateral");

        assertEqDecimal(result.minDebt, 100e6, 6, "result.minDebt");
        // (existing debt - min debt) * ask rate
        // (602.134078 - 100) * 0.905 = 454.43134 USDC max debt cost
        assertEqDecimal(result.maxCollateral, 454.43134e6, 6, "result.maxCollateral");

        assertFalse(result.needsBatchedCall, "result.needsBatchedCall");
        assertEq(result.quoteLendingLiquidity, quoteMaxBaseIn, "quoteLendingLiquidity");
        assertEq(result.baseLendingLiquidity, 0, "baseLendingLiquidity");
        assertFalse(result.insufficientLiquidity, "result.insufficientLiquidity");

        _assertLiquidity(result);
    }

    function testRemoveCollateralCost() public {
        // values for 2 ETHUSDC with 800 collateral position - taken from testCreatePositionOpenCost() test
        DataTypes.Balances memory balances = DataTypes.Balances({art: 602.134078e6, ink: 2e18});

        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, 0, -100e6);

        assertEqDecimal(result.spotCost, 0, 6, "result.spotCost");
        assertEqDecimal(result.collateralUsed, -100e6, 6, "result.collateralUsed");

        // how many fUSDC do I need, so that I can acquire 100 real USDC?
        // 100 / 0.895 (bid rate) = 111.731843 (could be rounded up if underlying protocol precision is greater than quote currency)
        // existing debt + new debt
        // 602.134078 + 111.731843 = 713.865921 USDC
        assertApproxEqAbsDecimal(result.underlyingDebt, 713.865921e6, 1, 6, "result.underlyingDebt");
        assertApproxEqAbsDecimal(result.debtDelta, 111.731843e6, 1, 6, "result.debtDelta");

        // debtDelta + deposited collateral
        // 111.731843 - 100 = 11.731843
        assertApproxEqAbsDecimal(result.financingCost, 11.731843e6, 1, 6, "result.financingCost");
        assertApproxEqAbsDecimal(result.cost, -11.731843e6, 1, 6, "result.cost");

        // 2 * 0.945 (bid rate) = 1.89 ETH
        // valued at ETHUSD oracle price
        // 1.89 * 700 = 1323 USDC
        assertEqDecimal(result.underlyingCollateral, 1323e6, 6, "result.underlyingCollateral");

        assertEqDecimal(result.liquidationRatio, 1.4e6, 6, "result.liquidationRatio");
        // underlying collateral valued at 1323 USDC
        // after applying min CR (40%): 945 USDC
        // collateral value - existing debt
        // 945 - 602.134078 = 342.865922 refinancing room
        // 342.865922 * 0.895 (bid rate) = 306.865 USDC refinancing room value
        assertEqDecimal(result.minCollateral, -306.865e6, 6, "result.minCollateral");

        assertEqDecimal(result.minDebt, 100e6, 6, "result.minDebt");
        // (existing debt - min debt) * ask rate
        // (602.134078 - 100) * 0.905 = 454.43134 USDC max debt cost
        assertEqDecimal(result.maxCollateral, 454.43134e6, 6, "result.maxCollateral");

        assertFalse(result.needsBatchedCall, "result.needsBatchedCall");
        assertEq(result.quoteLendingLiquidity, 0, "quoteLendingLiquidity");
        assertEq(result.baseLendingLiquidity, 0, "baseLendingLiquidity");
        assertFalse(result.insufficientLiquidity, "result.insufficientLiquidity");

        _assertLiquidity(result);
    }

    function testDeliveryCost() public {
        // values for 2 ETHUSDC with 800 collateral position - taken from testCreatePositionOpenCost() test
        DataTypes.Balances memory balances = DataTypes.Balances({art: 602.134078e6, ink: 2e18});

        // assumes position is already expired
        // 0.15% fees of cost - taken from testCreatePositionOpenCost() test
        // 1402.134078 * 0.0015 = 2.103202 (rounded up)
        Position memory position;
        position.protocolFees = 2.103202e6;

        uint256 deliveryCost = testQuoter.deliveryCostForPosition(balances, yieldInstrument, position);

        // existing debt + fees
        // 602.134078 + 2.103202 = 604.23728
        assertEqDecimal(deliveryCost, 604.23728e6, 6, "deliveryCost");
    }

    function testIncreasePositionAndDepositCost() public {
        // values for 2 ETHUSDC with 800 collateral position - taken from testCreatePositionOpenCost() test
        DataTypes.Balances memory balances = DataTypes.Balances({art: 602.134078e6, ink: 2e18});

        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, 0.5 ether, 100e6);

        // ETHUSDC: bid 699 / ask 701
        // 0.5 * 701 = 350.5 USDC
        assertEqDecimal(result.spotCost, -350.5e6, 6, "result.spotCost");

        assertEqDecimal(result.collateralUsed, 100e6, 6, "result.collateralUsed");

        // how much ETH do we need today (PV) to have 0.5 ETH at expiry?
        // 0.5 * 0.955 (ask rate) = 0.4775 ETH
        // 0.4775 * 701 = 334.7275 swap cost
        // swap cost - collateral posted
        // 334.7275 - 100 = 234.7275 total USDC we need to borrow
        // how many fUSDC do I need, so that I can acquire 234.7275 real USDC?
        // 234.7275 / 0.895 (bid rate) = 262.265363 (could be rounded up if underlying protocol precision is greater than quote currency)
        // existing debt + new debt
        // 602.134078 + 262.265363 = 864.399441 USDC
        assertApproxEqAbsDecimal(result.underlyingDebt, 864.399441e6, 1, 6, "result.underlyingDebt");
        assertApproxEqAbsDecimal(result.debtDelta, 262.265363e6, 1, 6, "result.debtDelta");
        // debtDelta + collateral posted
        // 262.265363 + 100 = 362.265363
        assertApproxEqAbsDecimal(result.cost, -362.265363e6, 1, 6, "result.cost");

        // sold fUSDC (debtDelta) - borrowed
        // 262.265363 - 234.7275 = 27.537863
        assertApproxEqAbsDecimal(result.financingCost, 27.537863e6, 1, 6, "result.financingCost");

        // fETH valued at bid rate
        // 2.5 * 0.945 = 2.3625 ETH
        // ETH valued at ETHUSD oracle price
        // 2.3625 * 700 = 1653.75 USDC
        // TODO alfredo - check if haircut should be applied on this valuation and if it should look at bid prices
        assertEqDecimal(result.underlyingCollateral, 1653.75e6, 6, "result.underlyingCollateral");

        assertEqDecimal(result.liquidationRatio, 1.4e6, 6, "result.liquidationRatio");
        // underlying collateral valued at 1653.75 USDC
        // after applying min CR (40%): 1181.25 USDC
        // collateral value - existing debt
        // 1181.25 - 602.134078 = 579.115922 USDC max borrowing
        // fUSDC can borrow at bid rate
        // 579.115922 * 0.895 = 518.30875 USDC remaining borrowing
        assertEqDecimal(result.minDebt, 100e6, 6, "result.minDebt");

        // swap cost - remaining borrowing
        // 334.7275 - 518.30875 = -183.58125
        assertEqDecimal(result.minCollateral, -183.58125e6, 6, "result.minCollateral");
        // full swap payment + repaying existing debt
        // (existing debt - min debt) * ask rate
        // (602.134078 - 100) * 0.905 = 454.431340 USDC existing debt cost
        // swap cost + existing debt cost
        // 334.7275 + 454.431340 = 789.15884 USDC
        assertEqDecimal(result.maxCollateral, 789.15884e6, 6, "result.maxCollateral");

        assertFalse(result.needsBatchedCall, "result.needsBatchedCall");
        assertEq(result.baseLendingLiquidity, baseMaxFYTokenOut, "baseLendingLiquidity");
        assertEq(result.quoteLendingLiquidity, quoteMaxBaseIn, "quoteLendingLiquidity");
        assertFalse(result.insufficientLiquidity, "result.insufficientLiquidity");

        _assertLiquidity(result);
    }

    function testIncreasePositionAndWithdrawCost() public {
        // values for 2 ETHUSDC with 800 collateral position - taken from testCreatePositionOpenCost() test
        DataTypes.Balances memory balances = DataTypes.Balances({art: 602.134078e6, ink: 2e18});

        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, 0.5 ether, -100e6);

        // ETHUSDC: bid 699 / ask 701
        // 0.5 * 701 = 350.5 USDC
        assertEqDecimal(result.spotCost, -350.5e6, 6, "result.spotCost");

        assertEqDecimal(result.collateralUsed, -100e6, 6, "result.collateralUsed");

        // how much ETH do we need today (PV) to have 0.5 ETH at expiry?
        // 0.5 * 0.955 (ask rate) = 0.4775 ETH
        // 0.4775 * 701 = 334.7275 swap cost
        // swap cost - collateral withdrawn
        // 334.7275 + 100 = 434.7275 total USDC we need to borrow
        // how many fUSDC do I need, so that I can acquire 434.7275 real USDC?
        // 434.7275 / 0.895 (bid rate) = 485.72905 (could be rounded up if underlying protocol precision is greater than quote currency)
        // existing debt + new debt
        // 602.134078 + 485.72905 = 1087.863128 USDC
        assertApproxEqAbsDecimal(result.underlyingDebt, 1087.863128e6, 1, 6, "result.underlyingDebt");
        assertApproxEqAbsDecimal(result.debtDelta, 485.72905e6, 1, 6, "result.debtDelta");
        // debtDelta - collateral withdrawn
        // 485.72905 - 100 = 385.72905
        assertApproxEqAbsDecimal(result.cost, -385.72905e6, 1, 6, "result.cost");

        // sold fUSDC (debtDelta) - borrowed
        // 485.72905 - 434.7275 = 51.00155
        assertApproxEqAbsDecimal(result.financingCost, 51.00155e6, 1, 6, "result.financingCost");

        // fETH valued at bid rate
        // 2.5 * 0.945 = 2.3625 ETH
        // ETH valued at ETHUSD oracle price
        // 2.3625 * 700 = 1653.75 USDC
        // TODO alfredo - check if haircut should be applied on this valuation and if it should look at bid prices
        assertEqDecimal(result.underlyingCollateral, 1653.75e6, 6, "result.underlyingCollateral");

        assertEqDecimal(result.liquidationRatio, 1.4e6, 6, "result.liquidationRatio");
        // underlying collateral valued at 1653.75 USDC
        // after applying min CR (40%): 1181.25 USDC
        // collateral value - existing debt
        // 1181.25 - 602.134078 = 579.115922 USDC max borrowing
        // fUSDC can borrow at bid rate
        // 579.115922 * 0.895 = 518.30875 USDC remaining borrowing
        assertEqDecimal(result.minDebt, 100e6, 6, "result.minDebt");

        // swap cost - remaining borrowing
        // 334.7275 - 518.30875 = -183.58125
        assertEqDecimal(result.minCollateral, -183.58125e6, 6, "result.minCollateral");
        // full swap payment + repaying existing debt
        // (existing debt - min debt) * ask rate
        // (602.134078 - 100) * 0.905 = 454.431340 USDC existing debt cost
        // swap cost + existing debt cost
        // 334.7275 + 454.431340 = 789.15884 USDC
        assertEqDecimal(result.maxCollateral, 789.15884e6, 6, "result.maxCollateral");

        assertFalse(result.needsBatchedCall, "result.needsBatchedCall");
        assertEq(result.baseLendingLiquidity, baseMaxFYTokenOut, "baseLendingLiquidity");
        assertEq(result.quoteLendingLiquidity, 0, "quoteLendingLiquidity");
        assertFalse(result.insufficientLiquidity, "result.insufficientLiquidity");

        _assertLiquidity(result);
    }

    function testDecreasePositionAndDepositCost() public {
        // values for 2 ETHUSDC with 800 collateral position - taken from testCreatePositionOpenCost() test
        DataTypes.Balances memory balances = DataTypes.Balances({art: 602.134078e6, ink: 2e18});

        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, -0.5 ether, 100e6);

        // ETHUSDC: bid 699 / ask 701
        // 0.5 * 699 = 349.50
        assertEqDecimal(result.spotCost, 349.5e6, 6, "result.spotCost");

        assertEqDecimal(result.collateralUsed, 100e6, 6, "result.collateralUsed");

        // 0.5 * 0.945 (bid rate) = 0.4725 ETH
        // 0.4725 * 699 = 330.2775 (total USDC received)
        // swap received + posted collateral
        // 330.2775 + 100 = 430.2775
        // how many fUSDC can I burn with 430.2775 USDC?
        // 430.2775 / 0.905 (ask rate) = 475.444751 fUSDC (could be rounded up if underlying protocol precision is greater than quote currency)
        // existing debt - burnt debt
        // 602.134078 - 475.444751 = 126.689327 fUSDC
        assertApproxEqAbsDecimal(result.underlyingDebt, 126.689327e6, 1, 6, "result.underlyingDebt");
        assertApproxEqAbsDecimal(result.debtDelta, -475.444751e6, 1, 6, "result.debtDelta");

        // bought fUSDC (debtDelta) - (swap cost + posted collateral)
        // 475.444751 - (330.2775 + 100) = 45.167251
        assertEqDecimal(result.financingCost, -45.167251e6, 6, "result.financingCost");

        // debtDelta - posted collateral
        // 475.444751 - 100 = 375.444751 USDC cost
        assertEqDecimal(result.cost, 375.444751e6, 6, "result.cost");

        // 1.5 fETH valued at bid rate 0.945 = 1.4175 ETH
        // 1.4175 ETH valued at ETHUSD oracle price 700 = 992.25 USDC
        assertEqDecimal(result.underlyingCollateral, 992.25e6, 6, "result.underlyingCollateral");

        assertEqDecimal(result.liquidationRatio, 1.4e6, 6, "result.liquidationRatio");
        // underlying collateral valued at 992.25 USDC
        // after applying min CR (40%): 708.75 USDC
        // collateral value 708.75 - existing debt 602.134078 = 106.615922 refinancing room
        // 106.615922 * 0.895 (bid rate) = 95.42125 USDC refinancing room value
        // swap cost recovered 330.2775 + refinancing room value 95.42125 = 425.69875 free collateral
        assertEqDecimal(result.minCollateral, -425.69875e6, 6, "result.minCollateral");

        assertEqDecimal(result.minDebt, 100e6, 6, "result.minDebt");
        // (existing debt 602.134078 - min debt 100) * 0.905 (ask rate) = 454.43134 USDC max debt cost
        // max debt cost 454.43134 - swap cost recovered 330.2775 = 124.15384 USDC
        assertEqDecimal(result.maxCollateral, 124.15384e6, 6, "result.maxCollateral");

        assertFalse(result.needsBatchedCall, "result.needsBatchedCall");
        assertEq(result.quoteLendingLiquidity, quoteMaxBaseIn, "quoteLendingLiquidity");
        assertEq(result.baseLendingLiquidity, 0, "baseLendingLiquidity");
        assertFalse(result.insufficientLiquidity, "result.insufficientLiquidity");

        _assertLiquidity(result);
    }

    function testDecreasePositionAndWithdrawCost() public {
        // values for 2 ETHUSDC with 800 collateral position - taken from testCreatePositionOpenCost() test
        DataTypes.Balances memory balances = DataTypes.Balances({art: 602.134078e6, ink: 2e18});

        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, -0.5 ether, -100e6);

        // ETHUSDC: bid 699 / ask 701
        // 0.5 * 699 = 349.50
        assertEqDecimal(result.spotCost, 349.5e6, 6, "result.spotCost");

        assertEqDecimal(result.collateralUsed, -100e6, 6, "result.collateralUsed");

        // 0.5 * 0.945 (bid rate) = 0.4725 ETH
        // 0.4725 * 699 = 330.2775 (total USDC received)
        // how many fUSDC can I burn with 330.2775 USDC?
        // 330.2775 / 0.905 (ask rate) = 364.947513 fUSDC (could be rounded up if underlying protocol precision is greater than quote currency)
        // withdrawn collateral / ask rate
        // 100 / 0.905 = 110.497237 new debt
        // existing debt - burnt debt + new debt
        // 602.134078 - 364.947513 + 110.497237 = 347.683802 fUSDC
        assertApproxEqAbsDecimal(result.underlyingDebt, 347.683802e6, 1, 6, "result.underlyingDebt");
        // new debt - burnt debt
        // 110.497237 - 364.947513 = -254.450276
        assertApproxEqAbsDecimal(result.debtDelta, -254.450276e6, 1, 6, "result.debtDelta");

        // swap cost - bought fUSDC (debtDelta) - collateral withdrawn
        // 330.2775 - 254.450276 - 100 = -24.172776
        assertEqDecimal(result.financingCost, -24.172776e6, 6, "result.financingCost");

        // debtDelta + collateral withdrawn
        // 254.450276 + 100 = 354.450276 USDC cost
        assertEqDecimal(result.cost, 354.450276e6, 6, "result.cost");

        // 1.5 fETH valued at bid rate 0.945 = 1.4175 ETH
        // 1.4175 ETH valued at ETHUSD oracle price 700 = 992.25 USDC
        assertEqDecimal(result.underlyingCollateral, 992.25e6, 6, "result.underlyingCollateral");

        assertEqDecimal(result.liquidationRatio, 1.4e6, 6, "result.liquidationRatio");
        // underlying collateral valued at 992.25 USDC
        // after applying min CR (40%): 708.75 USDC
        // collateral value 708.75 - existing debt 602.134078 = 106.615922 refinancing room
        // 106.615922 * 0.895 (bid rate) = 95.42125 USDC refinancing room value
        // swap cost recovered 330.2775 + refinancing room value 95.42125 = 425.69875 free collateral
        assertEqDecimal(result.minCollateral, -425.69875e6, 6, "result.minCollateral");

        assertEqDecimal(result.minDebt, 100e6, 6, "result.minDebt");
        // (existing debt 602.134078 - min debt 100) * 0.905 (ask rate) = 454.43134 USDC max debt cost
        // max debt cost 454.43134 - swap cost recovered 330.2775 = 124.15384 USDC
        assertEqDecimal(result.maxCollateral, 124.15384e6, 6, "result.maxCollateral");

        assertFalse(result.needsBatchedCall, "result.needsBatchedCall");
        assertEq(result.quoteLendingLiquidity, quoteMaxBaseIn, "quoteLendingLiquidity");
        assertEq(result.baseLendingLiquidity, 0, "baseLendingLiquidity");
        assertFalse(result.insufficientLiquidity, "result.insufficientLiquidity");

        _assertLiquidity(result);
    }

    function testCreatePositionOpenCost_Overcollateralised() public {
        // empty account since it's a new position
        DataTypes.Balances memory balances;

        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, 2 ether, 1600e6);
        // exceeds max collateral taken from testCreatePositionOpenCost() test

        // ETHUSDC: bid 699 / ask 701
        // 2 * 701 = 1402 USDC
        assertEqDecimal(result.spotCost, -1402e6, 6, "result.spotCost");

        // how much ETH do we need today (PV) to have 2 ETH at expiry?
        // 2 * 0.955 (ask rate) = 1.91 ETH
        // 1.91 * 701 = 1338.91 (total USDC needed)

        assertEqDecimal(result.minDebt, 100e6, 6, "result.minDebt");
        // full swap payment
        // min debt 100 at bid rate 0.895 = min borrow 89.50 USDC
        // swap cost 1338.91 - min borrow 89.50 = 1249.41 USDC
        assertEqDecimal(result.maxCollateral, 1249.41e6, 6, "result.maxCollateral");
        assertEqDecimal(result.collateralUsed, 1249.41e6, 6, "result.collateralUsed");

        // 1338.91 - 1249.41 (user collateral) = 89.5 (total USDC we need to borrow)
        // how many fUSDC do I need, so that I can acquire 89.5 real USDC?
        // 89.5 / 0.895 (bid rate) = 100 (could be rounded up if underlying protocol precision is greater than quote currency)
        assertApproxEqAbsDecimal(result.underlyingDebt, 100e6, 1, 6, "result.underlyingDebt");
        assertApproxEqAbsDecimal(result.debtDelta, 100e6, 1, 6, "result.debtDelta");

        // sold fUSDC (debtDelta) - borrowed USDC
        // 100 - 89.5 = 10.5
        assertApproxEqAbsDecimal(result.financingCost, 10.5e6, 1, 6, "result.financingCost");

        // collateral posted + debtDelta
        // 1249.41 + 100 = 1349.41 USDC cost
        assertApproxEqAbsDecimal(result.cost, -1349.41e6, 1, 6, "result.cost");

        // 2 fETH valued at bid rate 0.945 = 1.89 ETH
        // 1.89 ETH valued at ETHUSD oracle price 700 = 1323 USDC
        assertEqDecimal(result.underlyingCollateral, 1323e6, 6, "result.underlyingCollateral");

        assertEqDecimal(result.liquidationRatio, 1.4e6, 6, "result.liquidationRatio");
        // underlying collateral valued at 1323 USDC
        // after applying min CR (40%): 945 USDC
        // 945 fUSDC can borrow at bid rate 0.895 = 845.775 USDC

        // swap cost 1338.91 - max borrowing 845.775 = 493.135 USDC min collateral
        assertEqDecimal(result.minCollateral, 493.135e6, 6, "result.minCollateral");

        assertFalse(result.needsBatchedCall, "result.needsBatchedCall");
        assertEq(result.baseLendingLiquidity, baseMaxFYTokenOut, "baseLendingLiquidity");
        assertEq(result.quoteLendingLiquidity, 0, "quoteLendingLiquidity");
        assertFalse(result.insufficientLiquidity, "result.insufficientLiquidity");

        _assertLiquidity(result);
    }

    function testIncreasePositionCost_Overcollateralised() public {
        // values for 2 ETHUSDC with 800 collateral position - taken from testCreatePositionOpenCost() test
        DataTypes.Balances memory balances = DataTypes.Balances({art: 602.134078e6, ink: 2e18});

        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, 2 ether, 1850e6);
        // exceeds max collateral taken from testIncreasePositionOpenCost() test

        // ETHUSDC: bid 699 / ask 701
        // 2 * 701 = 1402 USDC
        assertEqDecimal(result.spotCost, -1402e6, 6, "result.spotCost");

        // how much ETH do we need today (PV) to have 2 ETH at expiry?
        // 2 * 0.955 (ask rate) = 1.91 ETH
        // 1.91 * 701 = 1338.91 (total USDC needed)

        assertEqDecimal(result.minDebt, 100e6, 6, "result.minDebt");
        // full swap payment + repaying existing debt
        // (existing debt - min debt) * ask rate
        // (602.134078 - 100) * 0.905 = 454.431340 USDC existing debt cost
        // swap cost + existing debt cost
        // 1338.91 + 454.431340 = 1793.34134 USDC
        assertEqDecimal(result.maxCollateral, 1793.34134e6, 6, "result.maxCollateral");
        assertEqDecimal(result.collateralUsed, 1793.34134e6, 6, "result.collateralUsed");

        // 1338.91 - 1793.34134 (user collateral) = -454.43134 (total USDC left to burn debt)
        // how much debt can I burn with 454.43134 USDC?
        // cash to burn debt / ask rate
        // 454.43134 / 0.905 = 502.134077 (could be rounded up if underlying protocol precision is greater than quote currency)
        assertApproxEqAbsDecimal(result.debtDelta, -502.134077e6, 1, 6, "result.debtDelta");
        // existing debt - burnt debt
        // 602.134078 - 502.134077 = 100.000001
        assertApproxEqAbsDecimal(result.underlyingDebt, 100.000001e6, 1, 6, "result.underlyingDebt");

        // repayment - sold fUSDC (debtDelta)
        // 454.43134 - 502.134077 = -47.702737
        assertApproxEqAbsDecimal(result.financingCost, -47.702737e6, 1, 6, "result.financingCost");

        // collateral posted + debtDelta
        // 1793.34134 - 502.134077 = 1291.207263 USDC cost
        assertApproxEqAbsDecimal(result.cost, -1291.207263e6, 1, 6, "result.cost");

        // 4 fETH valued at bid rate 0.945 = 3.78 ETH
        // 3.78 ETH valued at ETHUSD oracle price 700 = 2646 USDC
        assertEqDecimal(result.underlyingCollateral, 2646e6, 6, "result.underlyingCollateral");

        assertEqDecimal(result.liquidationRatio, 1.4e6, 6, "result.liquidationRatio");
        // underlying collateral valued at 2646 USDC
        // after applying min CR (40%): 1890 USDC
        // collateral value 1890 - existing debt 602.134078 = max borrowing 1287.865922 USDC
        // 1287.865922 fUSDC can borrow at bid rate 0.895 = remaining borrowing 1152.64 USDC

        // swap cost 1338.91 - remaining borrowing 1152.64 = 186.27
        assertEqDecimal(result.minCollateral, 186.27e6, 6, "result.minCollateral");

        assertTrue(result.needsBatchedCall, "result.needsBatchedCall");
        assertEq(result.baseLendingLiquidity, baseMaxFYTokenOut, "baseLendingLiquidity");
        assertEq(result.quoteLendingLiquidity, quoteMaxBaseIn, "quoteLendingLiquidity");
        assertFalse(result.insufficientLiquidity, "result.insufficientLiquidity");

        _assertLiquidity(result);
    }

    function testDecreasePositionCost_Overcollateralised() public {
        // values for 2 ETHUSDC with 800 collateral position - taken from testCreatePositionOpenCost() test
        DataTypes.Balances memory balances = DataTypes.Balances({art: 602.134078e6, ink: 2e18});

        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, -1.5 ether, 0);

        // ETHUSDC: bid 699 / ask 701
        // 1.5 * 699 = 1048.50
        assertEqDecimal(result.spotCost, 1048.5e6, 6, "result.spotCost");

        assertEqDecimal(result.minDebt, 100e6, 6, "result.minDebt");

        // (existing debt - min debt) * ask rate
        // (602.134078 - 100) * 0.905 = 454.43134 USDC max debt cost
        // 1.5 * 0.945 (bid rate) = 1.4175 ETH
        // 1.4175 * 699 = 990.8325 (total USDC received)
        // max debt cost - swap cost recovered
        // 454.43134 - 990.8325 = -536.40116 USDC
        assertEqDecimal(result.maxCollateral, -536.40116e6, 6, "result.maxCollateral");
        assertEqDecimal(result.collateralUsed, -536.40116e6, 6, "result.collateralUsed");

        // how many fUSDC can I burn with 454.43134 USDC?
        // 454.43134 / 0.905 (ask rate) = 502.134077 fUSDC max debt burn (could be rounded up if underlying protocol precision is greater than quote currency)
        // existing debt - max debt burn
        // 602.134078 - 502.134077 = 100 USDC
        assertApproxEqAbsDecimal(result.underlyingDebt, 100e6, 1, 6, "result.underlyingDebt");
        assertApproxEqAbsDecimal(result.debtDelta, -502.134077e6, 1, 6, "result.debtDelta");

        // debt cost - bought fUSDC (debtDelta)
        // 454.43134 - 502.134077 = -47.702737
        assertEqDecimal(result.financingCost, -47.702737e6, 6, "result.financingCost");

        // collateral used + debt delta
        // 536.40116 + 502.134077 = 1038.535237
        assertEqDecimal(result.cost, 1038.535237e6, 6, "result.cost");

        // 2 - 1.5 = 0.5
        // 0.5 * 0.945 (bid rate) = 0.4725 ETH
        // 0.4725 * 700 (oracle rate) = 330.75 USDC
        assertEqDecimal(result.underlyingCollateral, 330.75e6, 6, "result.underlyingCollateral");

        assertEqDecimal(result.liquidationRatio, 1.4e6, 6, "result.liquidationRatio");
        // underlying collateral valued at 330.75 USDC
        // after applying min CR (40%): 236.25 USDC
        // existing debt - collateral value
        // 602.134078 - 236.25 = 365.884078 fUSDC debt to be burned
        // 365.884078 * 0.905 (ask rate) = 331.125090 USDC debt to be burned cost
        // swap cost recovered - debt to be burned cost
        // 990.8325 - 331.125090 = 659.70741 extra collateral
        assertEqDecimal(result.minCollateral, -659.70741e6, 6, "result.minCollateral");

        assertFalse(result.needsBatchedCall, "result.needsBatchedCall");
        assertEq(result.quoteLendingLiquidity, quoteMaxBaseIn, "quoteLendingLiquidity");
        assertEq(result.baseLendingLiquidity, 0, "baseLendingLiquidity");
        assertFalse(result.insufficientLiquidity, "result.insufficientLiquidity");

        _assertLiquidity(result);
    }

    function testAddCollateralCost_Overcollateralised() public {
        // values for 2 ETHUSDC with 800 collateral position - taken from testCreatePositionOpenCost() test
        DataTypes.Balances memory balances = DataTypes.Balances({art: 602.134078e6, ink: 2e18});

        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, 0, 800e6);
        // exceeds max collateral taken from testCreatePositionOpenCost() test

        assertEqDecimal(result.spotCost, 0, 6, "result.spotCost");

        assertEqDecimal(result.minDebt, 100e6, 6, "result.minDebt");
        // (existing debt - min debt) * ask rate
        // (602.134078 - 100) * 0.905 = 454.43134 USDC max debt cost
        assertEqDecimal(result.maxCollateral, 454.43134e6, 6, "result.maxCollateral");
        assertEqDecimal(result.collateralUsed, 454.43134e6, 6, "result.collateralUsed");

        // how much USDC I need to burn 454.43134 fUSDC?
        // 454.43134 / 0.905 (ask rate) = 502.134077 USDC (could be rounded up if underlying protocol precision is greater than quote currency)
        // existing debt - burnt debt
        // 602.134078 - 502.134077 = 100.000001 USDC
        assertApproxEqAbsDecimal(result.underlyingDebt, 100.000001e6, 1, 6, "result.underlyingDebt");
        assertApproxEqAbsDecimal(result.debtDelta, -502.134077e6, 1, 6, "result.debtDelta");

        // repayment - sold fUSDC (debtDelta)
        // 454.43134 - 502.134077 = -47.702737
        assertApproxEqAbsDecimal(result.financingCost, -47.702737e6, 1, 6, "result.financingCost");
        assertApproxEqAbsDecimal(result.cost, 47.702737e6, 1, 6, "result.cost");

        // 2 * 0.945 (bid rate) = 1.89 ETH
        // valued at ETHUSD oracle price
        // 1.89 * 700 = 1323 USDC
        assertEqDecimal(result.underlyingCollateral, 1323e6, 6, "result.underlyingCollateral");

        assertEqDecimal(result.liquidationRatio, 1.4e6, 6, "result.liquidationRatio");
        // underlying collateral valued at 1323 USDC
        // after applying min CR (40%): 945 USDC
        // collateral value - existing debt
        // 945 - 602.134078 = 342.865922 refinancing room
        // 342.865922 * 0.895 (bid rate) = 306.865 USDC refinancing room value
        assertEqDecimal(result.minCollateral, -306.865e6, 6, "result.minCollateral");

        assertFalse(result.needsBatchedCall, "result.needsBatchedCall");
        assertEq(result.quoteLendingLiquidity, quoteMaxBaseIn, "quoteLendingLiquidity");
        assertEq(result.baseLendingLiquidity, 0, "baseLendingLiquidity");
        assertFalse(result.insufficientLiquidity, "result.insufficientLiquidity");

        _assertLiquidity(result);
    }

    function testCreatePositionOpenCost_Undercollateralised() public {
        // empty account since it's a new position
        DataTypes.Balances memory balances;

        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, 2 ether, 450e6);
        // under min collateral taken from testCreatePositionOpenCost() test

        // ETHUSDC: bid 699 / ask 701
        // 2 * 701 = 1402 USDC
        assertEqDecimal(result.spotCost, -1402e6, 6, "result.spotCost");

        // how much ETH do we need today (PV) to have 2 ETH at expiry?
        // 2 * 0.955 (ask rate) = 1.91 ETH
        // 1.91 * 701 = 1338.91 (total USDC needed)

        // 2 fETH valued at bid rate 0.945 = 1.89 ETH
        // 1.89 ETH valued at ETHUSD oracle price 700 = 1323 USDC
        assertEqDecimal(result.underlyingCollateral, 1323e6, 6, "result.underlyingCollateral");

        assertEqDecimal(result.liquidationRatio, 1.4e6, 6, "result.liquidationRatio");
        // underlying collateral valued at 1323 USDC
        // after applying min CR (40%): 945 USDC
        // 945 fUSDC can borrow at bid rate 0.895 = 845.775 USDC

        // swap cost 1338.91 - max borrowing 845.775 = 493.135 USDC min collateral
        assertEqDecimal(result.minCollateral, 493.135e6, 6, "result.minCollateral");
        assertEqDecimal(result.collateralUsed, 493.135e6, 6, "result.collateralUsed");

        // 1338.91 - 493.135 (user collateral) = 845.775 (total USDC we need to borrow)
        // how many fUSDC do I need, so that I can acquire 845.775 real USDC?
        // 845.775 / 0.895 (bid rate) = 945 (could be rounded up if underlying protocol precision is greater than quote currency)
        assertApproxEqAbsDecimal(result.underlyingDebt, 945e6, 1, 6, "result.underlyingDebt");
        assertApproxEqAbsDecimal(result.debtDelta, 945e6, 1, 6, "result.debtDelta");

        // sold fUSDC (debtDelta) - borrowed USDC
        // 945 - 845.775 = 99.225
        assertApproxEqAbsDecimal(result.financingCost, 99.225e6, 1, 6, "result.financingCost");

        // collateral posted + debtDelta
        // 493.135 + 945 = 1438.135 USDC cost
        assertApproxEqAbsDecimal(result.cost, -1438.135e6, 1, 6, "result.cost");

        assertEqDecimal(result.minDebt, 100e6, 6, "result.minDebt");
        // full swap payment
        // min debt 100 at bid rate 0.895 = min borrow 89.50 USDC
        // swap cost 1338.91 - min borrow 89.50 = 1249.41 USDC
        assertEqDecimal(result.maxCollateral, 1249.41e6, 6, "result.maxCollateral");

        assertFalse(result.needsBatchedCall, "result.needsBatchedCall");
        assertEq(result.baseLendingLiquidity, baseMaxFYTokenOut, "baseLendingLiquidity");
        assertEq(result.quoteLendingLiquidity, 0, "quoteLendingLiquidity");
        assertFalse(result.insufficientLiquidity, "result.insufficientLiquidity");

        _assertLiquidity(result);
    }

    function testIncreasePositionCost_Undercollateralised() public {
        // values for 2 ETHUSDC with 800 collateral position - taken from testCreatePositionOpenCost() test
        DataTypes.Balances memory balances = DataTypes.Balances({art: 602.134078e6, ink: 2e18});

        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, 2 ether, 0);

        // ETHUSDC: bid 699 / ask 701
        // 2 * 701 = 1402 USDC
        assertEqDecimal(result.spotCost, -1402e6, 6, "result.spotCost");

        // how much ETH do we need today (PV) to have 2 ETH at expiry?
        // 2 * 0.955 (ask rate) = 1.91 ETH
        // 1.91 * 701 = 1338.91 (total USDC needed)

        // 4 fETH valued at bid rate 0.945 = 3.78 ETH
        // 3.78 ETH valued at ETHUSD oracle price 700 = 2646 USDC
        assertEqDecimal(result.underlyingCollateral, 2646e6, 6, "result.underlyingCollateral");

        assertEqDecimal(result.liquidationRatio, 1.4e6, 6, "result.liquidationRatio");
        // underlying collateral valued at 2646 USDC
        // after applying min CR (40%): 1890 USDC
        // collateral value 1890 - existing debt 602.134078 = max borrowing 1287.865922 USDC
        // 1287.865922 fUSDC can borrow at bid rate 0.895 = remaining borrowing 1152.64 USDC

        // swap cost 1338.91 - remaining borrowing 1152.64 = 186.27
        assertEqDecimal(result.minCollateral, 186.27e6, 6, "result.minCollateral");
        assertEqDecimal(result.collateralUsed, 186.27e6, 6, "result.collateralUsed");

        // 1338.91 - 186.27 (user collateral) = 1152.64 (total USDC we need to borrow)
        // how many fUSDC do I need, so that I can acquire 1152.64 real USDC?
        // 1152.64 / 0.895 (bid rate) = 1287.865921 (could be rounded up if underlying protocol precision is greater than quote currency)
        // existing debt + new debt
        // 602.134078 + 1287.865921 = 1889.999999
        assertApproxEqAbsDecimal(result.underlyingDebt, 1889.999999e6, 1, 6, "result.underlyingDebt");
        assertApproxEqAbsDecimal(result.debtDelta, 1287.865921e6, 1, 6, "result.debtDelta");

        // sold fUSDC (debtDelta) - borrowed USDC
        // 1287.865921 - 1152.64 = 135.225921
        assertApproxEqAbsDecimal(result.financingCost, 135.225921e6, 1, 6, "result.financingCost");

        // collateral posted + debtDelta
        // 186.27 + 1287.865921 = 1474.135921 USDC cost
        assertApproxEqAbsDecimal(result.cost, -1474.135921e6, 1, 6, "result.cost");

        assertEqDecimal(result.minDebt, 100e6, 6, "result.minDebt");
        // full swap payment + repaying existing debt
        // (existing debt - min debt) * ask rate
        // (602.134078 - 100) * 0.905 = 454.431340 USDC existing debt cost
        // swap cost + existing debt cost
        // 1338.91 + 454.431340 = 1793.34134 USDC
        assertEqDecimal(result.maxCollateral, 1793.34134e6, 6, "result.maxCollateral");

        assertFalse(result.needsBatchedCall, "result.needsBatchedCall");
        assertEq(result.baseLendingLiquidity, baseMaxFYTokenOut, "baseLendingLiquidity");
        assertEq(result.quoteLendingLiquidity, 0, "quoteLendingLiquidity");
        assertFalse(result.insufficientLiquidity, "result.insufficientLiquidity");

        _assertLiquidity(result);
    }

    function testDecreasePositionCost_Undercollateralised() public {
        // values for 2 ETHUSDC with 800 collateral position - taken from testCreatePositionOpenCost() test
        DataTypes.Balances memory balances = DataTypes.Balances({art: 602.134078e6, ink: 2e18});

        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, -0.5 ether, -400e6);

        // ETHUSDC: bid 699 / ask 701
        // 0.5 * 699 = 349.50
        assertEqDecimal(result.spotCost, 349.5e6, 6, "result.spotCost");

        assertEqDecimal(result.minDebt, 100e6, 6, "result.minDebt");

        // (existing debt - min debt) * ask rate
        // (602.134078 - 100) * 0.905 = 454.43134 USDC max debt cost
        // 0.5 * 0.945 (bid rate) = 0.4725 ETH
        // 0.4725 * 699 = 330.2775 (total USDC received)
        // max debt cost - swap cost recovered
        // 454.43134 - 330.2775 = 124.15384 USDC
        assertEqDecimal(result.maxCollateral, 124.15384e6, 6, "result.maxCollateral");

        // 2 - 0.5 = 1.5
        // 1.5 * 0.945 (bid rate) = 1.4175 ETH
        // 1.4175 * 700 (oracle rate) = 992.25 USDC
        assertEqDecimal(result.underlyingCollateral, 992.25e6, 6, "result.underlyingCollateral");

        assertEqDecimal(result.liquidationRatio, 1.4e6, 6, "result.liquidationRatio");
        // underlying collateral valued at 992.25 USDC
        // after applying min CR (40%): 708.75 USDC
        // collateral value - existing debt
        // 708.75 - 602.134078 = 106.615922 fUSDC available debt
        // 106.615922 * 0.895 (bid rate) = 95.42125 USDC available debt cost
        // swap cost recovered - available debt cost
        // 330.2775 + 95.42125 = 425.69875 extra collateral
        assertEqDecimal(result.minCollateral, -425.69875e6, 6, "result.minCollateral");
        assertEqDecimal(result.collateralUsed, -400e6, 6, "result.collateralUsed");

        // collateral used + swap cost
        // -400 + 330.2775 = -69.7225 borrowing needed
        // 69.7225 / 0.895 (bid rate) = 77.902234 fUSDC new debt (could be rounded up if underlying protocol precision is greater than quote currency)
        // existing debt + new debt
        // 602.134078 + 77.902234 = 680.036312 USDC
        assertApproxEqAbsDecimal(result.underlyingDebt, 680.036312e6, 1, 6, "result.underlyingDebt");
        assertApproxEqAbsDecimal(result.debtDelta, 77.902234e6, 1, 6, "result.debtDelta");

        // bought fUSDC - received USDC
        // 77.902234 - 69.7225 = 8.179734
        assertApproxEqAbsDecimal(result.financingCost, 8.179734e6, 1, 6, "result.financingCost");

        // -collateral used + debt delta
        // 400 + 77.902234 = 322.097766
        assertApproxEqAbsDecimal(result.cost, 322.097766e6, 1, 6, "result.cost");

        assertTrue(result.needsBatchedCall, "result.needsBatchedCall");
        assertEq(result.quoteLendingLiquidity, quoteMaxBaseIn, "quoteLendingLiquidity");
        assertEq(result.baseLendingLiquidity, 0, "baseLendingLiquidity");
        assertFalse(result.insufficientLiquidity, "result.insufficientLiquidity");

        _assertLiquidity(result);
    }

    function testRemoveCollateralCost_Undercollateralised() public {
        // values for 2 ETHUSDC with 800 collateral position - taken from testCreatePositionOpenCost() test
        DataTypes.Balances memory balances = DataTypes.Balances({art: 602.134078e6, ink: 2e18});

        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, 0, -450e6);
        // under min collateral taken from testCreatePositionOpenCost() test

        assertEqDecimal(result.spotCost, 0, 6, "result.spotCost");

        // 2 * 0.945 (bid rate) = 1.89 ETH
        // valued at ETHUSD oracle price
        // 1.89 * 700 = 1323 USDC
        assertEqDecimal(result.underlyingCollateral, 1323e6, 6, "result.underlyingCollateral");

        assertEqDecimal(result.liquidationRatio, 1.4e6, 6, "result.liquidationRatio");
        // underlying collateral valued at 1323 USDC
        // after applying min CR (40%): 945 USDC
        // collateral value - existing debt
        // 945 - 602.134078 = 342.865922 refinancing room
        // 342.865922 * 0.895 (bid rate) = 306.865 USDC refinancing room value
        assertEqDecimal(result.minCollateral, -306.865e6, 6, "result.minCollateral");
        assertEqDecimal(result.collateralUsed, -306.865e6, 6, "result.collateralUsed");

        // how many fUSDC do I need, so that I can acquire 306.865 real USDC?
        // 306.865 / 0.895 (bid rate) = 342.865921 (could be rounded up if underlying protocol precision is greater than quote currency)
        // existing debt + new debt
        // 602.134078 + 342.865921 = 944.999999 USDC
        assertApproxEqAbsDecimal(result.underlyingDebt, 944.999999e6, 1, 6, "result.underlyingDebt");
        assertApproxEqAbsDecimal(result.debtDelta, 342.865921e6, 1, 6, "result.debtDelta");

        // debtDelta + deposited collateral
        // 342.865921 - 306.865 = 36.000921
        assertApproxEqAbsDecimal(result.financingCost, 36.000921e6, 1, 6, "result.financingCost");
        assertApproxEqAbsDecimal(result.cost, -36.000921e6, 1, 6, "result.cost");

        assertEqDecimal(result.minDebt, 100e6, 6, "result.minDebt");
        // (existing debt - min debt) * ask rate
        // (602.134078 - 100) * 0.905 = 454.43134 USDC max debt cost
        assertEqDecimal(result.maxCollateral, 454.43134e6, 6, "result.maxCollateral");

        assertFalse(result.needsBatchedCall, "result.needsBatchedCall");
        assertEq(result.quoteLendingLiquidity, 0, "quoteLendingLiquidity");
        assertEq(result.baseLendingLiquidity, 0, "baseLendingLiquidity");
        assertFalse(result.insufficientLiquidity, "result.insufficientLiquidity");

        _assertLiquidity(result);
    }

    function testCreatePositionOpenCost_NoBaseLendingLiquidity() public {
        // empty account since it's a new position
        DataTypes.Balances memory balances;

        // No liquidity for ETH lending
        _setPoolStubLiquidity({pool: yieldInstrument.basePool, borrowing: 1_000 ether, lending: 0});

        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, 2 ether, 800e6);

        // ETHUSDC: bid 699 / ask 701
        // 2 * 701 = 1402 USDC
        assertEqDecimal(result.spotCost, -1402e6, 6, "result.spotCost");

        assertEqDecimal(result.collateralUsed, 800e6, 6, "result.collateralUsed");

        // No base lending liquidity, therefore it's treated as 1:1
        // 2 * 701 = 1402 (total USDC needed)
        // 1402 - 800 (user collateral) = 602 (total USDC we need to borrow)
        // how many fUSDC do I need, so that I can acquire 602 real USDC?
        // 602 / 0.895 (bid rate) = 672.625698 (could be rounded up if underlying protocol precision is greater than quote currency)
        assertApproxEqAbsDecimal(result.underlyingDebt, 672.625698e6, 1, 6, "result.underlyingDebt");
        assertApproxEqAbsDecimal(result.debtDelta, 672.625698e6, 1, 6, "result.debtDelta");

        // sold fUSDC (debtDelta) - borrowed USDC
        // 672.625698 - 602 = 70.625698
        assertApproxEqAbsDecimal(result.financingCost, 70.625698e6, 1, 6, "result.financingCost");

        // collateral posted + debtDelta
        // 800 + 672.625698 = 1472.625698 USDC cost
        assertApproxEqAbsDecimal(result.cost, -1472.625698e6, 1, 6, "result.cost");

        // 2 fETH valued at bid rate 0.945 = 1.89 ETH
        // 1.89 ETH valued at ETHUSD oracle price 700 = 1323 USDC
        // TODO alfredo - check if haircut should be applied on this valuation and if it should look at bid prices
        assertEqDecimal(result.underlyingCollateral, 1323e6, 6, "result.underlyingCollateral");

        assertEqDecimal(result.liquidationRatio, 1.4e6, 6, "result.liquidationRatio");
        // underlying collateral valued at 1323 USDC
        // after applying min CR (40%): 945 USDC
        // 945 fUSDC can borrow at bid rate 0.895 = 845.775 USDC

        assertEqDecimal(result.minDebt, 100e6, 6, "result.minDebt");

        // swap cost - max borrowing
        // 1402 - 845.775 = 556.225 USDC min collateral
        assertEqDecimal(result.minCollateral, 556.225e6, 6, "result.minCollateral");
        // full swap payment
        // min debt 100 at bid rate 0.895 = min borrow 89.50 USDC
        // swap cost - min borrow
        // 1402 - 89.50 = 1312.50 USDC
        assertEqDecimal(result.maxCollateral, 1312.5e6, 6, "result.maxCollateral");

        assertFalse(result.needsBatchedCall, "result.needsBatchedCall");
        assertEq(result.quoteLendingLiquidity, 0, "quoteLendingLiquidity");
        assertEq(result.baseLendingLiquidity, 0, "baseLendingLiquidity");
        assertFalse(result.insufficientLiquidity, "result.insufficientLiquidity");

        // assertEqDecimal(result.basePoolLendingLiquidity, 0, 18, "result.basePoolLendingLiquidity");
        // assertEqDecimal(
        //     result.basePoolBorrowingLiquidity, 1058.201058201058201058 ether, 18, "result.basePoolBorrowingLiquidity"
        // );
        _assertQuoteLiquidity(result);
    }

    function testDecreasePositionCost_NoBaseBorrowingLiquidity() public {
        // values for 2 ETHUSDC with 800 collateral position - taken from testCreatePositionOpenCost() test
        DataTypes.Balances memory balances = DataTypes.Balances({art: 602.134078e6, ink: 2e18});

        // No liquidity for ETH borrowing
        _setPoolStubLiquidity({pool: yieldInstrument.basePool, borrowing: 0, lending: 1_000 ether});

        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, -0.5 ether, 0);

        // insufficient base borrowing liquidity for closing/decreasing, therefore no other value is calculated
        assertTrue(result.insufficientLiquidity, "result.insufficientLiquidity");
        assertFalse(result.needsBatchedCall, "result.needsBatchedCall");
        assertEq(result.quoteLendingLiquidity, 0, "quoteLendingLiquidity");
        assertEq(result.baseLendingLiquidity, 0, "baseLendingLiquidity");

        assertEqDecimal(result.spotCost, 0, 6, "result.spotCost");
        assertEqDecimal(result.collateralUsed, 0, 6, "result.collateralUsed");
        assertApproxEqAbsDecimal(result.underlyingDebt, 0, 1, 6, "result.underlyingDebt");
        assertApproxEqAbsDecimal(result.debtDelta, 0, 1, 6, "result.debtDelta");
        assertEqDecimal(result.financingCost, 0, 6, "result.financingCost");
        assertEqDecimal(result.cost, 0, 6, "result.cost");
        assertEqDecimal(result.underlyingCollateral, 0, 6, "result.underlyingCollateral");
        assertEqDecimal(result.minCollateral, 0, 6, "result.minCollateral");
        assertEqDecimal(result.maxCollateral, 0, 6, "result.maxCollateral");

        // assertEqDecimal(result.basePoolLendingLiquidity, 1000 ether, 18, "result.basePoolLendingLiquidity");
        // assertEqDecimal(result.basePoolBorrowingLiquidity, 0, 18, "result.basePoolBorrowingLiquidity");
        _assertQuoteLiquidity(result);
    }

    function testDecreasePositionCost_NoQuoteLendingLiquidity() public {
        // values for 2 ETHUSDC with 800 collateral position - taken from testCreatePositionOpenCost() test
        DataTypes.Balances memory balances = DataTypes.Balances({art: 602.134078e6, ink: 2e18});

        // No liquidity for USDC lending
        _setPoolStubLiquidity({pool: yieldInstrument.quotePool, borrowing: 1_000_000e6, lending: 0});

        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, -0.5 ether, 0);

        // ETHUSDC: bid 699 / ask 701
        // 0.5 * 699 = 349.50
        assertEqDecimal(result.spotCost, 349.5e6, 6, "result.spotCost");

        assertEqDecimal(result.collateralUsed, 0, 6, "result.collateralUsed");

        // 0.5 * 0.945 (bid rate) = 0.4725 ETH
        // 0.4725 * 699 = 330.2775 (total USDC received)
        // No liquidity for quote lending, so can only burn fUSDC 1:1
        // existing debt - burnt debt
        // 602.134078 - 330.2775 = 271.856578 fUSDC
        assertApproxEqAbsDecimal(result.underlyingDebt, 271.856578e6, 1, 6, "result.underlyingDebt");
        assertApproxEqAbsDecimal(result.debtDelta, -330.2775e6, 1, 6, "result.debtDelta");

        // bought 330.2775 fUSDC (debtDelta) - swapped 330.2775 USDC
        // 330.2775 - 330.2775 = 0
        assertEqDecimal(result.financingCost, 0, 6, "result.financingCost");

        // debtDelta 330.2775 USDC cost
        assertEqDecimal(result.cost, 330.2775e6, 6, "result.cost");

        // 1.5 fETH valued at bid rate 0.945 = 1.4175 ETH
        // 1.4175 ETH valued at ETHUSD oracle price 700 = 992.25 USDC
        // TODO alfredo - check if haircut should be applied on this valuation and if it should look at bid prices
        assertEqDecimal(result.underlyingCollateral, 992.25e6, 6, "result.underlyingCollateral");

        assertEqDecimal(result.liquidationRatio, 1.4e6, 6, "result.liquidationRatio");
        // underlying collateral valued at 992.25 USDC
        // after applying min CR (40%): 708.75 USDC
        // collateral value 708.75 - existing debt 602.134078 = 106.615922 refinancing room
        // 106.615922 * 0.895 (bid rate) = 95.42125 USDC refinancing room value
        // swap cost recovered 330.2775 + refinancing room value 95.42125 = 425.69875 free collateral
        assertEqDecimal(result.minCollateral, -425.69875e6, 6, "result.minCollateral");

        assertEqDecimal(result.minDebt, 100e6, 6, "result.minDebt");
        // No liquidity for quote lending, so can only burn fUSDC 1:1
        // existing debt - min debt
        // 602.134078 - 100 = 502.134078 USDC max debt cost
        // max debt cost - swap cost recovered
        // 502.134078 - 330.2775 = 171.856578 USDC
        assertEqDecimal(result.maxCollateral, 171.856578e6, 6, "result.maxCollateral");

        assertFalse(result.needsBatchedCall, "result.needsBatchedCall");
        assertEq(result.quoteLendingLiquidity, 0, "quoteLendingLiquidity");
        assertEq(result.baseLendingLiquidity, 0, "baseLendingLiquidity");
        assertFalse(result.insufficientLiquidity, "result.insufficientLiquidity");

        _assertBaseLiquidity(result);
        // assertEqDecimal(result.quotePoolLendingLiquidity, 0, 6, "result.quotePoolLendingLiquidity");
        // assertEqDecimal(result.quotePoolBorrowingLiquidity, 1_117_318.435754e6, 6, "result.quotePoolBorrowingLiquidity");
    }

    function testCreatePositionOpenCost_NoQuoteBorrowingLiquidity() public {
        // empty account since it's a new position
        DataTypes.Balances memory balances;

        // No liquidity for USDC borrowing
        _setPoolStubLiquidity({pool: yieldInstrument.quotePool, borrowing: 0, lending: 1_000_000e6});

        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, 2 ether, 800e6);

        // insufficient quote borrowing liquidity for opening/increasing, therefore no other value is calculated
        assertTrue(result.insufficientLiquidity, "result.insufficientLiquidity");
        assertFalse(result.needsBatchedCall, "result.needsBatchedCall");
        assertEq(result.quoteLendingLiquidity, 0, "quoteLendingLiquidity");
        assertEq(result.baseLendingLiquidity, 0, "baseLendingLiquidity");

        assertEqDecimal(result.spotCost, 0, 6, "result.spotCost");
        assertEqDecimal(result.collateralUsed, 0, 6, "result.collateralUsed");
        assertApproxEqAbsDecimal(result.underlyingDebt, 0, 1, 6, "result.underlyingDebt");
        assertApproxEqAbsDecimal(result.debtDelta, 0, 1, 6, "result.debtDelta");
        assertEqDecimal(result.financingCost, 0, 6, "result.financingCost");
        assertEqDecimal(result.cost, 0, 6, "result.cost");
        assertEqDecimal(result.underlyingCollateral, 0, 6, "result.underlyingCollateral");
        assertEqDecimal(result.minCollateral, 0, 6, "result.minCollateral");
        assertEqDecimal(result.maxCollateral, 0, 6, "result.maxCollateral");

        _assertBaseLiquidity(result);
        // assertEqDecimal(result.quotePoolLendingLiquidity, 905_000e6, 6, "result.quotePoolLendingLiquidity");
        // assertEqDecimal(result.quotePoolBorrowingLiquidity, 0, 6, "result.quotePoolBorrowingLiquidity");
    }

    function testCreatePositionOpenCost_LimitedQuoteBorrowingLiquidity() public {
        // empty account since it's a new position
        DataTypes.Balances memory balances;

        // limited liquidity for USDC borrowing (minDebt)
        _setPoolStubLiquidity({pool: yieldInstrument.quotePool, borrowing: 100e6, lending: 1_000_000e6});

        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, 2 ether, 800e6);

        // ETHUSDC: bid 699 / ask 701
        // 2 * 701 = 1402 USDC
        assertEqDecimal(result.spotCost, -1402e6, 6, "result.spotCost");

        // how much ETH do we need today (PV) to have 2 ETH at expiry?
        // 2 * 0.955 (ask rate) = 1.91 ETH
        // 1.91 * 701 = 1338.91 (total USDC needed)

        // only 100 USDC borrowing liquidity
        // swap cost - max borrowing
        // 1338.91 - 100 = 1238.91 USDC min collateral
        // TODO alfredo - why do we have this off by one? approx eq masks it
        assertEqDecimal(result.minCollateral, 1238.910001e6, 6, "result.minCollateral");
        assertEqDecimal(result.collateralUsed, 1238.910001e6, 6, "result.collateralUsed");
        assertApproxEqAbsDecimal(result.minCollateral, 1238.91e6, 1, 6, "result.minCollateral");
        assertApproxEqAbsDecimal(result.collateralUsed, 1238.91e6, 1, 6, "result.collateralUsed");

        // 1338.91 - 1238.91 (user collateral) = 100 (total USDC we need to borrow)
        // how many fUSDC do I need, so that I can acquire 100 real USDC?
        // 100 / 0.895 (bid rate) = 111.731843 (could be rounded up if underlying protocol precision is greater than quote currency)
        // TODO alfredo -  the above quote is not accurate since it doesn't represent the yield curve close to the liquidity edge
        assertApproxEqAbsDecimal(result.underlyingDebt, 111.731843e6, 1, 6, "result.underlyingDebt");
        assertApproxEqAbsDecimal(result.debtDelta, 111.731843e6, 1, 6, "result.debtDelta");

        // sold fUSDC (debtDelta) - borrowed
        // 111.731843 - 100 = 11.731843
        assertApproxEqAbsDecimal(result.financingCost, 11.731843e6, 1, 6, "result.financingCost");

        // collateral posted + debtDelta
        // 1238.91 + 111.731843 = 1350.641843 USDC cost
        assertApproxEqAbsDecimal(result.cost, -1350.641843e6, 1, 6, "result.cost");

        // 2 fETH valued at bid rate 0.945 = 1.89 ETH
        // 1.89 ETH valued at ETHUSD oracle price 700 = 1323 USDC
        // TODO alfredo - check if haircut should be applied on this valuation and if it should look at bid prices
        assertEqDecimal(result.underlyingCollateral, 1323e6, 6, "result.underlyingCollateral");

        assertEqDecimal(result.liquidationRatio, 1.4e6, 6, "result.liquidationRatio");
        // underlying collateral valued at 1323 USDC
        // after applying min CR (40%): 945 USDC
        // 945 fUSDC can borrow at bid rate 0.895 = 845.775 USDC

        assertEqDecimal(result.minDebt, 100e6, 6, "result.minDebt");
        // full swap payment
        // min debt 100 at bid rate 0.895 = min borrow 89.50 USDC
        // swap cost 1338.91 - min borrow 89.50 = 1249.41 USDC
        assertEqDecimal(result.maxCollateral, 1249.41e6, 6, "result.maxCollateral");

        assertFalse(result.needsBatchedCall, "result.needsBatchedCall");
        assertEq(result.baseLendingLiquidity, baseMaxFYTokenOut, "baseLendingLiquidity");
        assertEq(result.quoteLendingLiquidity, 0, "quoteLendingLiquidity");
        assertFalse(result.insufficientLiquidity, "result.insufficientLiquidity");

        _assertBaseLiquidity(result);
        // assertEqDecimal(result.quotePoolLendingLiquidity, 905_000e6, 6, "result.quotePoolLendingLiquidity");
        // assertEqDecimal(result.quotePoolBorrowingLiquidity, 111.731843e6, 6, "result.quotePoolBorrowingLiquidity");
    }

    // same as before except:
    // maxCollateral: 1338.91 -> 2103.91
    function testIncreaseCostLongMinCollateralDiscovery() public {
        DataTypes.Balances memory balances = DataTypes.Balances({art: 945e6, ink: 2e18});

        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, 2 ether, 0);

        assertEqDecimal(result.cost, -1438.135e6, 6, "cost");
        assertEqDecimal(result.minCollateral, 493.135e6, 6, "minCollateral");
        assertEq(result.collateralUsed, result.minCollateral, "collateralUsed");
        // quote qty: 1338.91
        // 945 - 100 = 845
        // 845 * 0.905 = 764.725
        // 1338.91 + 764.725 = 2103.635
        assertEqDecimal(result.maxCollateral, 2103.635e6, 6, "maxCollateral");
        assertEqDecimal(result.underlyingDebt, 1890e6, 6, "underlyingDebt");
        assertEqDecimal(result.underlyingCollateral, 2646e6, 6, "underlyingCollateral");
        assertEqDecimal((result.underlyingCollateral * 1e6) / result.underlyingDebt, 1.4e6, 6, "collRatio");
        assertEqDecimal(result.liquidationRatio, 1.4e6, 6, "liquidationRatio");
    }

    // same as before except:
    // maxCollateral: 1338.91 -> 2103.91
    function testIncreaseCostLongNoExistingFreeCollateralNewCollateralAboveMinimum() public {
        DataTypes.Balances memory balances = DataTypes.Balances({art: 945e6, ink: 2e18});

        int256 collateral = 600e6;
        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, 2 ether, collateral);

        assertEqDecimal(result.cost, -1425.597765e6, 6, "cost");
        assertEqDecimal(result.minCollateral, 493.135e6, 6, "minCollateral");
        assertEq(result.collateralUsed, collateral, "collateralUsed");
        // quote qty: 1338.91
        // 945 - 100 = 845
        // 845 * 0.905 = 764.725
        // 1338.91 + 764.725 = 2103.635
        assertEqDecimal(result.maxCollateral, 2103.635e6, 6, "maxCollateral");
        assertEqDecimal(result.underlyingDebt, 1770.597765e6, 6, "underlyingDebt");
        assertEqDecimal(result.underlyingCollateral, 2646e6, 6, "underlyingCollateral");
        assertEqDecimal((result.underlyingCollateral * 1e6) / result.underlyingDebt, 1.49441e6, 6, "collRatio");
        assertEqDecimal(result.liquidationRatio, 1.4e6, 6, "liquidationRatio");
    }

    // same as before except:
    // maxCollateral: 1338.91 -> 1972.41
    function testIncreaseCostLongExistingFreeCollateralNewCollateralAboveMinimum() public {
        // 945 is the max amount we can borrow (see test above).
        // Therefore, in this position, we have 145 fyUSDC of free collateral.
        DataTypes.Balances memory balances = DataTypes.Balances({art: 800e6, ink: 2e18});

        int256 collateral = 600e6;
        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, 2 ether, collateral);

        assertEqDecimal(result.cost, -1425.597765e6, 6);
        assertEqDecimal(result.minCollateral, 363.36e6, 6, "minCollateral");
        assertEq(result.collateralUsed, collateral, "collateralUsed");
        // quote qty: 1338.91
        // 800 - 100 = 700
        // 700 * 0.905 = 633.5
        // 1338.91 + 633.5 = 1972.41
        assertEqDecimal(result.maxCollateral, 1972.41e6, 6, "maxCollateral");
        assertEqDecimal(result.underlyingDebt, 1625.597765e6, 6, "underlyingDebt");
        assertEqDecimal(result.underlyingCollateral, 2646e6, 6, "underlyingCollateral");
        assertEqDecimal((result.underlyingCollateral * 1e6) / result.underlyingDebt, 1.627708e6, 6, "collRatio");
        assertEqDecimal(result.liquidationRatio, 1.4e6, 6, "liquidationRatio");
    }

    // new test intended to test the min/max collateral when qty: 0, collateral: 0
    function testModifyPositionMinMaxCollateral() public {
        // 945 is the max amount we can borrow (see test above).
        // Therefore, in this position, we have 645 fyUSDC of free collateral.
        DataTypes.Balances memory balances = DataTypes.Balances({art: 300e6, ink: 2e18});

        int256 collateral = 0;
        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, 0, collateral);

        // We have 645 fyUSDC of free collateral.
        // To get the USDC value, we hit the bid rate on the quote pool
        // 645 * 0.895 = 577,275
        assertEqDecimal(result.minCollateral, -577.275e6, 6, "minCollateral");

        assertEq(result.cost, 0);
        assertEq(result.collateralUsed, collateral, "collateralUsed");

        // min debt is 100 fyUSDC
        // current debt is 300 fyUSDC (balances.art)
        // maxCollateral is equal to USDC cost of acquiring 200 fyUSDC
        // we hit the ask rate on the quote pool
        // 200 * 0.905 = 181
        assertEqDecimal(result.maxCollateral, 181e6, 6, "maxCollateral");

        // balances.art == 300
        assertEqDecimal(result.underlyingDebt, 300e6, 6, "underlyingDebt");
        assertEqDecimal(result.underlyingCollateral, 1323e6, 6, "underlyingCollateral");
        assertEqDecimal((result.underlyingCollateral * 1e6) / result.underlyingDebt, 4.41e6, 6, "collRatio");
        assertEqDecimal(result.liquidationRatio, 1.4e6, 6, "liquidationRatio");
    }

    // same as before except:
    // minCollateral: 0 -> -84.14
    // maxCollateral: 1338.91 -> 1519.91
    function testIncreaseCostLongLotsOfExistingFreeCollateralNoNewCollateral() public {
        // 945 is the max amount we can borrow (see test above).
        // Therefore, in this position, we have 645 fyUSDC of free collateral.
        DataTypes.Balances memory balances = DataTypes.Balances({art: 300e6, ink: 2e18});

        int256 collateral = 0;
        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, 2 ether, collateral);

        assertEqDecimal(result.cost, -1495.988826e6, 6);
        // minCollateral for opening long of 2 ETH is 493.135 (see openingCostMinDiscovery)
        // max that you can withdraw if not changing qty is 577.275 (see test above)
        // -577.275 + 493.135 = -84.14
        assertEqDecimal(result.minCollateral, -84.14e6, 6, "minCollateral");
        assertEq(result.collateralUsed, collateral, "collateralUsed");
        // quote qty + PV of 200 fyUSDC (300 - 100 (min debt))
        assertEqDecimal(result.maxCollateral, 1519.91e6, 6, "maxCollateral");
        assertEqDecimal(result.underlyingDebt, 1795.988826e6, 6, "underlyingDebt");
        assertEqDecimal(result.underlyingCollateral, 2646e6, 6, "underlyingCollateral");
        assertEqDecimal((result.underlyingCollateral * 1e6) / result.underlyingDebt, 1.473283e6, 6, "collRatio");
        assertEqDecimal(result.liquidationRatio, 1.4e6, 6, "liquidationRatio");
    }

    function testClosingCostLongPartialClose() public {
        DataTypes.Balances memory balances = DataTypes.Balances({art: 945e6, ink: 2e18});

        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, -1 ether, 0);

        // 1 fyETH -> 0.945 ETH
        // 0.945 ETH * 699 = 660.555 USDC
        // maxDebt after modify = 472.5 fyUSDC
        // current debt is 945 fyUSDC, max debt after modify is 472.5. We need to burn the difference.
        // How much USDC does it cost to acquire 472.5 fyUSDC?
        // 472.5 * 0.905 = 427.6125
        // 427.6125 - 660.555 = -232.9425
        assertEqDecimal(result.minCollateral, -232.9425e6, 6);

        // 945 - 100 = 845 (current debt - min debt) aka the max amount of debt that can be burned
        // 845 * 0.905 = 764.725 (how much does it cost to acquire this amount of fyTokens?)
        // 764.725 - 660.555 = 104,17 (the cost to acquire fyTokens - what we get from uni)
        assertEqDecimal(result.maxCollateral, 104.17e6, 6);

        assertEq(result.collateralUsed, 0, "collateralUsed");

        assertEqDecimal(result.cost, 729.895027e6, 6, "cost");
        assertEqDecimal(result.underlyingDebt, 215.104973e6, 6, "underlyingDebt");
        assertEqDecimal(result.underlyingCollateral, 661.5e6, 6, "underlyingCollateral");
        assertEqDecimal((result.underlyingCollateral * 1e6) / result.underlyingDebt, 3.075242e6, 6);
        assertEqDecimal(result.liquidationRatio, 1.4e6, 6, "liquidationRatio");
    }

    function testClosingCostLongPartialCloseVerifyCost() public {
        // ----- REFERENCE VALUES ----- //
        DataTypes.Balances memory balances = DataTypes.Balances({art: 0, ink: 0});
        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, 1.75 ether, 0);

        assertEqDecimal(result.minCollateral, 431.493125e6, 6);
        assertEqDecimal(result.maxCollateral, 1082.04625e6, 6);
        assertEqDecimal(result.cost, -1258.368125e6, 6, "cost");
        assertEqDecimal(result.underlyingDebt, 826.875e6, 6, "underlyingDebt");

        // this tells us that, creating a position of qty 1.75, that is at the max debt limits, yields a open cost of 1258.368125
        // this means that the forward price is: 1258.368125 / 1.75 = 719.0675
        // ----------- END ------------ //

        // Assumptions: creating a position of qty 2, with some excess collateral (above min),
        // and then decreasing it by 0.25, and withdrawing the maximum allowed, should yield an open cost
        // That is slightly bigger than in the reference values above, but still pretty close
        // (reason why it should be higher is that you'll be crossing the spread when selling 0.25 of the hedge)
        ModifyCostResult memory openingResult =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, 2 ether, 800e6);

        assertEqDecimal(openingResult.cost, -1402.134078e6, 6, "openingResult.cost");
        assertEqDecimal(openingResult.underlyingDebt, 602.134078e6, 6, "openingResult.underlyingDebt");

        // forward price: 1402.134078 / 2 = 701,067039

        DataTypes.Balances memory balances2 =
            DataTypes.Balances({art: uint128(openingResult.underlyingDebt), ink: 2 ether});
        ModifyCostResult memory decreaseResult =
            testQuoter.modifyCostForLongPosition(balances2, instrument, yieldInstrument, -0.25 ether, -1000e6);

        assertEqDecimal(decreaseResult.cost, 141.540954e6, 6, "decreaseResult.cost");

        int256 resultingCostAfterDecrease = openingResult.cost + decreaseResult.cost;
        // we can see here that the assumptions are true. Its slightly higher than in the reference values test, yet pretty close (1258 vs 1260)
        assertEqDecimal(resultingCostAfterDecrease, -1260.593124e6, 6, "resultingCostAfterDecrease");
        assertApproxEqAbs(result.cost, resultingCostAfterDecrease, 2.5e6, "are costs roughly equal?");

        // forward price: 1260.593124 / 1.75 = 720,338928
    }

    // NEW TEST
    // We partially close, but withdraw more than what we get from the spot market (resulting in debt increase)
    function testClosingCostLongPartialCloseWithdrawMoreThanWeGetFromSpot() public {
        // We start with a position that has the min debt, so 845 fyUSDC of financing room
        DataTypes.Balances memory balances = DataTypes.Balances({art: 100e6, ink: 2e18});

        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, -1 ether, 0);

        // 1 fyETH -> 0.945 ETH
        // 0.945 ETH * 699 = 660.555 USDC
        // maxDebt after modify = 472.5 fyUSDC
        // current debt is 100 fyUSDC, max debt after modify is 472.5.
        // We don't need to burn any debt, we actually have 372.5 fyUSDC of refinancing room.
        // How much USDC can we get for selling 372.5 fyUSDC?
        // 372.5 * 0.895 = 333.3875
        // -333.3875 - 660.555 = -993.9425
        assertEqDecimal(result.minCollateral, -993.9425e6, 6);

        // We're already at the minimum debt requirements.
        // We'll need to withdraw the entirety of what we get from the spot market
        assertEqDecimal(result.maxCollateral, -660.555e6, 6);

        assertEq(result.collateralUsed, result.maxCollateral, "collateralUsed");

        assertEqDecimal(result.cost, 660.555e6, 6, "cost");
        // underlying debt is still 100
        assertEqDecimal(result.underlyingDebt, 100e6, 6, "underlyingDebt");
        assertEqDecimal(result.underlyingCollateral, 661.5e6, 6, "underlyingCollateral");
        assertEqDecimal((result.underlyingCollateral * 1e6) / result.underlyingDebt, 6.615e6, 6);
        assertEqDecimal(result.liquidationRatio, 1.4e6, 6, "liquidationRatio");
    }

    // NEW TEST
    // We partially close, and withdraw the maximum we can (refinance up to max debt)
    function testClosingCostLongPartialCloseWithdrawMaximum() public {
        // We start with a position that has the min debt, so 845 fyUSDC of financing room
        DataTypes.Balances memory balances = DataTypes.Balances({art: 100e6, ink: 2e18});

        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, -1 ether, -1000e6);

        // 1 fyETH -> 0.945 ETH
        // 0.945 ETH * 699 = 660.555 USDC
        // maxDebt after modify = 472.5 fyUSDC
        // current debt is 100 fyUSDC, max debt after modify is 472.5.
        // We don't need to burn any debt, we actually have 372.5 fyUSDC of refinancing room.
        // How much USDC can we get for selling 372.5 fyUSDC?
        // 372.5 * 0.895 = 333.3875
        // -333.3875 - 660.555 = -993.9425
        assertEqDecimal(result.minCollateral, -993.9425e6, 6);

        // We're already at the minimum debt requirements.
        // We'll need to withdraw the entirety of what we get from the spot market
        assertEqDecimal(result.maxCollateral, -660.555e6, 6);

        assertEq(result.collateralUsed, result.minCollateral, "collateralUsed");

        // cost should be: what we need to pay on the spot + the interest paid on the refinancing
        // previous debt was: 100 -> max debt after modify is: 472.5 -> difference is: 372.5
        // we issue debt of 372.5 fyUSDC, and then sell them in the market
        // how much USDC do we get for 372.5 fyUSDC?
        // 372.5 * 0.895 = 333.3875
        // difference: 372.5 - 333.3875 = 39.1125
        // cost: 660.555 - 39.1125 = 621.4425
        assertEqDecimal(result.cost, 621.4425e6, 6, "cost");
        // underlying debt should be equal to max debt after modify: 472.5
        assertEqDecimal(result.underlyingDebt, 472.5e6, 6, "underlyingDebt");
        assertEqDecimal(result.underlyingCollateral, 661.5e6, 6, "underlyingCollateral");
        assertEqDecimal((result.underlyingCollateral * 1e6) / result.underlyingDebt, 1.4e6, 6);
        assertEqDecimal(result.liquidationRatio, 1.4e6, 6, "liquidationRatio");
    }

    // NEW TEST
    // We partially close, withdraw less than we get from the spot, but not so little that we're at the min debt
    function testClosingCostLongPartialCloseWithdrawMoreThanWeGetFromSpotAndMoreThanTheMin() public {
        // We start with a position that has 500 fyUSDC debt, so we have 445 fyUSDC of financing room
        DataTypes.Balances memory balances = DataTypes.Balances({art: 500e6, ink: 2e18});

        int256 collateral = -400e6;
        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, -1 ether, collateral);

        // 1 fyETH -> 0.945 ETH
        // 0.945 ETH * 699 = 660.555 USDC
        // maxDebt after modify = 472.5 fyUSDC
        // current debt is 500 fyUSDC, max debt after modify is 472.5
        // We need to burn the difference: 27.5
        // How much does it cost to acquire 27.5 fyUSDC?
        // we hit the ask rate on the quote pool: 27.5 * 0.905 = 24.8875
        // 24.8875 - 660.555 = -635.6675
        assertEqDecimal(result.minCollateral, -635.6675e6, 6);

        // current debt 500. min debt 100. difference: 400 (aka. max debt we can burn)
        // how much does it cost to acquire 400 fyUSDC?
        // 400 * 0.905 = 362 (aka. maximum amount we can use towards repaying our loan)
        // 362 - 660.555 = -298.555
        assertEqDecimal(result.maxCollateral, -298.555e6, 6);

        assertEq(result.collateralUsed, collateral, "collateralUsed");

        // 660.555 - 400 = 260.555 (amount used to repay debt)
        // how much fyUSDC we get for that? 260.555 / 0.905 = 287.906077
        // 500 - 287.906077 = 212.093923
        assertEqDecimal(result.underlyingDebt, 212.093923e6, 6, "underlyingDebt");
        assertEqDecimal(result.underlyingCollateral, 661.5e6, 6, "underlyingCollateral");

        // 660.555 from spot
        // quote used to repay debt: 260.555
        // how much debt did we cancel with that?
        // 260.555 / 0.905 = 287.906077
        // financing cost (cost recovered): 287.906077 - 260.555 = 27.351077
        // 660.555 + 27.351077 = 687.906077
        assertEqDecimal(result.cost, 687.906077e6, 6, "cost");

        assertEqDecimal((result.underlyingCollateral * 1e6) / result.underlyingDebt, 3.118901e6, 6);
        assertEqDecimal(result.liquidationRatio, 1.4e6, 6, "liquidationRatio");
    }

    function testClosingCostLongPartialCloseNegativeMaxColl() public {
        DataTypes.Balances memory balances = DataTypes.Balances({art: 945e6, ink: 2e18});

        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, -1.5 ether, 0);

        // 1.5 fyETH -> 1.4175 ETH
        // 1.4175 ETH * 699 = 990.8325 USDC
        // maxDebt after modify = 236.25 fyUSDC
        // current debt is 945 fyUSDC, max debt after modify is 236.25. We need to burn the difference.
        // How much USDC does it cost to acquire 708.75 fyUSDC?
        // 708.75 * 0.905 = 641.41875
        // 641.41875 - 990.8325 = -349.41375
        assertEqDecimal(result.minCollateral, -349.41375e6, 6);

        // money we get from uniswap: 990.8325 USDC
        // how much debt can we burn with that?
        // we hit the ask rate on the quote pool (ask rate: 0.905)
        // 990.8325 / 0.905 = 1094.8425414365 fyUSDC
        // The resulting debt would be: 945 - 1094.8425414365 = -149.8425414365
        // Resulting debt: -149.8425414365 fyUSDC
        // min debt: 100

        // ----- //
        // 945 - 100 = 845
        // 845 * 0.905 = 764.725
        // 764.725 - 990.8325 = -226.1075
        assertEqDecimal(result.maxCollateral, -226.1075e6, 6);

        // if the collateral parameter passed to the quoting function is above the max, we use the max
        // max collateral in this case can be thought of as:
        // "what is the minimum amount that I need to withdraw, along with this decrease (so I don't breach the min debt requirements)"
        assertEq(result.collateralUsed, result.maxCollateral, "collateralUsed");

        // do cost calculation and verify
        assertEqDecimal(result.cost, 1071.1075e6, 6, "cost");
        // underlyingDebt == minDebt
        assertEqDecimal(result.underlyingDebt, 100e6, 6, "underlyingDebt");

        // 0.5 fyETH * 0.945 (bid rate on base pool) = 0.4725 ETH
        // 0.4725 * 700 = 330.75
        assertEqDecimal(result.underlyingCollateral, 330.75e6, 6, "underlyingCollateral");

        assertEqDecimal((result.underlyingCollateral * 1e6) / result.underlyingDebt, 3.3075e6, 6);
        assertEqDecimal(result.liquidationRatio, 1.4e6, 6, "liquidationRatio");
    }

    function testClosingCostLongPartialCloseNegativeMaxCollWithdrawMoreThanMin() public {
        // This test is a copy paste of the test above. Here I want to test the scenario
        // where the max coll is negative (you have to withdraw funds), yet the trader is
        // withdrawing more than the min (the min being: max collateral - which is negative)
        DataTypes.Balances memory balances = DataTypes.Balances({art: 945e6, ink: 2e18});

        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, -1.5 ether, -300e6);

        // the min collateral is calculated the same way as above.
        assertEqDecimal(result.minCollateral, -349.41375e6, 6);

        // max collateral is the same as in the test above
        assertEqDecimal(result.maxCollateral, -226.1075e6, 6);

        // if the collateral parameter passed to the quoting function is above the max, we use the max
        // max collateral in this case can be thought of as:
        // "what is the minimum amount that I need to withdraw, along with this decrease (so I don't breach the min debt requirements)"
        assertEqDecimal(result.collateralUsed, -300e6, 6, "collateralUsed");

        // do cost calculation and verify
        // cost should be lower than in test above! (lower closing cost == worse)
        assertEqDecimal(result.cost, 1063.350828e6, 6, "cost");

        // money we get from uniswap?: 990.8325 USDC
        // how much cash does the trader want to withdraw? 300
        // USDC we have remaining, and can be used to burn debt: 990.8325 - 300 = 690.8325
        // we hit the ask rate on the quote pool (ask rate: 0.905)
        // 690.8325 / 0.905 = 763.350829 fyUSDC
        // The resulting debt would be: 945 - 763.350829 = 181.649171 fyUSDC
        assertEqDecimal(result.underlyingDebt, 181.649172e6, 6, "underlyingDebt");

        // 0.5 fyETH * 0.945 (bid rate on base pool) = 0.4725 ETH
        // 0.4725 * 700 = 330.75
        // (same as above!)
        assertEqDecimal(result.underlyingCollateral, 330.75e6, 6, "underlyingCollateral");

        // 330.75 / 181.649171 = 1.820818
        assertEqDecimal((result.underlyingCollateral * 1e6) / result.underlyingDebt, 1.820817e6, 6);
        assertEqDecimal(result.liquidationRatio, 1.4e6, 6, "liquidationRatio");
    }

    function testClosingCostLongPartialCloseInsufficientLiquidityOnBasePool() public {
        DataTypes.Balances memory balances = DataTypes.Balances({art: 945e6, ink: 2e18});

        _setPoolStubLiquidity(yieldInstrument.basePool, 0.5e18);

        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, -1 ether, 0);

        assertTrue(result.insufficientLiquidity, "insufficientLiquidity");
        assertEq(result.quoteLendingLiquidity, 0, "quoteLendingLiquidity");
        assertEq(result.baseLendingLiquidity, 0, "baseLendingLiquidity");
    }

    function testClosingCostLongPartialCloseNeedsForce() public {
        DataTypes.Balances memory balances = DataTypes.Balances({art: 945e6, ink: 2e18});

        quoteMaxFYTokenOut = 552.486188e6;
        _setPoolStubLiquidity({pool: yieldInstrument.quotePool, borrowing: 1_000_000e6, lending: quoteMaxFYTokenOut});
        quoteMaxBaseIn = 500e6; // 552.486188 * .905

        int256 collateral = 0;
        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, -1 ether, collateral);

        // 1 fyETH -> 0.945 ETH
        // 0.945 ETH * 699 = 660.555 USDC
        // maxDebt after modify = 472.5 fyUSDC
        // current debt is 945 fyUSDC, max debt after modify is 472.5. We need to burn the difference.
        // How much USDC does it cost to acquire 472.5 fyUSDC?
        // 472.5 * 0.905 = 427.6125
        // 427.6125 - 660.555 = -232.9425
        assertEqDecimal(result.minCollateral, -232.9425e6, 6);

        // currentDebt: 945 fyUSDC
        // minDebt: 100 fyUSDC
        // max debt that can be repaid: 945 - 100 = 845
        // in theory, the max debt that can be burned is 845 fyUSDC, but the avail liquidity on the lending side is only 500!

        // Therefore:
        // The max amount of USDC we can use to buy fyTokens is 500.
        // 500 / 0.905 = 552.486188 fyUSDC
        // 845 - 552.486188 = 292.513813
        // 292.513813: this is the amount of fyUSDC debt that we'll have to mint 1:1 to repay down to min debt limits
        // We get 660.555 from the spot market
        // we need to withdraw the difference: (500 + 292.513813) - 660.555 = 131.958813
        assertEqDecimal(result.maxCollateral, 131.958812e6, 6);

        // we get 660.555 USDC from the spot market.
        // available liquidity for lending on the quote pool is 500 USDC,
        // so given our collateral input of 0, we assume a partial repayment of debt at 1:1 (use real USDC to mint fyUSDC at 1:1)
        assertEq(result.quoteLendingLiquidity, quoteMaxBaseIn, "quoteLendingLiquidity");
        assertEq(result.baseLendingLiquidity, 0, "baseLendingLiquidity");

        // this should only be true if there we are unable to perform modification under any circumstances
        // we can only force liquidity on the lending side.
        assertFalse(result.insufficientLiquidity, "insufficientLiquidity");

        // Our collateral input (0) is within the allowed range (between min and max)
        assertEq(result.collateralUsed, collateral);

        // 0.945 * 699 = 660.555 (whatever you got out of the spot market)
        // 660.555 + 52.48 = 713.035
        // (500 - 552.48) = 52.48 (financing cost recovered by repaying loan early)
        // 660.555 + 52.48 = 713.035
        // 660.555 - x = 552.48
        // 660.555 - 552.48 = 108.075
        assertEqDecimal(result.cost, 713.041187e6, 6, "cost");

        // previous debt: 945 fyUSDC
        // we got 660.555 out of the spot market, all of which we used to repay debt
        // how much were we able to reduce our debt?

        // first, we used 500 (the available liquidity) to buy fyUSDC from the pool.
        // 500 / 0.905 = 552.486188 fyUSDC

        // we used the remainder: 660.555 - 500 = 160.555 to mint fyUSDC at 1:1 --> 160.555 fyUSDC

        // result: 945 - (552.486188 + 160.555) = 231.958813
        assertEqDecimal(result.underlyingDebt, 231.958813e6, 6, "underlyingDebt");
        assertEqDecimal(result.underlyingCollateral, 661.5e6, 6, "underlyingCollateral");
        // result.underlyingCollateral / result.underlyingDebt
        assertEqDecimal((result.underlyingCollateral * 1e6) / result.underlyingDebt, 2.851799e6, 6);
        assertEqDecimal(result.liquidationRatio, 1.4e6, 6, "liquidationRatio");
    }

    // same as before, but min debt is now 100 -> therefore closing cost is lower
    function testClosingCostLongPartialCloseExcessQuote() public {
        DataTypes.Balances memory balances = DataTypes.Balances({art: 945e6, ink: 2e18});

        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, -1.5 ether, 0);

        assertEqDecimal(result.cost, 1071.1075e6, 6, "cost");
        // we don't assume full repayment of debt. Only repaid to the point where debt equals min
        assertEqDecimal(result.underlyingDebt, 100e6, 6, "underlyingDebt");
        assertEqDecimal(result.underlyingCollateral, 330.75e6, 6, "underlyingCollateral");
        assertEqDecimal(result.liquidationRatio, 1.4e6, 6, "liquidationRatio");
    }

    function testClosingCostLongFullyCloseNoExistingDebt() public {
        DataTypes.Balances memory balances = DataTypes.Balances({art: 0, ink: 0.5e18});

        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, -0.5 ether, 0);

        // 0.4725 * 699 = 330.2775 (whatever you got out of the spot market)
        assertEqDecimal(result.cost, 330.2775e6, 6, "cost");
        assertEq(result.underlyingDebt, 0, "underlyingDebt");
        assertEq(result.underlyingCollateral, 0, "underlyingCollateral");
        assertEqDecimal(result.liquidationRatio, 1.4e6, 6, "liquidationRatio");
    }

    function testClosingCostLongFullyCloseNeedsForce() public {
        DataTypes.Balances memory balances = DataTypes.Balances({art: 945e6, ink: 2e18});

        quoteMaxFYTokenOut = 500e6;
        _setPoolStubLiquidity({pool: yieldInstrument.quotePool, borrowing: 1_000_000e6, lending: quoteMaxFYTokenOut});

        ModifyCostResult memory result =
            testQuoter.modifyCostForLongPosition(balances, instrument, yieldInstrument, -2 ether, 0);

        assertEqDecimal(result.cost, 1368.61e6, 6, "cost");
        assertEq(result.underlyingDebt, 0, "underlyingDebt");
        assertEq(result.underlyingCollateral, 0, "underlyingCollateral");
        assertEq(result.quoteLendingLiquidity, quoteMaxFYTokenOut, "quoteLendingLiquidity");
        assertEq(result.baseLendingLiquidity, 0, "baseLendingLiquidity");
        assertEqDecimal(result.liquidationRatio, 1.4e6, 6, "liquidationRatio");
    }

    function _assertLiquidity(ModifyCostResult memory result) private {
        _assertBaseLiquidity(result);
        _assertQuoteLiquidity(result);
    }

    function _assertBaseLiquidity(ModifyCostResult memory result) private {
        // assertEqDecimal(result.basePoolLendingLiquidity, 1000 ether, 18, "result.basePoolLendingLiquidity");
        // assertEqDecimal(
        //     result.basePoolBorrowingLiquidity, 1058.201058201058201058 ether, 18, "result.basePoolBorrowingLiquidity"
        // );
    }

    function _assertQuoteLiquidity(ModifyCostResult memory result) private {
        // assertEqDecimal(result.quotePoolLendingLiquidity, 905_000e6, 6, "result.quotePoolLendingLiquidity");
        // assertEqDecimal(result.quotePoolBorrowingLiquidity, 1_117_318.435754e6, 6, "result.quotePoolBorrowingLiquidity");
    }
}

contract TestQuoter is ContangoYieldQuoter {
    // solhint-disable no-empty-blocks
    constructor(ContangoPositionNFT _positionNFT, ContangoYield _contangoYield, ICauldron _cauldron, IQuoter _quoter)
        ContangoYieldQuoter(_positionNFT, _contangoYield, _cauldron, _quoter)
    {}

    function modifyCostForLongPosition(
        DataTypes.Balances memory balances,
        Instrument memory instrument,
        YieldInstrument memory yieldInstrument,
        int256 quantity,
        int256 collateral
    ) external returns (ModifyCostResult memory) {
        return _modifyCostForLongPosition(balances, instrument, yieldInstrument, quantity, collateral, 0);
    }

    function deliveryCostForPosition(
        DataTypes.Balances memory balances,
        YieldInstrument memory yieldInstrument,
        Position memory position
    ) external returns (uint256) {
        return _deliveryCostForPosition(balances, yieldInstrument, position);
    }
}
