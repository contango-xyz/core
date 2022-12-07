//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./WithYieldFixtures.sol";

/// @notice these examples apply to any ETH quoted instrument
contract YieldMainnetWethExamplesUSDCETHTest is
    WithYieldFixtures(constants.yUSDCETH2303, constants.FYUSDC2303, constants.FYETH2303)
{
    using SignedMath for int256;
    using SafeCast for int256;
    using SignedMathLib for int256;
    using YieldUtils for PositionId;
    using TestUtils for *;

    // ==============================================
    // createPosition()
    // ==============================================

    function testCreatePosition() public {
        uint256 quantity = 30000e6;
        uint256 collateral = 1 ether;

        ModifyCostResult memory openingCostResult =
            contangoQuoter.openingCostForPosition(OpeningCostParams(symbol, quantity, collateral, collateralSlippage));

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(contango.wrapETH.selector);
        calls[1] = abi.encodeWithSelector(
            contango.createPosition.selector,
            symbol,
            trader,
            quantity,
            openingCostResult.cost.slippage(),
            openingCostResult.collateralUsed.toUint256(),
            address(contango),
            openingCostResult.baseLendingLiquidity
        );
        // unwrap is not necessary since the full collateral posted will be used
        // adding it wouldn't break the code but would incur in unnecessary gas expenditure

        vm.deal(trader, openingCostResult.collateralUsed.toUint256());
        vm.prank(trader);
        bytes[] memory results = contango.batch{value: openingCostResult.collateralUsed.toUint256()}(calls);
        PositionId positionId = abi.decode(results[1], (PositionId));

        assertEq(contango.position(positionId).openQuantity, quantity);
        assertEq(trader.balance, 0);
        assertEq(WETH.balanceOf(address(contango)), 0);
    }

    function testOpenPositionOnBehalfOfSomeoneElse() public {
        address proxy = address(0x99);

        uint256 quantity = 30000e6;
        uint256 collateral = 1 ether;

        ModifyCostResult memory openingCostResult =
            contangoQuoter.openingCostForPosition(OpeningCostParams(symbol, quantity, collateral, collateralSlippage));

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(contango.wrapETH.selector);
        calls[1] = abi.encodeWithSelector(
            contango.createPosition.selector,
            symbol,
            trader,
            quantity,
            openingCostResult.cost.slippage(),
            openingCostResult.collateralUsed.toUint256(),
            address(contango),
            openingCostResult.baseLendingLiquidity
        );
        // unwrap is not necessary since the full collateral posted will be used
        // adding it wouldn't break the code but would incur in unnecessary gas expenditure

        vm.deal(proxy, openingCostResult.collateralUsed.toUint256());
        vm.prank(proxy);
        bytes[] memory results = contango.batch{value: openingCostResult.collateralUsed.toUint256()}(calls);
        PositionId positionId = abi.decode(results[1], (PositionId));

        assertEq(contango.position(positionId).openQuantity, quantity);
        assertEq(trader.balance, 0);
        assertEq(WETH.balanceOf(address(contango)), 0);
    }

    function testCreateFullCollateralisedPosition() public {
        uint256 quantity = 30000e6;

        OpeningCostParams memory params = OpeningCostParams(symbol, quantity, 0, collateralSlippage);
        ModifyCostResult memory openingCostResult = contangoQuoter.openingCostForPosition(params);
        params.collateral = openingCostResult.maxCollateral.toUint256();
        openingCostResult = contangoQuoter.openingCostForPosition(params);

        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeWithSelector(contango.wrapETH.selector);
        calls[1] = abi.encodeWithSelector(
            contango.createPosition.selector,
            symbol,
            trader,
            quantity,
            openingCostResult.cost.slippage(),
            openingCostResult.maxCollateral,
            address(contango),
            openingCostResult.baseLendingLiquidity
        );
        // unwrap is necessary since we're providing more than the maximum collateral
        // the excess will be given back to the payer (contango because of the wrapping) and therefore we need to collect it
        // if we don't, it will sit in the contango contract and will be up for grabs!
        calls[2] = abi.encodeWithSelector(contango.unwrapWETH.selector, trader);

        vm.deal(trader, openingCostResult.maxCollateral.toUint256() + 0.1 ether);
        vm.prank(trader);
        bytes[] memory results = contango.batch{value: openingCostResult.maxCollateral.toUint256() + 0.1 ether}(calls);
        PositionId positionId = abi.decode(results[1], (PositionId));

        assertEq(contango.position(positionId).openQuantity, quantity);
        assertEq(trader.balance, 0.1 ether);
        assertEq(WETH.balanceOf(address(contango)), 0);
    }

    // ==============================================
    // increasePosition()
    // ==============================================

    function testIncreasePosition() public {
        uint256 initialQuantity = 8000e6;
        (PositionId positionId,) = _openPosition(initialQuantity);

        uint256 quantity = 1000e6;

        ModifyCostResult memory increasingCostResult =
            contangoQuoter.modifyCostForPosition(ModifyCostParams(positionId, int256(quantity), 0, collateralSlippage));

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(contango.wrapETH.selector);
        calls[1] = abi.encodeWithSelector(
            contango.modifyPosition.selector,
            positionId,
            quantity,
            increasingCostResult.cost.slippage(),
            increasingCostResult.collateralUsed,
            address(contango),
            increasingCostResult.baseLendingLiquidity
        );
        // unwrap is not necessary since the full collateral posted will be used
        // adding it wouldn't break the code but would incur in unnecessary gas expenditure

        vm.deal(trader, increasingCostResult.collateralUsed.toUint256());
        vm.prank(trader);
        contango.batch{value: increasingCostResult.collateralUsed.toUint256()}(calls);

        assertEq(contango.position(positionId).openQuantity, initialQuantity + quantity, "openQuantity");
        assertEqDecimal(trader.balance, 0, quoteDecimals, "trader balance");
        assertEqDecimal(WETH.balanceOf(address(contango)), 0, quoteDecimals, "contango balance");
    }

    function testIncreaseAndCollateralisePositionAtMax() public {
        uint256 initialQuantity = 20000e6;
        (PositionId positionId,) = _openPosition(initialQuantity);

        uint256 quantity = 1000e6;
        uint256 collateral = 30 ether;

        ModifyCostResult memory result = contangoQuoter.modifyCostForPosition(
            ModifyCostParams({
                positionId: positionId,
                quantity: int256(quantity),
                collateral: int256(collateral),
                collateralSlippage: collateralSlippage
            })
        );

        assertGt(result.collateralUsed, 0, "collateralUsed");

        uint256 cost = (result.cost + result.financingCost).slippage();
        int256 amountToUseInAddCollateralCall = result.financingCost - result.debtDelta;
        uint256 costToUseInAddCollateralCall = result.debtDelta.abs();

        bytes[] memory calls = new bytes[](4);
        calls[0] = abi.encodeWithSelector(contango.wrapETH.selector);
        calls[1] = abi.encodeWithSelector(
            contango.modifyPosition.selector,
            positionId,
            quantity,
            cost,
            result.collateralUsed,
            address(contango),
            result.baseLendingLiquidity
        );
        calls[2] = abi.encodeWithSelector(
            contango.modifyCollateral.selector,
            positionId,
            amountToUseInAddCollateralCall,
            costToUseInAddCollateralCall,
            address(contango),
            result.quoteLendingLiquidity
        );
        // unwrap is necessary since we're providing more than the maximum collateral
        // the excess will be given back to the payer (contango because of the wrapping) and therefore we need to collect it
        // if we don't, it will sit in the contango contract and will be up for grabs!
        calls[3] = abi.encodeWithSelector(contango.unwrapWETH.selector, trader);

        vm.deal(trader, collateral);
        vm.prank(trader);
        contango.batch{value: collateral}(calls);

        assertEq(contango.position(positionId).openQuantity, initialQuantity + quantity);
        assertApproxEqAbsDecimal(
            trader.balance, collateral - uint256(result.collateralUsed), 0.01 ether, quoteDecimals, "trader balance"
        );
        assertEq(WETH.balanceOf(address(contango)), 0);
    }

    // ==============================================
    // decreasePosition()
    // ==============================================

    function testDecreasePosition() public {
        uint256 initialQuantity = 30000e6;
        (PositionId positionId,) = _openPosition(initialQuantity);

        int256 quantity = -1000e6;

        ModifyCostResult memory modifyCostResult =
            contangoQuoter.modifyCostForPosition(ModifyCostParams(positionId, quantity, 0, collateralSlippage));

        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSelector(
            contango.modifyPosition.selector,
            positionId,
            quantity,
            modifyCostResult.cost,
            0,
            address(contango),
            modifyCostResult.quoteLendingLiquidity
        );
        // unwrap is not necessary since the no settlement nor execissve quote will be generated
        // adding it wouldn't break the code but would incur in unnecessary gas expenditure
        // since it becomes a single action, batching is also dispensable for gas savings, but is left here for example purposes

        vm.prank(trader);
        contango.batch(calls);

        assertEq(contango.position(positionId).openQuantity, initialQuantity - quantity.abs());
        assertEq(trader.balance, 0);
        assertEq(WETH.balanceOf(address(contango)), 0);
    }

    function testFullyClosePosition() public {
        int256 quantity = -30000e6;
        (PositionId positionId, ModifyCostResult memory openPositionResult) = _openPosition(quantity.abs());

        ModifyCostResult memory modifyCostResult =
            contangoQuoter.modifyCostForPosition(ModifyCostParams(positionId, quantity, 0, collateralSlippage));

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(
            contango.modifyPosition.selector,
            positionId,
            quantity,
            modifyCostResult.cost.slippage(),
            0,
            address(contango),
            modifyCostResult.quoteLendingLiquidity
        );
        // unwrap always necessary when fully closing to receive PnL since it's quoted in ETH
        calls[1] = abi.encodeWithSelector(contango.unwrapWETH.selector, trader);

        vm.prank(trader);
        contango.batch(calls);

        assertEq(contango.position(positionId).openQuantity, 0);
        assertApproxEqAbs(trader.balance, openPositionResult.collateralUsed.abs(), 0.25 ether, "trader balance");
        assertEq(WETH.balanceOf(address(contango)), 0);
    }

    function testDecreasePositionWithExcessQuote() public {
        uint256 initialQuantity = 30000e6;

        // in this example. we open a heavily collateralised position, so when we decrease, any excess quote is sent back to us
        // but it could also be due to a position becoming profitable for example
        (PositionId positionId,) = _openPosition(initialQuantity, 30 ether);

        // clear balance to make assertions easier
        clearBalanceETH(trader);

        int256 quantity = -15000e6;

        ModifyCostResult memory result = contangoQuoter.modifyCostForPosition(
            ModifyCostParams({
                positionId: positionId,
                quantity: quantity,
                collateral: 0,
                collateralSlippage: collateralSlippage
            })
        );

        // Negative collateralUsed means that quantity MUST be withdrawn
        assertLt(result.collateralUsed, 0, "collateralUsed");

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(
            contango.modifyPosition.selector,
            positionId,
            quantity,
            result.cost.slippage(),
            type(int256).min, // To avoid dust/slippage related issues, if we wanna withdraw all, we set the amount to a very high (low) number
            address(contango),
            result.quoteLendingLiquidity
        );
        // unwrap is necessary since we're receiving excess quote due to the position not having any debt to burn
        // the excess will be given back to the payer (contango because of the wrapping) and therefore we need to collect it
        // if we don't, it will sit in the contango contract and will be up for grabs!
        calls[1] = abi.encodeWithSelector(contango.unwrapWETH.selector, trader);

        vm.prank(trader);
        contango.batch(calls);

        assertEq(contango.position(positionId).openQuantity, initialQuantity - quantity.abs());
        // Balance is close to the original collateralUsed, but not the same, as the effective spot amount is used
        assertApproxEqAbsDecimal(
            trader.balance, result.collateralUsed.abs(), 0.02 ether, quoteDecimals, "trader balance"
        );
        assertEq(WETH.balanceOf(address(contango)), 0);
    }

    // ==============================================
    // removeCollateral()
    // ==============================================

    function testRemoveCollateral() public {
        uint256 quantity = 30000e6;
        (PositionId positionId,) = _openPosition(quantity);

        ModifyCostResult memory result = contangoQuoter.modifyCostForPosition(
            ModifyCostParams({
                positionId: positionId,
                quantity: 0,
                collateral: -0.001 ether,
                collateralSlippage: collateralSlippage
            })
        );

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(
            contango.modifyCollateral.selector,
            positionId,
            result.collateralUsed,
            result.debtDelta,
            address(contango),
            0
        );
        // unwrap is necessary since we're withdrawing in ETH quote
        // the value will be sent in WETH, so we send it to contango and therefore we need to collect it
        // if we don't, it will sit in the contango contract and will be up for grabs!
        calls[1] = abi.encodeWithSelector(contango.unwrapWETH.selector, trader);

        vm.prank(trader);
        contango.batch(calls);

        assertEq(contango.position(positionId).openQuantity, quantity);
        assertApproxEqAbsDecimal(trader.balance, result.collateralUsed.abs(), 1, quoteDecimals, "trader balance");
        assertEq(WETH.balanceOf(address(contango)), 0);
    }
}

