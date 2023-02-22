//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/SignedMath.sol";

import "src/interfaces/IFeeModel.sol";

import "src/libraries/DataTypes.sol";
import "src/libraries/QuoterDataTypes.sol";

import "../../utils/TestUtils.sol";
import "../../ContangoTestBase.sol";

// solhint-disable func-name-mixedcase
abstract contract PositionFixtures is ContangoTestBase {
    using Math for uint256;
    using SafeCast for int256;
    using SignedMath for int256;
    using TestUtils for *;

    struct UnderlyingBalances {
        uint256 borrowing;
        uint256 lending;
    }

    Vm.Log[] internal recordedLogs;

    uint24 uniswapFee = 3000;

    uint256 internal quoteDecimals;
    uint256 internal baseDecimals;
    uint256 internal maxBaseDust;
    uint256 internal maxQuoteDust;

    Symbol internal symbol;

    constructor(Symbol _symbol) {
        symbol = _symbol;
    }

    // solhint-disable-next-line no-empty-blocks
    function _afterOpenPosition(PositionId positionId) internal virtual {}

    // solhint-disable-next-line no-empty-blocks
    function _afterModifyPosition(PositionId positionId) internal virtual {}

    // solhint-disable-next-line no-empty-blocks
    function _afterModifyCollateral(PositionId positionId) internal virtual {}

    function _underlyingBalances(PositionId positionId) internal virtual returns (UnderlyingBalances memory);

    function _dealCollateral(uint256 collateral) internal {
        if (quote == WETH9) {
            vm.deal(trader, collateral);
        } else {
            dealAndApprove(address(quote), trader, collateral, address(contango));
        }
    }

    function quoteBalance(address account) internal view returns (uint256) {
        return quote == WETH9 ? account.balance : quote.balanceOf(account);
    }

    function _assertNoBalances(address addr, string memory label) internal {
        _assertNoBalances(addr, string.concat(label, " base"), base, baseDecimals);
        _assertNoBalances(addr, string.concat(label, " quote"), quote, quoteDecimals);
        _assertNoBalances(addr, string.concat(label, " ETH"), ERC20(address(0)), 18);
    }

    function _assertNoBalances(address addr, string memory label, ERC20 token, uint256 decimals) internal {
        uint256 balance = address(token) == address(0) ? addr.balance : token.balanceOf(addr);
        assertEqDecimal(balance, 0, decimals, string.concat(label, " dust"));
    }

    function _openPosition(uint256 quantity) internal returns (PositionId, ModifyCostResult memory) {
        return _openPosition(trader, quantity);
    }

    function _openPosition(address owner, uint256 quantity)
        internal
        returns (PositionId positionId, ModifyCostResult memory result)
    {
        ModifyCostResult memory initialQuote = contangoQuoter.openingCostForPositionWithCollateral(
            OpeningCostParams(symbol, quantity, collateralSlippage, uniswapFee), 0
        );

        // 10% over min
        return _openPosition(owner, quantity, ((initialQuote.minCollateral * 1.1e1) / 1e1).toUint256());
    }

    function _openPosition(uint256 quantity, uint256 collateral)
        internal
        returns (PositionId, ModifyCostResult memory)
    {
        return _openPosition(trader, quantity, collateral);
    }

    function _openPositionAtLeverage(uint256 quantity, uint256 leverage)
        internal
        returns (PositionId, ModifyCostResult memory)
    {
        ModifyCostResult memory _quote = contangoQuoter.openingCostForPositionWithLeverage(
            OpeningCostParams(symbol, quantity, collateralSlippage, uniswapFee), leverage
        );

        return _openPosition(trader, quantity, _quote.collateralUsed.toUint256());
    }

    function _openPosition(address owner, uint256 quantity, uint256 collateral)
        internal
        returns (PositionId positionId, ModifyCostResult memory result)
    {
        result = contangoQuoter.openingCostForPositionWithCollateral(
            OpeningCostParams(symbol, quantity, collateralSlippage, uniswapFee), collateral
        );
        require(!result.insufficientLiquidity, "insufficientLiquidity");

        vm.recordLogs();
        positionId = _createPosition(owner, quantity, result);

        {
            Position memory position = contango.position(positionId);
            assertEq(Symbol.unwrap(position.symbol), Symbol.unwrap(symbol), "position.symbol");
            assertEqDecimal(position.openQuantity, quantity, baseDecimals, "position.openQuantity");
            assertApproxEqAbsDecimal(
                position.openCost, result.cost.abs(), maxQuoteDust, quoteDecimals, "position.openCost"
            );
            assertApproxEqAbsDecimal(
                position.protocolFees, result.fee, maxQuoteDust, quoteDecimals, "position.protocolFees"
            );
            assertEqDecimal(
                position.collateral,
                result.collateralUsed - int256(position.protocolFees),
                quoteDecimals,
                "position.collateral"
            );

            Vm.Log memory _log = _updateRecordedLogs().first(
                "PositionUpserted(bytes32,address,uint256,uint256,uint256,int256,uint256,uint256,int256)"
            );
            assertEq(_log.topics[1], Symbol.unwrap(symbol));
            assertEq(uint256(_log.topics[2]), uint160(address(owner)));
            assertEq(uint256(_log.topics[3]), PositionId.unwrap(positionId));

            (
                uint256 openQuantity,
                uint256 openCost,
                int256 _collateral,
                uint256 totalFees,
                uint256 txFees,
                int256 realisedPnL
            ) = abi.decode(_log.data, (uint256, uint256, int256, uint256, uint256, int256));

            assertEqDecimal(openQuantity, quantity, baseDecimals, "PositionUpserted.openQuantity");
            assertApproxEqAbsDecimal(
                openCost, result.cost.abs(), maxQuoteDust, quoteDecimals, "PositionUpserted.openCost"
            );
            assertApproxEqAbsDecimal(txFees, result.fee, maxQuoteDust, quoteDecimals, "PositionUpserted.txFees");
            assertApproxEqAbsDecimal(totalFees, result.fee, maxQuoteDust, quoteDecimals, "PositionUpserted.totalFees");
            assertEqDecimal(realisedPnL, 0, quoteDecimals, "PositionUpserted.realisedPnL");
            assertEqDecimal(
                _collateral, result.collateralUsed - int256(txFees), quoteDecimals, "PositionUpserted.collateral"
            );
        }

        assertEqDecimal(address(contango).balance, 0, quoteDecimals, "contango ETH balance");
        assertApproxEqAbsDecimal(quote.balanceOf(address(contango)), 0, maxQuoteDust, quoteDecimals, "contango balance");

        assertEqDecimal(quote.balanceOf(treasury), 0, quoteDecimals, "treasury balance");
        assertApproxEqAbsDecimal(quoteBalance(owner), 0, maxQuoteDust, quoteDecimals, "owner balance");

        _afterOpenPosition(positionId);
    }

    function _createPosition(uint256 quantity, ModifyCostResult memory result) internal returns (PositionId) {
        return _createPosition(trader, quantity, result);
    }

    function _createPosition(address owner, uint256 quantity, ModifyCostResult memory result)
        internal
        returns (PositionId positionId)
    {
        if (quote == WETH9) {
            vm.deal(owner, result.collateralUsed.toUint256());

            bytes[] memory calls = new bytes[](2);
            calls[0] = abi.encodeWithSelector(contango.wrapETH.selector);
            calls[1] = abi.encodeWithSelector(
                contango.createPosition.selector,
                symbol,
                owner,
                quantity,
                result.cost.slippage(),
                result.collateralUsed.toUint256(),
                address(contango),
                result.baseLendingLiquidity,
                uniswapFee
            );

            vm.prank(owner);
            bytes[] memory results = contango.batch{value: result.collateralUsed.toUint256()}(calls);
            positionId = abi.decode(results[1], (PositionId));
        } else {
            dealAndApprove({
                token: address(quote),
                to: owner,
                amount: result.collateralUsed.toUint256(),
                approveTo: address(contango)
            });
            vm.prank(owner);
            positionId = contango.createPosition(
                symbol,
                owner,
                quantity,
                result.cost.slippage(),
                result.collateralUsed.toUint256(),
                owner,
                result.baseLendingLiquidity,
                uniswapFee
            );
        }
    }

    function _closePosition(PositionId positionId) internal returns (ModifyCostResult memory result) {
        uint256 traderBalance = quoteBalance(trader);
        uint256 treasuryBalance = quote.balanceOf(treasury);
        Position memory position = contango.position(positionId);
        int256 closeQty = -int256(position.openQuantity);

        result = contangoQuoter.modifyCostForPositionWithCollateral(
            ModifyCostParams(positionId, closeQty, collateralSlippage, uniswapFee), 0
        );
        require(!result.insufficientLiquidity, "insufficientLiquidity");

        vm.recordLogs();
        _modifyPosition(positionId, closeQty, result);

        assertPositionWasClosed(positionId);

        Vm.Log memory _log = _updateRecordedLogs().first(
            "PositionClosed(bytes32,address,uint256,uint256,uint256,int256,uint256,uint256,int256)"
        );
        assertEq(_log.topics[1], Symbol.unwrap(symbol));
        assertEq(uint256(_log.topics[2]), uint160(address(trader)));
        assertEq(uint256(_log.topics[3]), PositionId.unwrap(positionId));

        (
            uint256 closedQuantity,
            uint256 closedCost,
            int256 collateral,
            uint256 totalFees,
            uint256 txFees,
            int256 realisedPnL
        ) = abi.decode(_log.data, (uint256, uint256, int256, uint256, uint256, int256));

        assertEqDecimal(closedQuantity, position.openQuantity, baseDecimals, "closedQuantity");
        assertEqDecimal(closedCost, position.openCost, quoteDecimals, "closedCost");
        assertApproxEqAbsDecimal(txFees, result.fee, maxQuoteDust, quoteDecimals, "txFees");
        assertApproxEqAbsDecimal(
            totalFees, position.protocolFees + result.fee, maxQuoteDust, quoteDecimals, "totalFees"
        );
        assertApproxEqAbsDecimal(
            realisedPnL, result.cost - int256(closedCost), maxQuoteDust, quoteDecimals, "realisedPnL"
        );
        assertEqDecimal(collateral, position.collateral - int256(txFees) + realisedPnL, quoteDecimals, "collateral");

        assertEqDecimal(address(contango).balance, 0, quoteDecimals, "contango ETH balance");
        assertApproxEqAbsDecimal(quote.balanceOf(address(contango)), 0, maxQuoteDust, quoteDecimals, "contango balance");

        assertEqDecimal(quote.balanceOf(treasury), treasuryBalance + totalFees, quoteDecimals, "treasury balance");
        assertApproxEqAbsDecimal(
            quoteBalance(trader), traderBalance + uint256(collateral), maxQuoteDust, quoteDecimals, "trader balance"
        );
    }

    function _modifyPosition(PositionId positionId, int256 quantity, int256 collateral)
        internal
        returns (ModifyCostResult memory result)
    {
        uint256 traderBalance = quoteBalance(trader);
        uint256 treasuryBalance = quote.balanceOf(treasury);

        Position memory position = contango.position(positionId);
        result = contangoQuoter.modifyCostForPositionWithCollateral(
            ModifyCostParams(positionId, quantity, collateralSlippage, uniswapFee), collateral
        );
        require(!result.insufficientLiquidity, "insufficientLiquidity");

        if (result.collateralUsed < 0) {
            traderBalance += result.collateralUsed.abs();
        }

        vm.recordLogs();
        _modifyPosition(positionId, quantity, result);

        {
            Vm.Log memory _log = _updateRecordedLogs().first(
                "PositionUpserted(bytes32,address,uint256,uint256,uint256,int256,uint256,uint256,int256)"
            );
            assertEq(_log.topics[1], Symbol.unwrap(symbol));
            assertEq(uint256(_log.topics[2]), uint160(address(trader)));
            assertEq(uint256(_log.topics[3]), PositionId.unwrap(positionId));

            int256 _quantity = quantity;

            (
                uint256 openQuantity,
                uint256 openCost,
                int256 _collateral,
                uint256 totalFees,
                uint256 txFees,
                int256 realisedPnL
            ) = abi.decode(_log.data, (uint256, uint256, int256, uint256, uint256, int256));

            if (quantity > 0) {
                assertEqDecimal(realisedPnL, 0, quoteDecimals, "realisedPnL");
                assertApproxEqAbsDecimal(
                    openCost, position.openCost + result.cost.abs(), maxQuoteDust, quoteDecimals, "openCost"
                );
            } else {
                uint256 closedCost = (_quantity.abs() * position.openCost).ceilDiv(position.openQuantity);
                assertEqDecimal(openCost, position.openCost - closedCost, quoteDecimals, "openCost");
                assertApproxEqAbsDecimal(
                    realisedPnL, result.cost - int256(closedCost), maxQuoteDust, quoteDecimals, "realisedPnL"
                );
            }
            assertEqDecimal(
                openQuantity, uint256(int256(position.openQuantity) + _quantity), baseDecimals, "openQuantity"
            );
            assertApproxEqAbsDecimal(txFees, result.fee, maxQuoteDust, quoteDecimals, "txFees");
            assertApproxEqAbsDecimal(
                totalFees, position.protocolFees + result.fee, maxQuoteDust, quoteDecimals, "totalFees"
            );
            assertEqDecimal(
                _collateral,
                position.collateral - int256(txFees) + realisedPnL + result.collateralUsed,
                quoteDecimals,
                "collateral"
            );
        }

        assertEqDecimal(address(contango).balance, 0, quoteDecimals, "contango ETH balance");
        assertApproxEqAbsDecimal(quote.balanceOf(address(contango)), 0, maxQuoteDust, quoteDecimals, "contango balance");

        assertEqDecimal(quote.balanceOf(treasury), treasuryBalance, quoteDecimals, "treasury balance");
        assertApproxEqAbsDecimal(quoteBalance(trader), traderBalance, maxQuoteDust, quoteDecimals, "trader balance");
    }

    function _modifyPosition(PositionId positionId, int256 quantity, ModifyCostResult memory result) internal {
        address payerOrReceiver = trader;
        uint256 callNo = 1; // Call to modifyPosition
        if (result.needsBatchedCall) {
            callNo++; // Extra call to modifyCollateral
        }
        if (quote == WETH9) {
            payerOrReceiver = address(contango);
            callNo++; // Extra call to unwrapWETH (we always unwrap in case we sent too much)
            if (result.collateralUsed > 0) {
                callNo++; // Extra call to wrapWETH
            }
        }

        bytes[] memory calls = new bytes[](callNo);
        uint256 callIdx;

        if (quote == WETH9 && result.collateralUsed > 0) {
            calls[callIdx++] = abi.encodeWithSelector(contango.wrapETH.selector);
        }

        if (result.needsBatchedCall) {
            uint256 modifyPositionCost = (result.cost + result.financingCost).slippage();
            int256 modifyCollateralAmount = result.financingCost - result.debtDelta;
            int256 modifyPositionCollateralAmount = result.collateralUsed - modifyCollateralAmount;

            calls[callIdx++] = abi.encodeWithSelector(
                contango.modifyPosition.selector,
                positionId,
                quantity,
                modifyPositionCost,
                modifyPositionCollateralAmount,
                payerOrReceiver,
                quantity > 0 ? result.baseLendingLiquidity : result.quoteLendingLiquidity,
                uniswapFee
            );
            calls[callIdx++] = abi.encodeWithSelector(
                contango.modifyCollateral.selector,
                positionId,
                modifyCollateralAmount,
                result.debtDelta.abs(),
                payerOrReceiver,
                result.collateralUsed > 0 ? result.quoteLendingLiquidity : 0
            );
        } else {
            calls[callIdx++] = abi.encodeWithSelector(
                contango.modifyPosition.selector,
                positionId,
                quantity,
                result.cost.slippage(),
                result.collateralUsed,
                payerOrReceiver,
                quantity > 0 ? result.baseLendingLiquidity : result.quoteLendingLiquidity,
                uniswapFee
            );
        }

        if (quote == WETH9) {
            calls[callIdx++] = abi.encodeWithSelector(contango.unwrapWETH.selector, trader);
        }

        if (result.collateralUsed > 0) {
            _dealCollateral(result.collateralUsed.toUint256());
        }

        vm.prank(trader);
        contango.batch{value: result.collateralUsed > 0 && quote == WETH9 ? result.collateralUsed.toUint256() : 0}(
            calls
        );

        _afterModifyPosition(positionId);
    }

    function _modifyCollateral(PositionId positionId, int256 collateral)
        internal
        returns (ModifyCostResult memory result)
    {
        uint256 traderBalance = quoteBalance(trader);
        uint256 treasuryBalance = quote.balanceOf(treasury);
        Position memory position = contango.position(positionId);

        result = contangoQuoter.modifyCostForPositionWithCollateral(
            ModifyCostParams({
                positionId: positionId,
                quantity: 0,
                collateralSlippage: collateralSlippage,
                uniswapFee: uniswapFee
            }),
            collateral
        );
        require(!result.insufficientLiquidity, "insufficientLiquidity");

        vm.recordLogs();
        _modifyCollateral(
            positionId, result.collateralUsed, result.debtDelta.abs(), collateral > 0 ? result.quoteLendingLiquidity : 0
        );

        {
            Vm.Log memory _log = _updateRecordedLogs().first(
                "PositionUpserted(bytes32,address,uint256,uint256,uint256,int256,uint256,uint256,int256)"
            );
            assertEq(_log.topics[1], Symbol.unwrap(symbol));
            assertEq(uint256(_log.topics[2]), uint160(address(trader)));
            assertEq(uint256(_log.topics[3]), PositionId.unwrap(positionId));

            (
                uint256 openQuantity,
                uint256 openCost,
                int256 _collateral,
                uint256 totalFees,
                uint256 txFees,
                int256 realisedPnL
            ) = abi.decode(_log.data, (uint256, uint256, int256, uint256, uint256, int256));

            assertEqDecimal(openQuantity, position.openQuantity, baseDecimals, "openQuantity");
            assertApproxEqAbsDecimal(
                int256(openCost), int256(position.openCost) + result.financingCost, 2, quoteDecimals, "openCost"
            );
            assertEqDecimal(realisedPnL, 0, quoteDecimals, "realisedPnL");
            assertEqDecimal(txFees, result.fee, quoteDecimals, "txFees");
            assertEqDecimal(totalFees, position.protocolFees + txFees, quoteDecimals, "totalFees");
            assertEqDecimal(
                _collateral, position.collateral - int256(txFees) + result.collateralUsed, quoteDecimals, "collateral"
            );
        }

        assertEqDecimal(address(contango).balance, 0, quoteDecimals, "contango ETH balance");
        assertApproxEqAbsDecimal(quote.balanceOf(address(contango)), 0, maxQuoteDust, quoteDecimals, "contango balance");

        assertEqDecimal(quote.balanceOf(treasury), treasuryBalance, quoteDecimals, "treasury balance");
        assertApproxEqAbsDecimal(
            quoteBalance(trader),
            traderBalance + uint256(result.collateralUsed < 0 ? result.collateralUsed.abs() : 0),
            maxQuoteDust,
            quoteDecimals,
            "trader balance"
        );
    }

    function _modifyCollateral(PositionId positionId, int256 collateral, uint256 limitCost, uint256 lendingLiquidity)
        internal
    {
        if (quote == WETH9) {
            bytes[] memory calls = new bytes[](2);
            uint256 callsIdx;
            if (collateral > 0) {
                vm.deal(trader, uint256(collateral));
                calls[callsIdx++] = abi.encodeWithSelector(contango.wrapETH.selector);
            }

            calls[callsIdx++] = abi.encodeWithSelector(
                contango.modifyCollateral.selector,
                positionId,
                collateral,
                limitCost,
                address(contango),
                lendingLiquidity
            );
            if (collateral < 0) {
                calls[callsIdx] = abi.encodeWithSelector(contango.unwrapWETH.selector, trader);
            }

            vm.prank(trader);
            contango.batch{value: collateral > 0 ? uint256(collateral) : 0}(calls);
        } else {
            if (collateral > 0) {
                dealAndApprove({
                    token: address(quote),
                    to: trader,
                    amount: uint256(collateral),
                    approveTo: address(contango)
                });
            }
            vm.prank(trader);
            contango.modifyCollateral(positionId, collateral, limitCost, trader, lendingLiquidity);
        }

        _afterModifyCollateral(positionId);
    }

    function _deliverPosition(PositionId positionId) internal {
        address owner = positionNFT.ownerOf(PositionId.unwrap(positionId));
        uint256 traderBalance = quoteBalance(owner);
        uint256 treasuryBalance = quote.balanceOf(treasury);
        Position memory position = contango.position(positionId);
        uint256 underlyingBorrowing = _underlyingBalances(positionId).borrowing;

        uint256 deliveryCost = contangoQuoter.deliveryCostForPosition(positionId);
        assertEqDecimal(deliveryCost, underlyingBorrowing + position.protocolFees, quoteDecimals, "deliveryCost");
        dealAndApprove(address(quote), owner, deliveryCost, address(contango));

        vm.recordLogs();
        vm.prank(owner);
        contango.deliver(positionId, owner, owner);

        assertPositionWasClosedInternal(positionId);

        Vm.Log memory log =
            _updateRecordedLogs().first("PositionDelivered(bytes32,address,uint256,address,uint256,uint256,uint256)");
        assertEq(log.topics[1], Symbol.unwrap(symbol));
        assertEq(uint256(log.topics[2]), uint160(address(owner)));
        assertEq(uint256(log.topics[3]), PositionId.unwrap(positionId));

        (address to, uint256 deliveredQuantity, uint256 _deliveryCost, uint256 totalFees) =
            abi.decode(log.data, (address, uint256, uint256, uint256));

        assertEq(to, owner, "to");
        assertEqDecimal(deliveredQuantity, position.openQuantity, baseDecimals, "deliveredQuantity");
        // We don't charge a fee on delivery
        assertEqDecimal(totalFees, position.protocolFees, quoteDecimals, "totalFees");
        assertEqDecimal(_deliveryCost, underlyingBorrowing, quoteDecimals, "deliveryCost 2 ");

        assertEqDecimal(quoteBalance(address(contango)), 0, quoteDecimals, "contango balance");
        assertEqDecimal(quote.balanceOf(treasury), treasuryBalance + totalFees, quoteDecimals, "treasury balance");
        assertEqDecimal(quoteBalance(owner), traderBalance, quoteDecimals, "owner quote balance");
        assertEqDecimal(base.balanceOf(owner), position.openQuantity, quoteDecimals, "owner base balance");
    }

    // position assertions

    function assertPositionWasClosed(PositionId positionId) internal virtual {
        Position memory position = contangoView.position(positionId);
        assertEqDecimal(position.openQuantity, 0, baseDecimals, "openQuantity");
        assertEqDecimal(position.openCost, 0, quoteDecimals, "openCost");
        assertEqDecimal(position.collateral, 0, quoteDecimals, "collateral");
        assertEqDecimal(position.protocolFees, 0, quoteDecimals, "protocolFees");
        assertEq(position.maturity, 0, "maturity");
        assertEq(address(position.feeModel), address(0));

        if (feeModel == IFeeModel(address(0))) {
            assertEqDecimal(quote.balanceOf(treasury), 0, quoteDecimals, "treasury balance");
        } else {
            assertGtDecimal(quote.balanceOf(treasury), 0, quoteDecimals, "treasury balance");
        }

        assertEqDecimal(address(contango).balance, 0, quoteDecimals, "contango ETH balance");
        assertApproxEqAbsDecimal(quote.balanceOf(address(contango)), 0, maxQuoteDust, quoteDecimals, "contango balance");
    }

    function assertPositionWasClosedInternal(PositionId positionId) internal virtual {
        assertPositionWasClosed(positionId);

        UnderlyingBalances memory underlyingBalances = _underlyingBalances(positionId);
        assertEqDecimal(underlyingBalances.borrowing, 0, quoteDecimals, "underlying borrowing");
        assertEqDecimal(underlyingBalances.lending, 0, baseDecimals, "underlying lending");
    }

    function _assertLeverage(ModifyCostResult memory result, uint256 expected, uint256 tolerance) internal {
        return _assertLeverage(result.underlyingCollateral, result.underlyingDebt, expected, tolerance);
    }

    function _assertLeverage(uint256 underlyingCollateral, uint256 underlyingDebt, uint256 expected, uint256 tolerance)
        internal
    {
        uint256 multiplier = 10 ** (quoteDecimals);
        uint256 margin = (underlyingCollateral - underlyingDebt) * multiplier / underlyingCollateral;
        uint256 leverage = 1e18 * multiplier / margin;
        assertApproxEqAbsDecimal(leverage, expected, tolerance, 18, "leverage");
    }

    function _updateRecordedLogs() private returns (Vm.Log[] memory logs) {
        delete recordedLogs;
        logs = vm.getRecordedLogs();
        for (uint256 i = 0; i < logs.length; i++) {
            recordedLogs.push(logs[i]);
        }
    }
}
