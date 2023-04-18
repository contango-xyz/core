//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./WithYieldFixtures.sol";
import {IOraclePoolStub} from "../../../stub/IOraclePoolStub.sol";

contract YieldLowLiquidityETHUSDCTest is
    WithYieldFixtures(constants.yETHUSDC2306, constants.FYETH2306, constants.FYUSDC2306)
{
    using SignedMath for int256;
    using SafeCast for int256;
    using YieldUtils for *;
    using YieldQuoterUtils for *;
    using TestUtils for *;

    uint256 baseMaxFYTokenOut = 250e18;
    uint256 quoteMaxFYTokenOut = 250_000e6;
    uint256 quoteMaxBaseIn = 226_250e6; // 250000 * .905

    function setUp() public override {
        super.setUp();

        stubPrice({
            _base: WETH9,
            _quote: USDC,
            baseUsdPrice: 700e6,
            quoteUsdPrice: 1e6,
            spread: 1e6,
            uniswapFee: uniswapFee
        });

        vm.etch(address(instrument.basePool), address(new IPoolStub(instrument.basePool)).code);
        vm.etch(address(instrument.quotePool), address(new IPoolStub(instrument.quotePool)).code);

        IPoolStub(address(instrument.basePool)).setBidAsk(0.945e18, 0.955e18);
        IPoolStub(address(instrument.quotePool)).setBidAsk(0.895e6, 0.905e6);

        DataTypes.Debt memory debt = cauldron.debt({baseId: constants.USDC_ID, ilkId: constants.FYETH2306});

        uint96 maxDebt = uint96(debt.sum / 1e6) + 10_000; // Set max debt to 10.000 USDC over the current debt, so the available debt is always 10k

        vm.prank(yieldTimelock);
        ICauldronExt(address(cauldron)).setDebtLimits({
            baseId: constants.USDC_ID,
            ilkId: constants.FYETH2306,
            max: maxDebt,
            min: 100, // Set min debt to 100 USDC
            dec: 6
        });

        symbol = Symbol.wrap("yETHUSDC2306-2");
        vm.prank(contangoTimelock);
        instrument = contangoYield.createYieldInstrumentV2(symbol, constants.FYETH2306, constants.FYUSDC2306, feeModel);

        vm.startPrank(yieldTimelock);
        compositeOracle.setSource(
            constants.FYETH2306,
            constants.ETH_ID,
            new IOraclePoolStub(IPoolStub(address(instrument.basePool)), constants.FYETH2306)
        );
        vm.stopPrank();

        // High liquidity by default, tests will override whatever is necessary
        _setPoolStubLiquidity({pool: instrument.basePool, borrowing: 1_000 ether, lending: baseMaxFYTokenOut});
        _setPoolStubLiquidity({pool: instrument.quotePool, borrowing: 1_000_000e6, lending: quoteMaxFYTokenOut});
    }

    // Can open a position with low quote (borrowing) liquidity above min debt (req collateral will grow to compensate)
    function testCreate1() public {
        // Given
        _setPoolStubLiquidity({pool: instrument.quotePool, borrowing: 100e6, lending: baseMaxFYTokenOut});
        uint256 quantity = 2 ether;

        ModifyCostResult memory result = contangoQuoter.openingCostForPositionWithCollateral(
            OpeningCostParams(symbol, quantity, collateralSlippage, uniswapFee), 0
        );

        // Flag is false as the req collateral grew to accommodate the low liq
        assertEqDecimal(
            result.baseLendingLiquidity, baseMaxFYTokenOut.liquidityHaircut(), baseDecimals, "baseLendingLiquidity"
        );
        assertEqDecimal(result.quoteLendingLiquidity, 0, quoteDecimals, "quoteLendingLiquidity");
        assertEqDecimal(result.cost, -1349.909317e6, quoteDecimals, "cost");
        // Collateral is almost the cost, collateral grew to accommodate the low liq
        assertEqDecimal(result.collateralUsed, 1245.153912e6, quoteDecimals, "collateralUsed");

        PositionId positionId = _createPosition(quantity, result);

        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        // Enough debt to consume the available borrowing liquidity
        assertApproxEqAbsDecimal(
            balances.art, 104.755411e6, Yield.BORROWING_BUFFER + leverageBuffer, quoteDecimals, "art"
        );

        // Pool is almost empty
        assertApproxEqAbsDecimal(
            instrument.quotePool.maxBaseOut(), 6.243907e6, Yield.BORROWING_BUFFER, quoteDecimals, "pool liq"
        );

        _closePosition(positionId);
    }

    // Can't open a position with low quote (borrowing) liquidity below min debt
    function testCreate2() public {
        // Given
        // 100 * 0.895 = 89.5
        _setPoolStubLiquidity({pool: instrument.quotePool, borrowing: 89.49e6, lending: quoteMaxFYTokenOut});
        uint256 quantity = 2 ether;

        vm.expectRevert(IContangoQuoter.InsufficientLiquidity.selector);
        ModifyCostResult memory result = contangoQuoter.openingCostForPositionWithCollateral(
            OpeningCostParams(symbol, quantity, collateralSlippage, uniswapFee), 0
        );

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
            result.baseLendingLiquidity,
            uniswapFee
        );
    }

    // Can open a position with low base (lending) liquidity (will mint 1:1)
    function testCreate3() public {
        // Given
        baseMaxFYTokenOut = 1e18;
        _setPoolStubLiquidity({pool: instrument.basePool, borrowing: 100 ether, lending: baseMaxFYTokenOut});
        uint256 quantity = 2 ether;

        ModifyCostResult memory result = contangoQuoter.openingCostForPositionWithCollateral(
            OpeningCostParams(symbol, quantity, collateralSlippage, uniswapFee), 0
        );

        assertEqDecimal(
            result.baseLendingLiquidity, baseMaxFYTokenOut.liquidityHaircut(), baseDecimals, "baseLendingLiquidity"
        );
        assertEqDecimal(result.quoteLendingLiquidity, 0, quoteDecimals, "quoteLendingLiquidity");
        assertEqDecimal(result.cost, -1490.11441e6, quoteDecimals, "cost");
        assertEqDecimal(result.collateralUsed, 365.522407e6, quoteDecimals, "collateralUsed");

        PositionId positionId = _createPosition(quantity, result);

        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertApproxEqAbsDecimal(
            balances.art, 1124.592008e6, Yield.BORROWING_BUFFER + leverageBuffer, quoteDecimals, "art"
        );

        // Pool is almost empty
        assertEq(
            instrument.basePool.maxFYTokenOut(),
            baseMaxFYTokenOut - baseMaxFYTokenOut.liquidityHaircut(),
            "base pool liquidity"
        );

        _closePosition(positionId);
    }

    // Can open a position with no base (lending) liquidity (will mint 1:1)
    function testCreate4() public {
        // Given
        baseMaxFYTokenOut = 0;
        _setPoolStubLiquidity({pool: instrument.basePool, borrowing: 100 ether, lending: baseMaxFYTokenOut});
        uint256 quantity = 2 ether;

        ModifyCostResult memory result = contangoQuoter.openingCostForPositionWithCollateral(
            OpeningCostParams(symbol, quantity, collateralSlippage, uniswapFee), 0
        );

        assertEqDecimal(
            result.baseLendingLiquidity, baseMaxFYTokenOut.liquidityHaircut(), baseDecimals, "baseLendingLiquidity"
        );
        assertEqDecimal(result.quoteLendingLiquidity, 0, quoteDecimals, "quoteLendingLiquidity");
        assertEqDecimal(result.cost, -1520.078644e6, quoteDecimals, "cost");
        assertEqDecimal(result.collateralUsed, 395.520125e6, quoteDecimals, "collateralUsed");

        PositionId positionId = _createPosition(quantity, result);

        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertApproxEqAbsDecimal(
            balances.art, 1124.558525e6, Yield.BORROWING_BUFFER + leverageBuffer, quoteDecimals, "art"
        );

        // Pool is empty
        assertEq(instrument.basePool.maxFYTokenOut(), 0);

        _closePosition(positionId);
    }

    // Can open a position when global debt levels are close to the debt ceiling, debt to take is above min debt (req collateral will grow to compensate)
    function testCreate5() public {
        // Given
        uint256 quantity = 200 ether;

        ModifyCostResult memory result = contangoQuoter.openingCostForPositionWithCollateral(
            OpeningCostParams(symbol, quantity, collateralSlippage, uniswapFee), 0
        );

        // Flag is false as the req collateral grew to accommodate the low liq
        assertEqDecimal(
            result.baseLendingLiquidity, baseMaxFYTokenOut.liquidityHaircut(), baseDecimals, "baseLendingLiquidity"
        );
        assertEqDecimal(result.quoteLendingLiquidity, 0, quoteDecimals, "quoteLendingLiquidity");
        assertEqDecimal(result.cost, -134926.331117e6, quoteDecimals, "cost");
        // Collateral is close to the cost as we could only borrow up to 10k
        // 134926.331117 - 125066.034764 = 9860.296353
        assertEqDecimal(result.collateralUsed, 125066.034764e6, quoteDecimals, "collateralUsed");

        _closePosition(_createPosition(quantity, result));
    }

    // Can't open a position when global debt levels are close to the debt ceiling, debt to take is below min debt
    function testCreate6() public {
        _openPosition({quantity: 21 ether, leverage: 0});
        DataTypes.Debt memory debt = cauldron.debt(constants.USDC_ID, constants.FYETH2306);
        assertApproxEqAbsDecimal(debt.sum, 26806.292018e6, Yield.BORROWING_BUFFER, quoteDecimals, "total debt");

        uint256 quantity = 20 ether;
        vm.expectRevert(IContangoQuoter.InsufficientLiquidity.selector);
        ModifyCostResult memory result = contangoQuoter.openingCostForPositionWithCollateral(
            OpeningCostParams(symbol, quantity, collateralSlippage, uniswapFee), 0
        );

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
            result.baseLendingLiquidity,
            uniswapFee
        );
    }

    // Can add more collateral (burn debt) than the available quote (lending) liquidity (will mint 1:1)
    function testCollateralManagement1() public {
        (PositionId positionId,) = _openPosition({quantity: 2 ether, leverage: 1.835293426713062884e18});
        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertApproxEqAbsDecimal(
            balances.art, 602.134079e6, Yield.BORROWING_BUFFER + leverageBuffer, quoteDecimals, "art"
        );

        _setPoolStubLiquidity({pool: instrument.quotePool, borrowing: 100_000e6, lending: 100e6});
        quoteMaxBaseIn = 90.5e6; // 100 * .905

        int256 collateral = 200e6;
        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: 0,
            collateralSlippage: collateralSlippage,
            uniswapFee: uniswapFee
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPositionWithCollateral(modifyParams, collateral);

        assertEqDecimal(
            result.quoteLendingLiquidity, quoteMaxBaseIn.liquidityHaircut(), quoteDecimals, "quoteLendingLiquidity"
        );
        assertEqDecimal(result.baseLendingLiquidity, 0, baseDecimals, "baseLendingLiquidity");

        dealAndApprove(address(USDC), trader, collateral.abs(), address(contango));

        vm.prank(trader);
        contango.modifyCollateral(positionId, collateral, result.debtDelta.abs(), trader, result.quoteLendingLiquidity);

        balances = cauldron.balances(positionId.toVaultId());
        assertApproxEqAbsDecimal(
            balances.art, 393.109083e6, Yield.BORROWING_BUFFER + leverageBuffer, quoteDecimals, "art"
        );

        _closePosition(positionId);
    }

    // Can't withdraw more collateral (take debt) than the available quote (borrowing) liquidity
    function testCollateralManagement2() public {
        (PositionId positionId,) = _openPosition({quantity: 2 ether, leverage: 1.835293426713062884e18});
        _setPoolStubLiquidity({pool: instrument.quotePool, borrowing: 100e6, lending: quoteMaxFYTokenOut});

        int256 collateral = -100.01e6;
        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: 0,
            collateralSlippage: collateralSlippage,
            uniswapFee: uniswapFee
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPositionWithCollateral(modifyParams, collateral);

        // The quoter caps the available liquidity to the max base out
        assertEqDecimal(result.collateralUsed, -94.905092e6, quoteDecimals, "collateralUsed");

        vm.prank(trader);
        contango.modifyCollateral(positionId, result.collateralUsed, result.debtDelta.abs(), trader, 0);
    }

    // Can't withdraw more collateral (take debt) than the available quote (borrowing) liquidity - leverage driven
    function testCollateralManagement3() public {
        (PositionId positionId,) = _openPosition({quantity: 2 ether, leverage: 1.835293426713062884e18});
        _setPoolStubLiquidity({pool: instrument.quotePool, borrowing: 100e6, lending: quoteMaxFYTokenOut});

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: 0,
            collateralSlippage: collateralSlippage,
            uniswapFee: uniswapFee
        });
        ModifyCostResult memory result =
            contangoQuoter.modifyCostForPositionWithLeverage(modifyParams, 2.151828731647590704e18);

        // The quoter caps the available liquidity to the max base out
        assertEqDecimal(result.collateralUsed, -94.905092e6, quoteDecimals, "collateralUsed");

        vm.prank(trader);
        contango.modifyCollateral(positionId, result.collateralUsed, result.debtDelta.abs(), trader, 0);
    }

    // Can't withdraw more collateral (take debt) than the available quote (borrowing) liquidity - zero liquidity
    function testCollateralManagement4() public {
        (PositionId positionId,) = _openPosition({quantity: 2 ether, leverage: 1.835293426713062884e18});
        _setPoolStubLiquidity({pool: instrument.quotePool, borrowing: 0, lending: quoteMaxFYTokenOut});

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: 0,
            collateralSlippage: collateralSlippage,
            uniswapFee: uniswapFee
        });
        ModifyCostResult memory result =
            contangoQuoter.modifyCostForPositionWithLeverage(modifyParams, 2.151828731647590704e18);

        // The quoter caps the available liquidity to the max base out
        assertEqDecimal(result.collateralUsed, 0, quoteDecimals, "collateralUsed");

        vm.prank(trader);
        contango.modifyCollateral(positionId, result.collateralUsed, result.debtDelta.abs(), trader, 0);
    }

    // Can increase a position with low quote (borrowing) liquidity (req collateral will grow to compensate)
    function testIncreasePosition1() public {
        uint256 quantity = 2 ether;
        (PositionId positionId,) = _openPosition({quantity: quantity, leverage: 1.835293426713062884e18});
        _setPoolStubLiquidity({pool: instrument.quotePool, borrowing: 100e6, lending: quoteMaxFYTokenOut});

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: 2 ether,
            collateralSlippage: collateralSlippage,
            uniswapFee: uniswapFee
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPositionWithCollateral(modifyParams, 0);

        assertEqDecimal(
            result.baseLendingLiquidity,
            (baseMaxFYTokenOut - quantity).liquidityHaircut(),
            baseDecimals,
            "baseLendingLiquidity"
        );
        assertEq(result.quoteLendingLiquidity, quoteMaxBaseIn.liquidityHaircut(), "lendingLiquidity");
        assertEqDecimal(result.cost, -1349.909317e6, quoteDecimals, "cost");
        // Collateral is almost the cost, collateral grew to accommodate the low liq
        assertEqDecimal(result.collateralUsed, 1245.153912e6, quoteDecimals, "collateralUsed");

        _modifyPosition(positionId, 2 ether, result);

        // Pool is almost empty
        assertApproxEqAbsDecimal(
            instrument.quotePool.maxBaseOut(), 6.243907e6, Yield.BORROWING_BUFFER, quoteDecimals, "quote pool balance"
        );

        _closePosition(positionId);
    }

    // Can increase a position with low quote (borrowing) liquidity below min debt (req collateral will grow to compensate)
    function testIncreasePosition2() public {
        uint256 quantity = 2 ether;
        (PositionId positionId,) = _openPosition({quantity: quantity, leverage: 1.835293426713062884e18});
        // 100 * 0.895 = 89.5
        _setPoolStubLiquidity({pool: instrument.quotePool, borrowing: 89.49e6, lending: quoteMaxFYTokenOut});

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: 2 ether,
            collateralSlippage: collateralSlippage,
            uniswapFee: uniswapFee
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPositionWithCollateral(modifyParams, 0);

        assertEqDecimal(
            result.baseLendingLiquidity,
            (baseMaxFYTokenOut - quantity).liquidityHaircut(),
            baseDecimals,
            "baseLendingLiquidity"
        );
        assertEq(result.quoteLendingLiquidity, quoteMaxBaseIn.liquidityHaircut(), "lendingLiquidity");
        assertEqDecimal(result.cost, -1348.73678e6, quoteDecimals, "cost");
        // Collateral is almost the cost, collateral grew to accommodate the low liq
        assertEqDecimal(result.collateralUsed, 1255.148396e6, quoteDecimals, "collateralUsed");

        _modifyPosition(positionId, 2 ether, result);

        // Pool is almost empty
        assertApproxEqAbsDecimal(
            instrument.quotePool.maxBaseOut(), 5.728391e6, Yield.BORROWING_BUFFER, quoteDecimals, "quote pool balance"
        );

        _closePosition(positionId);
    }

    // Can increase a position with low base (lending) liquidity (will mint 1:1)
    function testIncreasePosition3() public {
        uint256 quantity = 2 ether;
        (PositionId positionId,) = _openPosition({quantity: quantity, leverage: 1.835293426713062884e18});
        baseMaxFYTokenOut = 1e18;
        _setPoolStubLiquidity({pool: instrument.basePool, borrowing: 100 ether, lending: baseMaxFYTokenOut});

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: 4 ether,
            collateralSlippage: collateralSlippage,
            uniswapFee: uniswapFee
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPositionWithCollateral(modifyParams, 0);

        assertEqDecimal(
            result.baseLendingLiquidity, baseMaxFYTokenOut.liquidityHaircut(), baseDecimals, "baseLendingLiquidity"
        );
        assertEqDecimal(result.quoteLendingLiquidity, 215455.185004e6, quoteDecimals, "quoteLendingLiquidity");

        _modifyPosition(positionId, 4 ether, result);

        // Pool is almost empty
        assertEq(
            instrument.basePool.maxFYTokenOut(),
            baseMaxFYTokenOut - baseMaxFYTokenOut.liquidityHaircut(),
            "base pool balance"
        );

        _closePosition(positionId);
    }

    // Can increase a position with no base (lending) liquidity (will mint 1:1)
    function testIncreasePosition4() public {
        uint256 quantity = 2 ether;
        (PositionId positionId,) = _openPosition({quantity: quantity, leverage: 1.835293426713062884e18});
        baseMaxFYTokenOut = 0;
        _setPoolStubLiquidity({pool: instrument.basePool, borrowing: 100 ether, lending: baseMaxFYTokenOut});

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: 4 ether,
            collateralSlippage: collateralSlippage,
            uniswapFee: uniswapFee
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPositionWithCollateral(modifyParams, 0);

        assertEqDecimal(
            result.baseLendingLiquidity, baseMaxFYTokenOut.liquidityHaircut(), baseDecimals, "baseLendingLiquidity"
        );
        assertEqDecimal(result.quoteLendingLiquidity, 215455.185004e6, quoteDecimals, "quoteLendingLiquidity");

        _modifyPosition(positionId, 4 ether, result);

        // Pool is empty
        assertEq(instrument.basePool.maxFYTokenOut(), 0);

        _closePosition(positionId);
    }

    // Can increase a position AND deposit extra collateral with low base (lending) liquidity (will mint 1:1)
    function testIncreasePosition7() public {
        (PositionId positionId,) = _openPosition({quantity: 2 ether, leverage: 1.835293426713062884e18});
        baseMaxFYTokenOut = 1e18;
        _setPoolStubLiquidity({pool: instrument.basePool, borrowing: 100 ether, lending: baseMaxFYTokenOut});

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: 3 ether,
            collateralSlippage: collateralSlippage,
            uniswapFee: uniswapFee
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPositionWithCollateral(modifyParams, 2500e6);

        assertEqDecimal(
            result.baseLendingLiquidity, baseMaxFYTokenOut.liquidityHaircut(), baseDecimals, "baseLendingLiquidity"
        );
        assertApproxEqAbsDecimal(
            result.quoteLendingLiquidity, 215455.184777e6, leverageBuffer, quoteDecimals, "quoteLendingLiquidity"
        );
        assertTrue(result.needsBatchedCall, "needsBatchedCall");

        _modifyPosition(positionId, 3 ether, result);

        // Pool is almost empty
        assertEq(
            instrument.basePool.maxFYTokenOut(),
            baseMaxFYTokenOut - baseMaxFYTokenOut.liquidityHaircut(),
            "base pool balance"
        );

        _closePosition(positionId);
    }

    // Can increase a position AND deposit extra collateral with no base (lending) liquidity (will mint 1:1)
    function testIncreasePosition8() public {
        (PositionId positionId,) = _openPosition({quantity: 2 ether, leverage: 1.835293426713062884e18});
        baseMaxFYTokenOut = 0;
        _setPoolStubLiquidity({pool: instrument.basePool, borrowing: 100 ether, lending: baseMaxFYTokenOut});

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: 3 ether,
            collateralSlippage: collateralSlippage,
            uniswapFee: uniswapFee
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPositionWithCollateral(modifyParams, 2500e6);

        assertEqDecimal(
            result.baseLendingLiquidity, baseMaxFYTokenOut.liquidityHaircut(), baseDecimals, "baseLendingLiquidity"
        );
        assertApproxEqAbsDecimal(
            result.quoteLendingLiquidity, 215455.184777e6, leverageBuffer, quoteDecimals, "quoteLendingLiquidity"
        );
        assertTrue(result.needsBatchedCall, "needsBatchedCall");

        _modifyPosition(positionId, 3 ether, result);

        // Pool is empty
        assertEq(instrument.basePool.maxFYTokenOut(), 0);

        _closePosition(positionId);
    }

    // Can increase a position AND deposit extra collateral
    // Low base (lending) liquidity (will mint 1:1)
    // Low quote (lending) liquidity (will mint 1:1)
    function testIncreasePosition9() public {
        (PositionId positionId,) = _openPosition({quantity: 2 ether, leverage: 1.835293426713062884e18});
        baseMaxFYTokenOut = 1e18;
        _setPoolStubLiquidity({pool: instrument.basePool, borrowing: 100 ether, lending: baseMaxFYTokenOut});
        quoteMaxFYTokenOut = 100e6;
        _setPoolStubLiquidity({pool: instrument.quotePool, borrowing: 1_000_000e6, lending: quoteMaxFYTokenOut});
        quoteMaxBaseIn = 90.5e6; // 100 * .905

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: 3 ether,
            collateralSlippage: collateralSlippage,
            uniswapFee: uniswapFee
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPositionWithCollateral(modifyParams, 2500e6);

        assertEqDecimal(
            result.baseLendingLiquidity, baseMaxFYTokenOut.liquidityHaircut(), baseDecimals, "baseLendingLiquidity"
        );
        assertEqDecimal(
            result.quoteLendingLiquidity, quoteMaxBaseIn.liquidityHaircut(), quoteDecimals, "quoteLendingLiquidity"
        );
        assertTrue(result.needsBatchedCall, "needsBatchedCall");

        _modifyPosition(positionId, 3 ether, result);

        // Pool is almost empty
        assertEq(
            instrument.basePool.maxFYTokenOut(),
            baseMaxFYTokenOut - baseMaxFYTokenOut.liquidityHaircut(),
            "base pool balance"
        );

        _closePosition(positionId);
    }

    // Can increase a position AND deposit extra collateral
    // No base (lending) liquidity (will mint 1:1)
    // No quote (lending) liquidity (will mint 1:1)
    function testIncreasePosition10() public {
        (PositionId positionId,) = _openPosition({quantity: 2 ether, leverage: 1.835293426713062884e18});
        baseMaxFYTokenOut = 0;
        _setPoolStubLiquidity({pool: instrument.basePool, borrowing: 100 ether, lending: baseMaxFYTokenOut});
        quoteMaxFYTokenOut = 0;
        _setPoolStubLiquidity({pool: instrument.quotePool, borrowing: 1_000_000e6, lending: quoteMaxFYTokenOut});
        quoteMaxBaseIn = 0;

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: 3 ether,
            collateralSlippage: collateralSlippage,
            uniswapFee: uniswapFee
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPositionWithCollateral(modifyParams, 2500e6);

        assertEqDecimal(
            result.baseLendingLiquidity, baseMaxFYTokenOut.liquidityHaircut(), baseDecimals, "baseLendingLiquidity"
        );
        assertEqDecimal(
            result.quoteLendingLiquidity, quoteMaxBaseIn.liquidityHaircut(), quoteDecimals, "quoteLendingLiquidity"
        );
        assertTrue(result.needsBatchedCall, "needsBatchedCall");

        _modifyPosition(positionId, 3 ether, result);

        // Pool is empty
        assertEq(instrument.basePool.maxFYTokenOut(), 0);

        _closePosition(positionId);
    }

    // Can increase a position when global debt levels are close to the debt ceiling (req collateral will grow to compensate)
    function testIncreasePosition5() public {
        (PositionId positionId,) = _openPosition({quantity: 19 ether, leverage: 0});

        DataTypes.Debt memory debt = cauldron.debt(constants.USDC_ID, constants.FYETH2306);
        assertApproxEqAbs(debt.max, 26812, Yield.BORROWING_BUFFER * 2, "max debt");
        assertApproxEqAbsDecimal(debt.sum, 26807.788007e6, Yield.BORROWING_BUFFER * 2, quoteDecimals, "total debt");

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: 2 ether,
            collateralSlippage: collateralSlippage,
            uniswapFee: uniswapFee
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPositionWithCollateral(modifyParams, 0);

        assertEqDecimal(
            result.baseLendingLiquidity,
            (baseMaxFYTokenOut - 19 ether).liquidityHaircut(),
            baseDecimals,
            "baseLendingLiquidity"
        );
        assertEqDecimal(result.quoteLendingLiquidity, 223531.288757e6, quoteDecimals, "lendingLiquidity");
        assertApproxEqAbsDecimal(result.cost, -1339.195622e6, Yield.BORROWING_BUFFER * 2, quoteDecimals, "cost");
        // Collateral is almost the cost, as collateral grew to accommodate the low liq
        assertApproxEqAbsDecimal(
            result.collateralUsed, 1336.475407e6, Yield.BORROWING_BUFFER * 2, quoteDecimals, "collateralUsed"
        );

        _modifyPosition(positionId, 2 ether, result);

        _closePosition(positionId);
    }

    // Can decrease a position with low quote (lending) liquidity (will mint 1:1)
    function testDecreasePosition1() public {
        uint256 quantity = 2 ether;
        (PositionId positionId,) = _openPosition({quantity: quantity, leverage: 1.835293426713062884e18});
        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertApproxEqAbsDecimal(
            balances.art, 602.134079e6, Yield.BORROWING_BUFFER + leverageBuffer, quoteDecimals, "art"
        );
        quoteMaxFYTokenOut = 100e6;
        _setPoolStubLiquidity({pool: instrument.quotePool, borrowing: 100_000e6, lending: quoteMaxFYTokenOut});
        quoteMaxBaseIn = 90.5e6; // 100 * .905

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: -0.25 ether,
            collateralSlippage: collateralSlippage,
            uniswapFee: uniswapFee
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPositionWithCollateral(modifyParams, 0);

        assertEqDecimal(
            result.quoteLendingLiquidity, quoteMaxBaseIn.liquidityHaircut(), quoteDecimals, "quoteLendingLiquidity"
        );
        assertEqDecimal(result.baseLendingLiquidity, 0, baseDecimals, "baseLendingLiquidity");
        assertEqDecimal(result.cost, 174.16375e6, quoteDecimals, "cost");

        _modifyPosition(positionId, -0.25 ether, result);

        assertEqDecimal(
            cauldron.balances(positionId.toVaultId()).art, balances.art - result.cost.abs(), quoteDecimals, "art"
        );

        // Pool is almost empty
        assertEq(
            instrument.quotePool.maxFYTokenOut(),
            quoteMaxFYTokenOut - quoteMaxFYTokenOut.liquidityHaircut(),
            "quote pool liquidity"
        );

        _closePosition(positionId);
    }

    // Can decrease a position with no quote (lending) liquidity (will mint 1:1)
    function testDecreasePosition2() public {
        (PositionId positionId,) = _openPosition({quantity: 2 ether, leverage: 1.835293426713062884e18});
        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertApproxEqAbsDecimal(
            balances.art, 602.134079e6, Yield.BORROWING_BUFFER + leverageBuffer, quoteDecimals, "art"
        );
        _setPoolStubLiquidity({pool: instrument.quotePool, borrowing: 100_000e6, lending: 0});

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: -0.25 ether, // .25 * .945 = 0.23625
            collateralSlippage: collateralSlippage,
            uniswapFee: uniswapFee
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPositionWithCollateral(modifyParams, 0);

        assertEqDecimal(result.quoteLendingLiquidity, 0, quoteDecimals, "quoteLendingLiquidity");
        assertEqDecimal(result.baseLendingLiquidity, 0, baseDecimals, "baseLendingLiquidity");
        // 0.23625*699 = 165.138750
        assertEqDecimal(result.cost, 165.13875e6, quoteDecimals, "cost");

        _modifyPosition(positionId, -0.25 ether, result);

        assertEqDecimal(
            cauldron.balances(positionId.toVaultId()).art, balances.art - result.cost.abs(), quoteDecimals, "art"
        );

        // Pool is empty
        assertEq(instrument.quotePool.maxFYTokenOut(), 0);

        _closePosition(positionId);
    }

    // Can't decrease a position with low base (borrowing) liquidity
    function testDecreasePosition3() public {
        (PositionId positionId,) = _openPosition({quantity: 2 ether, leverage: 1.835293426713062884e18});
        // 0.25 * 0.945 = 0.23625
        _setPoolStubLiquidity({pool: instrument.basePool, borrowing: 0.236 ether, lending: 100e18});

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: -0.25 ether,
            collateralSlippage: collateralSlippage,
            uniswapFee: uniswapFee
        });
        vm.expectRevert(IContangoQuoter.InsufficientLiquidity.selector);
        ModifyCostResult memory result = contangoQuoter.modifyCostForPositionWithCollateral(modifyParams, 0);

        vm.expectRevert("Not enough liquidity");
        vm.prank(trader);
        contango.modifyPosition(
            positionId,
            modifyParams.quantity,
            result.cost.abs(),
            result.collateralUsed,
            trader,
            result.quoteLendingLiquidity,
            uniswapFee
        );
    }

    // Can decrease a position when debt must to be burnt and the quote (lending) is low (will mint 1:1)
    function testDecreasePosition4() public {
        (PositionId positionId,) = _openPosition({quantity: 2 ether, leverage: 0});
        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertApproxEqAbsDecimal(
            balances.art, 1124.629016e6, Yield.BORROWING_BUFFER + leverageBuffer, quoteDecimals, "art"
        );

        assertEqDecimal(USDC.balanceOf(trader), 0, quoteDecimals, "trader balance before");

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: -0.5 ether,
            collateralSlippage: collateralSlippage,
            uniswapFee: uniswapFee
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPositionWithCollateral(modifyParams, 0);

        assertEqDecimal(result.quoteLendingLiquidity, 215904.399796e6, quoteDecimals, "quoteLendingLiquidity");
        assertEqDecimal(result.baseLendingLiquidity, 0, baseDecimals, "baseLendingLiquidity");

        _setPoolStubLiquidity({pool: instrument.quotePool, borrowing: 100_000e6, lending: 100e6});
        quoteMaxBaseIn = 90.5e6; // 100 * .905
        result = contangoQuoter.modifyCostForPositionWithCollateral(modifyParams, 0);

        assertEqDecimal(
            result.quoteLendingLiquidity, quoteMaxBaseIn.liquidityHaircut(), quoteDecimals, "quoteLendingLiquidity"
        );
        assertEqDecimal(result.baseLendingLiquidity, 0, baseDecimals, "baseLendingLiquidity");

        _modifyPosition(positionId, -0.5 ether, result);

        assertEqDecimal(USDC.balanceOf(trader), 0, quoteDecimals, "trader balance after");
        assertEqDecimal(USDC.balanceOf(address(contango)), 0, quoteDecimals, "contango balance after");

        assertEqDecimal(
            cauldron.balances(positionId.toVaultId()).art, balances.art - result.cost.abs(), quoteDecimals, "art"
        );

        // Pool is almost empty
        assertEq(instrument.quotePool.maxFYTokenOut(), 5e6);

        _closePosition(positionId);
    }

    // Can decrease a position with excessQuote when the quote (lending) liquidity is low (will mint 1:1)
    function testDecreasePosition5() public {
        (PositionId positionId,) = _openPosition({quantity: 2 ether, leverage: 1.835293426713062884e18});
        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertApproxEqAbsDecimal(
            balances.art, 602.134079e6, Yield.BORROWING_BUFFER + leverageBuffer, quoteDecimals, "art"
        );
        stubPrice({
            _base: WETH9,
            _quote: USDC,
            baseUsdPrice: 1400e6,
            quoteUsdPrice: 1e6,
            spread: 1e6,
            uniswapFee: uniswapFee
        });

        assertEqDecimal(USDC.balanceOf(trader), 0, quoteDecimals, "trader balance before");

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: -1 ether,
            collateralSlippage: collateralSlippage,
            uniswapFee: uniswapFee
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPositionWithCollateral(modifyParams, 0);

        assertApproxEqAbsDecimal(
            result.quoteLendingLiquidity, 215455.184777e6, leverageBuffer, quoteDecimals, "quoteLendingLiquidity"
        );
        assertEqDecimal(result.baseLendingLiquidity, 0, baseDecimals, "baseLendingLiquidity");
        assertApproxEqAbsDecimal(
            result.maxCollateral, -868.491282e6, Yield.BORROWING_BUFFER + leverageBuffer, quoteDecimals, "maxCollateral"
        );
        assertApproxEqAbsDecimal(
            result.collateralUsed,
            -868.491282e6,
            Yield.BORROWING_BUFFER + leverageBuffer,
            quoteDecimals,
            "collateralUsed"
        );

        _setPoolStubLiquidity({pool: instrument.quotePool, borrowing: 100_000e6, lending: 100e6});
        quoteMaxBaseIn = 90.5e6; // 100 * .905
        result = contangoQuoter.modifyCostForPositionWithCollateral(modifyParams, 0);

        assertApproxEqAbsDecimal(
            result.quoteLendingLiquidity,
            quoteMaxBaseIn.liquidityHaircut(),
            leverageBuffer,
            quoteDecimals,
            "quoteLendingLiquidity"
        );
        assertEqDecimal(result.baseLendingLiquidity, 0, baseDecimals, "baseLendingLiquidity");
        assertApproxEqAbsDecimal(
            result.maxCollateral, -829.774862e6, Yield.BORROWING_BUFFER + leverageBuffer, quoteDecimals, "maxCollateral"
        );
        // Collateral to get is lower as I didn't recovered too much interest from lending on the pool
        assertApproxEqAbsDecimal(
            result.collateralUsed,
            -829.774862e6,
            Yield.BORROWING_BUFFER + leverageBuffer,
            quoteDecimals,
            "collateralUsed"
        );

        _modifyPosition(positionId, -1 ether, result);

        assertEqDecimal(USDC.balanceOf(trader), result.collateralUsed.abs(), quoteDecimals, "trader balance after");
        assertEqDecimal(USDC.balanceOf(address(contango)), 0, quoteDecimals, "contango balance after");

        // Pool is almost empty
        assertEq(instrument.quotePool.maxFYTokenOut(), 5e6);

        _closePosition(positionId);
    }

    // Can close a position with low quote (lending) liquidity (will mint 1:1)
    function testClosePosition1() public {
        (PositionId positionId,) = _openPosition({quantity: 2 ether, leverage: 1.835293426713062884e18});
        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertApproxEqAbsDecimal(
            balances.art, 602.134079e6, Yield.BORROWING_BUFFER + leverageBuffer, quoteDecimals, "art"
        );
        quoteMaxFYTokenOut = 100e6;
        _setPoolStubLiquidity({pool: instrument.quotePool, borrowing: 100_000e6, lending: quoteMaxFYTokenOut});

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: -2 ether,
            collateralSlippage: collateralSlippage,
            uniswapFee: uniswapFee
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPositionWithCollateral(modifyParams, 0);

        assertEqDecimal(
            result.quoteLendingLiquidity, quoteMaxFYTokenOut.liquidityHaircut(), quoteDecimals, "quoteLendingLiquidity"
        );
        assertEqDecimal(result.baseLendingLiquidity, 0, baseDecimals, "baseLendingLiquidity");
        assertEqDecimal(result.cost, 1330.135e6, quoteDecimals, "cost");

        _closePosition(positionId);

        // Pool is almost empty
        assertEq(instrument.quotePool.maxFYTokenOut(), quoteMaxFYTokenOut - quoteMaxFYTokenOut.liquidityHaircut());
    }

    // Can close a position with no quote (lending) liquidity (will mint 1:1)
    function testClosePosition2() public {
        (PositionId positionId,) = _openPosition({quantity: 2 ether, leverage: 1.835293426713062884e18});
        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertApproxEqAbsDecimal(
            balances.art, 602.134079e6, Yield.BORROWING_BUFFER + leverageBuffer, quoteDecimals, "art"
        );
        quoteMaxFYTokenOut = 0;
        _setPoolStubLiquidity({pool: instrument.quotePool, borrowing: 100_000e6, lending: quoteMaxFYTokenOut});

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: -2 ether,
            collateralSlippage: collateralSlippage,
            uniswapFee: uniswapFee
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPositionWithCollateral(modifyParams, 0);

        assertEqDecimal(
            result.quoteLendingLiquidity, quoteMaxFYTokenOut.liquidityHaircut(), quoteDecimals, "quoteLendingLiquidity"
        );
        assertEqDecimal(result.baseLendingLiquidity, 0, baseDecimals, "baseLendingLiquidity");
        assertEqDecimal(result.cost, 1321.11e6, quoteDecimals, "cost");

        _closePosition(positionId);

        // Pool is empty
        assertEq(instrument.quotePool.maxFYTokenOut(), 0);
    }

    // Can't close a position with low base (borrowing) liquidity
    function testClosePosition3() public {
        (PositionId positionId,) = _openPosition({quantity: 2 ether, leverage: 1.835293426713062884e18});
        // 2 * 0.945 = 1.89
        _setPoolStubLiquidity({pool: instrument.basePool, borrowing: 1.889 ether, lending: 100e18});

        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: -2 ether,
            collateralSlippage: collateralSlippage,
            uniswapFee: uniswapFee
        });
        vm.expectRevert(IContangoQuoter.InsufficientLiquidity.selector);
        ModifyCostResult memory result = contangoQuoter.modifyCostForPositionWithCollateral(modifyParams, 0);

        vm.expectRevert("Not enough liquidity");
        vm.prank(trader);
        contango.modifyPosition(
            positionId,
            modifyParams.quantity,
            result.cost.abs(),
            result.collateralUsed,
            trader,
            result.quoteLendingLiquidity,
            uniswapFee
        );
    }

    // Can close a position with low base (lending) liquidity (will repay 1:1)
    function testClosePosition4() public {
        // Given
        baseMaxFYTokenOut = 1e18;
        _setPoolStubLiquidity({pool: instrument.basePool, borrowing: 1 ether, lending: baseMaxFYTokenOut});
        uint256 quantity = 2 ether;

        ModifyCostResult memory result = contangoQuoter.openingCostForPositionWithCollateral(
            OpeningCostParams(symbol, quantity, collateralSlippage, uniswapFee), 0
        );

        assertEqDecimal(
            result.baseLendingLiquidity, baseMaxFYTokenOut.liquidityHaircut(), baseDecimals, "baseLendingLiquidity"
        );
        assertEqDecimal(result.quoteLendingLiquidity, 0, quoteDecimals, "quoteLendingLiquidity");
        assertEqDecimal(result.cost, -1490.11441e6, quoteDecimals, "cost");
        assertEqDecimal(result.collateralUsed, 365.522407e6, quoteDecimals, "collateralUsed");

        PositionId positionId = _createPosition(quantity, result);

        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertApproxEqAbsDecimal(
            balances.art, 1124.592008e6, Yield.BORROWING_BUFFER + leverageBuffer, quoteDecimals, "art"
        );

        // Pool is almost empty
        assertEq(
            instrument.basePool.maxFYTokenOut(),
            baseMaxFYTokenOut - baseMaxFYTokenOut.liquidityHaircut(),
            "base pool liquidity"
        );

        _closePosition(positionId);
    }

    // Can close a position with no base (lending) liquidity (will repay 1:1)
    function testClosePosition5() public {
        // Given
        baseMaxFYTokenOut = 0;
        _setPoolStubLiquidity({pool: instrument.basePool, borrowing: 0 ether, lending: baseMaxFYTokenOut});
        uint256 quantity = 2 ether;

        ModifyCostResult memory result = contangoQuoter.openingCostForPositionWithCollateral(
            OpeningCostParams(symbol, quantity, collateralSlippage, uniswapFee), 0
        );

        assertEqDecimal(
            result.baseLendingLiquidity, baseMaxFYTokenOut.liquidityHaircut(), baseDecimals, "baseLendingLiquidity"
        );
        assertEqDecimal(result.quoteLendingLiquidity, 0, quoteDecimals, "quoteLendingLiquidity");
        assertEqDecimal(result.cost, -1520.078644e6, quoteDecimals, "cost");
        assertEqDecimal(result.collateralUsed, 395.520125e6, quoteDecimals, "collateralUsed");

        PositionId positionId = _createPosition(quantity, result);

        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertApproxEqAbsDecimal(
            balances.art, 1124.558525e6, Yield.BORROWING_BUFFER + leverageBuffer, quoteDecimals, "art"
        );

        // Pool is empty
        assertEq(instrument.basePool.maxFYTokenOut(), 0);

        _closePosition(positionId);
    }
}