contract YieldMainnetWethExamplesETHUSDCTest is
    WithYieldFixtures(constants.yETHUSDC2303, constants.FYETH2303, constants.FYUSDC2303)
{
    // ==============================================
    // deliver()
    // ==============================================

    function testDeliverPosition() public {
        // Given
        (PositionId positionId,) = _openPosition(20 ether);
        Position memory position = contango.position(positionId);

        // When
        vm.warp(cauldron.series(quoteSeriesId).maturity);

        uint256 deliveryCost = contangoQuoter.deliveryCostForPosition(positionId);
        dealAndApprove(address(USDC), trader, deliveryCost, address(contango));

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(contango.deliver.selector, positionId, trader, address(contango));
        // unwrap is necessary since we're delivering a position, so buying ETH (base) with USDC (quote)
        // the value will be sent in WETH, so we send it to contango and therefore we need to collect it
        // if we don't, it will sit in the contango contract and will be up for grabs!
        calls[1] = abi.encodeWithSelector(contango.unwrapWETH.selector, trader);

        vm.prank(trader);
        contango.batch(calls);

        // Then
        assertPositionWasClosed(positionId);
        assertEq(USDC.balanceOf(trader), 0);
        assertEq(trader.balance, uint256(position.openQuantity));
        assertEq(WETH.balanceOf(address(contango)), 0);
    }
}
