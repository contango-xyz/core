//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../PositionFixtures.sol";

/// @notice these examples apply to any ETH quoted instrument
abstract contract WethExamplesETHQuoteFixtures is PositionFixtures {
    using SignedMath for int256;
    using SafeCast for int256;
    using TestUtils for *;

    // ==============================================
    // createPosition()
    // ==============================================

    function _testCreatePosition(uint256 quantity, uint256 collateral) internal {
        ModifyCostResult memory openingCostResult = contangoQuoter.openingCostForPositionWithCollateral(
            OpeningCostParams(symbol, quantity, collateralSlippage, uniswapFee), collateral
        );

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
            openingCostResult.baseLendingLiquidity,
            uniswapFee
        );
        // unwrap is not necessary since the full collateral posted will be used
        // adding it wouldn't break the code but would incur in unnecessary gas expenditure

        vm.deal(trader, openingCostResult.collateralUsed.toUint256());
        vm.prank(trader);
        bytes[] memory results = contango.batch{value: openingCostResult.collateralUsed.toUint256()}(calls);
        PositionId positionId = abi.decode(results[1], (PositionId));

        assertEqDecimal(contango.position(positionId).openQuantity, quantity, baseDecimals, "openQuantity");
        assertEqDecimal(trader.balance, 0, quoteDecimals, "trader ETH balance");
        assertEqDecimal(quote.balanceOf(address(contango)), 0, quoteDecimals, "contango quote balance");
    }

    function _testOpenPositionOnBehalfOfSomeoneElse(uint256 quantity, uint256 collateral) internal {
        address proxy = address(0x99);

        ModifyCostResult memory openingCostResult = contangoQuoter.openingCostForPositionWithCollateral(
            OpeningCostParams(symbol, quantity, collateralSlippage, uniswapFee), collateral
        );

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
            openingCostResult.baseLendingLiquidity,
            uniswapFee
        );
        // unwrap is not necessary since the full collateral posted will be used
        // adding it wouldn't break the code but would incur in unnecessary gas expenditure

        vm.deal(proxy, openingCostResult.collateralUsed.toUint256());
        vm.prank(proxy);
        bytes[] memory results = contango.batch{value: openingCostResult.collateralUsed.toUint256()}(calls);
        PositionId positionId = abi.decode(results[1], (PositionId));

        assertEqDecimal(contango.position(positionId).openQuantity, quantity, baseDecimals, "openQuantity");
        assertEqDecimal(trader.balance, 0, quoteDecimals, "trader ETH balance");
        assertEqDecimal(quote.balanceOf(address(contango)), 0, quoteDecimals, "contango quote balance");
    }

    function _testCreateFullCollateralisedPosition(uint256 quantity) internal {
        OpeningCostParams memory params = OpeningCostParams(symbol, quantity, collateralSlippage, uniswapFee);
        ModifyCostResult memory openingCostResult = contangoQuoter.openingCostForPositionWithCollateral(params, 0);
        openingCostResult =
            contangoQuoter.openingCostForPositionWithCollateral(params, openingCostResult.maxCollateral.toUint256());

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
            openingCostResult.baseLendingLiquidity,
            uniswapFee
        );
        // unwrap is necessary since we're providing more than the maximum collateral
        // the excess will be given back to the payer (contango because of the wrapping) and therefore we need to collect it
        // if we don't, it will sit in the contango contract and will be up for grabs!
        calls[2] = abi.encodeWithSelector(contango.unwrapWETH.selector, trader);

        vm.deal(trader, openingCostResult.maxCollateral.toUint256() + 0.1 ether);
        vm.prank(trader);
        bytes[] memory results = contango.batch{value: openingCostResult.maxCollateral.toUint256() + 0.1 ether}(calls);
        PositionId positionId = abi.decode(results[1], (PositionId));

        assertEqDecimal(contango.position(positionId).openQuantity, quantity, baseDecimals, "openQuantity");
        assertEqDecimal(trader.balance, 0.1 ether, quoteDecimals, "trader ETH balance");
        assertEqDecimal(quote.balanceOf(address(contango)), 0, quoteDecimals, "contango quote balance");
    }

    // ==============================================
    // increasePosition()
    // ==============================================

    function _testIncreasePosition(uint256 quantity, uint256 increaseQuantity) internal {
        (PositionId positionId,) = _openPosition(quantity);

        ModifyCostResult memory increasingCostResult = contangoQuoter.modifyCostForPositionWithCollateral(
            ModifyCostParams(positionId, int256(increaseQuantity), collateralSlippage, uniswapFee), 0
        );

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(contango.wrapETH.selector);
        calls[1] = abi.encodeWithSelector(
            contango.modifyPosition.selector,
            positionId,
            increaseQuantity,
            increasingCostResult.cost.slippage(),
            increasingCostResult.collateralUsed,
            address(contango),
            increasingCostResult.baseLendingLiquidity,
            uniswapFee
        );
        // unwrap is not necessary since the full collateral posted will be used
        // adding it wouldn't break the code but would incur in unnecessary gas expenditure

        vm.deal(trader, increasingCostResult.collateralUsed.toUint256());
        vm.prank(trader);
        contango.batch{value: increasingCostResult.collateralUsed.toUint256()}(calls);

        assertEqDecimal(
            contango.position(positionId).openQuantity, quantity + increaseQuantity, baseDecimals, "openQuantity"
        );
        assertEqDecimal(trader.balance, 0, quoteDecimals, "trader ETH balance");
        assertEqDecimal(quote.balanceOf(address(contango)), 0, quoteDecimals, "contango quote balance");
    }

    function _testIncreaseAndCollateralisePositionAtMax(uint256 quantity, uint256 collateral, uint256 increaseQuantity)
        internal
    {
        (PositionId positionId,) = _openPosition(quantity);

        ModifyCostResult memory result = contangoQuoter.modifyCostForPositionWithCollateral(
            ModifyCostParams({
                positionId: positionId,
                quantity: int256(increaseQuantity),
                collateralSlippage: collateralSlippage,
                uniswapFee: uniswapFee
            }),
            int256(collateral)
        );

        uint256 cost = (result.cost + result.financingCost).slippage();
        int256 amountToUseInAddCollateralCall =
            (int256((result.debtDelta - result.financingCost).abs()) * 0.999e18) / 1e18;
        uint256 costToUseInAddCollateralCall = (result.debtDelta.abs() * 0.999e18) / 1e18;

        bytes[] memory calls = new bytes[](4);
        calls[0] = abi.encodeWithSelector(contango.wrapETH.selector);
        calls[1] = abi.encodeWithSelector(
            contango.modifyPosition.selector,
            positionId,
            increaseQuantity,
            cost,
            result.collateralUsed,
            address(contango),
            result.baseLendingLiquidity,
            uniswapFee
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

        bool expectRevert = _shouldExpectRevertForMultipleOperationsOnTheSameTx();

        vm.deal(trader, collateral);
        vm.prank(trader);
        contango.batch{value: collateral}(calls);

        if (expectRevert) {
            // check necessary due to how foundry checks for reverts. if it arrives here, it did revert according to the expectations
            return;
        }

        assertEqDecimal(
            contango.position(positionId).openQuantity, quantity + increaseQuantity, baseDecimals, "openQuantity"
        );
        assertEqDecimal(quote.balanceOf(address(contango)), 0, quoteDecimals, "contango quote balance");

        uint256 expectedBalance = collateral - result.collateralUsed.abs();
        assertApproxEqAbsDecimal(
            trader.balance,
            expectedBalance,
            expectedBalance * 0.02e2 / 1e2, // around 2% to cover underlying protocol spreads + possible fees
            quoteDecimals,
            "trader ETH balance"
        );
    }

    // ==============================================
    // decreasePosition()
    // ==============================================

    function _testDecreasePosition(uint256 quantity, int256 decreaseQuantity) internal {
        (PositionId positionId,) = _openPosition(quantity);

        ModifyCostResult memory modifyCostResult = contangoQuoter.modifyCostForPositionWithCollateral(
            ModifyCostParams(positionId, decreaseQuantity, collateralSlippage, uniswapFee), 0
        );

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(
            contango.modifyPosition.selector,
            positionId,
            decreaseQuantity,
            modifyCostResult.cost,
            0,
            address(contango),
            modifyCostResult.quoteLendingLiquidity,
            uniswapFee
        );
        // unwrap is necessary since due to potential excess quote received from uniswap
        // this could be caused by how the underlying protocols calculate the amount need for repayment when exiting the borrowing position
        // TODO alfredo - evaluate if we want to leave the dust in the proxy itself
        calls[1] = abi.encodeWithSelector(contango.unwrapWETH.selector, trader);

        vm.prank(trader);
        contango.batch(calls);

        assertEqDecimal(
            contango.position(positionId).openQuantity, quantity - decreaseQuantity.abs(), baseDecimals, "openQuantity"
        );
        assertApproxEqAbsDecimal(trader.balance, 0, maxQuoteDust, quoteDecimals, "trader ETH balance");
        assertEqDecimal(quote.balanceOf(address(contango)), 0, quoteDecimals, "contango quote balance");
    }

    function _testFullyClosePosition(int256 quantity) internal {
        (PositionId positionId, ModifyCostResult memory openPositionResult) = _openPosition(quantity.abs());

        ModifyCostResult memory modifyCostResult = contangoQuoter.modifyCostForPositionWithCollateral(
            ModifyCostParams(positionId, quantity, collateralSlippage, uniswapFee), 0
        );

        Position memory position = contango.position(positionId);
        int256 expectedPnL = modifyCostResult.cost - int256(position.openCost);

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(
            contango.modifyPosition.selector,
            positionId,
            quantity,
            modifyCostResult.cost.slippage(),
            0,
            address(contango),
            modifyCostResult.quoteLendingLiquidity,
            uniswapFee
        );
        // unwrap always necessary when fully closing to receive PnL since it's quoted in ETH
        calls[1] = abi.encodeWithSelector(contango.unwrapWETH.selector, trader);

        vm.prank(trader);
        contango.batch(calls);

        assertEqDecimal(contango.position(positionId).openQuantity, 0, baseDecimals, "openQuantity");
        assertEqDecimal(quote.balanceOf(address(contango)), 0, quoteDecimals, "contango quote balance");

        uint256 expectedBalance = (openPositionResult.collateralUsed + expectedPnL).abs();
        assertApproxEqAbsDecimal(
            trader.balance,
            expectedBalance,
            // TODO Alfredo, I fixed this for Yield by calculating the PnL, it's only 1 wei off, but for Notional is quite off, maybe a bug on the notional side?
            expectedBalance * 0.02e2 / 1e2, // around 2% to cover underlying protocol spreads + possible fees
            quoteDecimals,
            "trader ETH balance"
        );
    }

    function _testDecreasePositionWithExcessQuote(uint256 quantity, uint256 collateral, int256 decreaseQuantity)
        internal
    {
        // in this example. we open a heavily collateralised position, so when we decrease, any excess quote is sent back to us
        // but it could also be due to a position becoming profitable for example
        (PositionId positionId,) = _openPosition(quantity, collateral);

        // clear balance to make assertions easier
        clearBalanceETH(trader);

        ModifyCostResult memory result = contangoQuoter.modifyCostForPositionWithCollateral(
            ModifyCostParams({
                positionId: positionId,
                quantity: decreaseQuantity,
                collateralSlippage: collateralSlippage,
                uniswapFee: uniswapFee
            }),
            0
        );

        // Negative collateralUsed means that quantity MUST be withdrawn
        assertLtDecimal(result.collateralUsed, 0, quoteDecimals, "collateralUsed");

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(
            contango.modifyPosition.selector,
            positionId,
            decreaseQuantity,
            result.cost.slippage(),
            type(int256).min, // To avoid dust/slippage related issues, if we wanna withdraw all, we set the amount to a very high (low) number
            address(contango),
            result.quoteLendingLiquidity,
            uniswapFee
        );
        // unwrap is necessary since we're receiving excess quote due to the position not having any debt to burn
        // the excess will be given back to the payer (contango because of the wrapping) and therefore we need to collect it
        // if we don't, it will sit in the contango contract and will be up for grabs!
        calls[1] = abi.encodeWithSelector(contango.unwrapWETH.selector, trader);

        vm.prank(trader);
        contango.batch(calls);

        assertEqDecimal(
            contango.position(positionId).openQuantity, quantity - decreaseQuantity.abs(), baseDecimals, "openQuantity"
        );
        assertEqDecimal(quote.balanceOf(address(contango)), 0, quoteDecimals, "contango quote balance");

        // Balance is close to the spot cost
        uint256 expectedBalance = result.spotCost.abs();
        assertApproxEqAbsDecimal(
            trader.balance,
            expectedBalance,
            expectedBalance * 0.02e2 / 1e2, // around 2% to cover underlying protocol spreads + possible fees
            quoteDecimals,
            "trader ETH balance"
        );
    }

    // ==============================================
    // removeCollateral()
    // ==============================================

    function _testRemoveCollateral(uint256 quantity, int256 collateralToRemove) internal {
        (PositionId positionId,) = _openPosition(quantity);

        ModifyCostResult memory result = contangoQuoter.modifyCostForPositionWithCollateral(
            ModifyCostParams({
                positionId: positionId,
                quantity: 0,
                collateralSlippage: collateralSlippage,
                uniswapFee: uniswapFee
            }),
            collateralToRemove
        );

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(
            contango.modifyCollateral.selector,
            positionId,
            result.collateralUsed,
            result.debtDelta,
            address(contango),
            0,
            uniswapFee
        );
        // unwrap is necessary since we're withdrawing in ETH quote
        // the value will be sent in WETH, so we send it to contango and therefore we need to collect it
        // if we don't, it will sit in the contango contract and will be up for grabs!
        calls[1] = abi.encodeWithSelector(contango.unwrapWETH.selector, trader);

        vm.prank(trader);
        contango.batch(calls);

        assertEqDecimal(contango.position(positionId).openQuantity, quantity, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(trader.balance, result.collateralUsed.abs(), 1, quoteDecimals, "trader ETH balance");
        assertEqDecimal(quote.balanceOf(address(contango)), 0, quoteDecimals, "contango quote balance");
    }

    /// @dev hook to expect a revert if multiples operations on the same block are not accepted
    /// refer to overrides of this function to see if the underlying protocol accepts it or not
    /// by default, it does not expect any revert
    /// @return flag indicating a revert was expected or not
    function _shouldExpectRevertForMultipleOperationsOnTheSameTx() internal virtual returns (bool) {
        return false;
    }
}

/// @notice these examples apply to any ETH base instrument
abstract contract WethExamplesETHBaseFixtures is PositionFixtures {
    // using SignedMath for int256;
    // using SafeCast for int256;
    // using SignedMathLib for int256;
    // using TestUtils for *;

    // ==============================================
    // deliver()
    // ==============================================

    function _testDeliverPosition(uint256 quantity) internal {
        // Given
        (PositionId positionId,) = _openPosition(quantity);
        Position memory position = contango.position(positionId);

        // When
        vm.warp(maturity);

        uint256 deliveryCost = contangoQuoter.deliveryCostForPosition(positionId);
        dealAndApprove(address(quote), trader, deliveryCost, address(contango));

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
        assertEqDecimal(trader.balance, uint256(position.openQuantity), baseDecimals, "trader ETH balance");
        assertEqDecimal(quote.balanceOf(trader), 0, quoteDecimals, "trader quote balance");
        assertEqDecimal(base.balanceOf(address(contango)), 0, baseDecimals, "contango base balance");
    }
}

// ========== Mainnet ==========

abstract contract MainnetWethExamplesUSDCETHFixtures is WethExamplesETHQuoteFixtures {
    function testCreatePosition() public {
        _testCreatePosition({quantity: 30_000e6, collateral: 1 ether});
    }

    function testOpenPositionOnBehalfOfSomeoneElse() public {
        _testOpenPositionOnBehalfOfSomeoneElse({quantity: 30_000e6, collateral: 1 ether});
    }

    function testCreateFullCollateralisedPosition() public {
        _testCreateFullCollateralisedPosition({quantity: 30_000e6});
    }

    function testIncreasePosition() public {
        _testIncreasePosition({quantity: 8_000e6, increaseQuantity: 1_000e6});
    }

    function testIncreaseAndCollateralisePositionAtMax() public virtual {
        _testIncreaseAndCollateralisePositionAtMax({quantity: 20_000e6, collateral: 30 ether, increaseQuantity: 1_000e6});
    }

    function testDecreasePosition() public {
        _testDecreasePosition({quantity: 30_000e6, decreaseQuantity: -1_000e6});
    }

    function testFullyClosePosition() public {
        _testFullyClosePosition({quantity: -30_000e6});
    }

    function testDecreasePositionWithExcessQuote() public {
        _testDecreasePositionWithExcessQuote({quantity: 30_000e6, collateral: 30 ether, decreaseQuantity: -15_000e6});
    }

    function testRemoveCollateral() public {
        _testRemoveCollateral({quantity: 30_000e6, collateralToRemove: -0.001 ether});
    }
}

abstract contract MainnetWethExamplesETHUSDCFixtures is WethExamplesETHBaseFixtures {
    function testDeliverPosition() public {
        _testDeliverPosition({quantity: 20 ether});
    }
}

// ========== Arbitrum ==========

abstract contract ArbitrumWethExamplesUSDCETHFixtures is WethExamplesETHQuoteFixtures {
    function testCreatePosition() public {
        _testCreatePosition({quantity: 3_000e6, collateral: 1 ether});
    }

    function testOpenPositionOnBehalfOfSomeoneElse() public {
        _testOpenPositionOnBehalfOfSomeoneElse({quantity: 3_000e6, collateral: 1 ether});
    }

    function testCreateFullCollateralisedPosition() public {
        _testCreateFullCollateralisedPosition({quantity: 3_000e6});
    }

    function testIncreasePosition() public {
        _testIncreasePosition({quantity: 3_000e6, increaseQuantity: 3_000e6});
    }

    function testIncreaseAndCollateralisePositionAtMax() public {
        _testIncreaseAndCollateralisePositionAtMax({quantity: 3_000e6, collateral: 6 ether, increaseQuantity: 3_000e6});
    }

    function testDecreasePosition() public {
        _testDecreasePosition({quantity: 3_000e6, decreaseQuantity: -1_000e6});
    }

    function testFullyClosePosition() public {
        _testFullyClosePosition({quantity: -3_000e6});
    }

    function testDecreasePositionWithExcessQuote() public {
        _testDecreasePositionWithExcessQuote({quantity: 2_000e6, collateral: 2 ether, decreaseQuantity: -1_000e6});
    }

    function testRemoveCollateral() public {
        _testRemoveCollateral({quantity: 3_000e6, collateralToRemove: -0.001 ether});
    }
}

abstract contract ArbitrumWethExamplesETHUSDCFixtures is WethExamplesETHBaseFixtures {
    function testDeliverPosition() public {
        _testDeliverPosition({quantity: 2 ether});
    }
}
