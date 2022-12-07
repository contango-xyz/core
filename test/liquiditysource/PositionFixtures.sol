//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";

import {IFeeModel} from "src/interfaces/IFeeModel.sol";

import "src/libraries/DataTypes.sol";

import {TestUtils} from "../utils/TestUtils.sol";
import "../ContangoTestBase.sol";

// solhint-disable func-name-mixedcase
abstract contract PositionFixtures is ContangoTestBase {
    using Math for uint256;
    using SafeCast for int256;
    using SignedMath for int256;
    using TestUtils for *;

    Instrument internal instrument;

    uint256 internal quoteDecimals;
    uint256 internal baseDecimals;

    Symbol internal symbol;

    constructor(Symbol _symbol) {
        symbol = _symbol;
    }

    // solhint-disable-next-line no-empty-blocks
    function _afterOpenPosition() internal virtual {}

    // solhint-disable-next-line no-empty-blocks
    function _afterModifyPosition() internal virtual {}

    // solhint-disable-next-line no-empty-blocks
    function _afterModifyCollateral() internal virtual {}

    function _dealCollateral(uint256 collateral) internal {
        if (quote == WETH) {
            vm.deal(trader, collateral);
        } else {
            dealAndApprove(address(quote), trader, collateral, address(contango));
        }
    }

    function quoteBalance(address account) internal view returns (uint256) {
        return quote == WETH ? account.balance : quote.balanceOf(account);
    }

    function _openPosition(uint256 quantity) internal returns (PositionId positionId, ModifyCostResult memory result) {
        ModifyCostResult memory initialQuote =
            contangoQuoter.openingCostForPosition(OpeningCostParams(symbol, quantity, 0, collateralSlippage));

        // 10% over min
        return _openPosition(quantity, ((initialQuote.minCollateral * 1.1e6) / 1e6).toUint256());
    }

    function _openPosition(uint256 quantity, uint256 collateral)
        internal
        returns (PositionId positionId, ModifyCostResult memory result)
    {
        result =
            contangoQuoter.openingCostForPosition(OpeningCostParams(symbol, quantity, collateral, collateralSlippage));
        require(!result.insufficientLiquidity, "insufficientLiquidity");

        vm.recordLogs();
        positionId = _createPosition(quantity, result);

        {
            Position memory position = contango.position(positionId);
            assertEq(Symbol.unwrap(position.symbol), Symbol.unwrap(symbol), "position.symbol");
            assertEqDecimal(position.openQuantity, quantity, baseDecimals, "position.openQuantity");
            assertApproxEqAbsDecimal(position.openCost, result.cost.abs(), 1e12, quoteDecimals, "position.openCost");
            assertApproxEqAbsDecimal(position.protocolFees, result.fee, 1e12, quoteDecimals, "position.protocolFees");
            assertEqDecimal(
                position.collateral,
                result.collateralUsed - int256(position.protocolFees),
                quoteDecimals,
                "position.collateral"
            );

            Vm.Log memory log = vm.getRecordedLogs().first(
                "PositionUpserted(bytes32,address,uint256,uint256,uint256,int256,uint256,uint256,int256)"
            );
            assertEq(log.topics[1], Symbol.unwrap(symbol));
            assertEq(uint256(log.topics[2]), uint160(address(trader)));
            assertEq(uint256(log.topics[3]), PositionId.unwrap(positionId));

            (
                uint256 openQuantity,
                uint256 openCost,
                int256 _collateral,
                uint256 totalFees,
                uint256 txFees,
                int256 realisedPnL
            ) = abi.decode(log.data, (uint256, uint256, int256, uint256, uint256, int256));

            assertEqDecimal(openQuantity, quantity, baseDecimals, "PositionUpserted.openQuantity");
            assertApproxEqAbsDecimal(openCost, result.cost.abs(), 1e12, quoteDecimals, "PositionUpserted.openCost");
            assertApproxEqAbsDecimal(txFees, result.fee, 1e12, quoteDecimals, "PositionUpserted.txFees");
            assertApproxEqAbsDecimal(totalFees, result.fee, 1e12, quoteDecimals, "PositionUpserted.totalFees");
            assertEqDecimal(realisedPnL, 0, quoteDecimals, "PositionUpserted.realisedPnL");
            assertEqDecimal(
                _collateral, result.collateralUsed - int256(txFees), quoteDecimals, "PositionUpserted.collateral"
            );
        }

        assertEqDecimal(quoteBalance(address(contango)), 0, quoteDecimals, "contango balance");
        assertEqDecimal(quote.balanceOf(treasury), 0, quoteDecimals, "treasury balance");
        assertEqDecimal(quoteBalance(trader), 0, quoteDecimals, "trader balance");

        _afterOpenPosition();
    }

    function _createPosition(uint256 quantity, ModifyCostResult memory result)
        internal
        returns (PositionId positionId)
    {
        if (quote == WETH) {
            vm.deal(trader, result.collateralUsed.toUint256());

            bytes[] memory calls = new bytes[](2);
            calls[0] = abi.encodeWithSelector(contango.wrapETH.selector);
            calls[1] = abi.encodeWithSelector(
                contango.createPosition.selector,
                symbol,
                trader,
                quantity,
                result.cost.slippage(),
                result.collateralUsed.toUint256(),
                address(contango),
                result.baseLendingLiquidity
            );

            vm.prank(trader);
            bytes[] memory results = contango.batch{value: result.collateralUsed.toUint256()}(calls);
            positionId = abi.decode(results[1], (PositionId));
        } else {
            dealAndApprove({
                token: address(quote),
                to: trader,
                amount: result.collateralUsed.toUint256(),
                approveTo: address(contango)
            });
            vm.prank(trader);
            positionId = contango.createPosition(
                symbol,
                trader,
                quantity,
                result.cost.slippage(),
                result.collateralUsed.toUint256(),
                trader,
                result.baseLendingLiquidity
            );
        }
    }

    function _closePosition(PositionId positionId) internal {
        uint256 traderBalance = quoteBalance(trader);
        uint256 treasuryBalance = quote.balanceOf(treasury);
        Position memory position = contango.position(positionId);
        int256 closeQty = -int256(position.openQuantity);

        ModifyCostResult memory result =
            contangoQuoter.modifyCostForPosition(ModifyCostParams(positionId, closeQty, 0, collateralSlippage));
        require(!result.insufficientLiquidity, "insufficientLiquidity");

        vm.recordLogs();
        _modifyPosition(positionId, closeQty, result);

        assertPositionWasClosed(positionId);

        Vm.Log memory log = vm.getRecordedLogs().first(
            "PositionClosed(bytes32,address,uint256,uint256,uint256,int256,uint256,uint256,int256)"
        );
        assertEq(log.topics[1], Symbol.unwrap(symbol));
        assertEq(uint256(log.topics[2]), uint160(address(trader)));
        assertEq(uint256(log.topics[3]), PositionId.unwrap(positionId));

        (
            uint256 closedQuantity,
            uint256 closedCost,
            int256 collateral,
            uint256 totalFees,
            uint256 txFees,
            int256 realisedPnL
        ) = abi.decode(log.data, (uint256, uint256, int256, uint256, uint256, int256));

        assertEqDecimal(closedQuantity, position.openQuantity, baseDecimals, "closedQuantity");
        assertEqDecimal(closedCost, position.openCost, quoteDecimals, "closedCost");
        assertEqDecimal(txFees, result.fee, quoteDecimals, "txFees");
        assertEqDecimal(totalFees, position.protocolFees + result.fee, quoteDecimals, "totalFees");
        assertApproxEqAbsDecimal(realisedPnL, result.cost - int256(closedCost), 1, quoteDecimals, "realisedPnL");
        assertEqDecimal(collateral, position.collateral - int256(txFees) + realisedPnL, quoteDecimals, "collateral");

        assertEqDecimal(quoteBalance(address(contango)), 0, quoteDecimals, "contango balance");
        assertEqDecimal(quoteBalance(trader), traderBalance + uint256(collateral), quoteDecimals, "trader balance");
        // TODO alfredo - limit how much dust we accept on the assertion?
        // minimum treasury balance + dust sweeping (if any)
        assertGeDecimal(quote.balanceOf(treasury), treasuryBalance + totalFees, quoteDecimals, "treasury balance");
    }

    function _modifyPosition(PositionId positionId, int256 quantity, int256 collateral)
        internal
        returns (ModifyCostResult memory result)
    {
        uint256 traderBalance = quoteBalance(trader);
        uint256 treasuryBalance = quote.balanceOf(treasury);

        Position memory position = contango.position(positionId);
        result =
            contangoQuoter.modifyCostForPosition(ModifyCostParams(positionId, quantity, collateral, collateralSlippage));
        require(!result.insufficientLiquidity, "insufficientLiquidity");

        vm.recordLogs();
        _modifyPosition(positionId, quantity, result);

        {
            Vm.Log memory log = vm.getRecordedLogs().first(
                "PositionUpserted(bytes32,address,uint256,uint256,uint256,int256,uint256,uint256,int256)"
            );
            assertEq(log.topics[1], Symbol.unwrap(symbol));
            assertEq(uint256(log.topics[2]), uint160(address(trader)));
            assertEq(uint256(log.topics[3]), PositionId.unwrap(positionId));

            int256 _quantity = quantity;

            (
                uint256 openQuantity,
                uint256 openCost,
                int256 _collateral,
                uint256 totalFees,
                uint256 txFees,
                int256 realisedPnL
            ) = abi.decode(log.data, (uint256, uint256, int256, uint256, uint256, int256));

            if (quantity > 0) {
                assertEqDecimal(realisedPnL, 0, quoteDecimals, "realisedPnL");
                assertApproxEqAbsDecimal(
                    openCost, position.openCost + result.cost.abs(), 1e12, quoteDecimals, "openCost"
                );
            } else {
                uint256 closedCost = (_quantity.abs() * position.openCost).ceilDiv(position.openQuantity);
                assertEqDecimal(openCost, position.openCost - closedCost, quoteDecimals, "openCost");
                assertApproxEqAbsDecimal(realisedPnL, result.cost - int256(closedCost), 1, quoteDecimals, "realisedPnL");
            }
            assertEqDecimal(
                openQuantity, uint256(int256(position.openQuantity) + _quantity), baseDecimals, "openQuantity"
            );
            assertEqDecimal(txFees, result.fee, quoteDecimals, "txFees");
            assertEqDecimal(totalFees, position.protocolFees + result.fee, quoteDecimals, "totalFees");
            assertEqDecimal(
                _collateral,
                position.collateral - int256(txFees) + realisedPnL + result.collateralUsed,
                quoteDecimals,
                "collateral"
            );
        }

        assertEqDecimal(quoteBalance(address(contango)), 0, quoteDecimals, "contango balance");
        assertEqDecimal(quote.balanceOf(treasury), treasuryBalance, quoteDecimals, "treasury balance");
        assertEqDecimal(quoteBalance(trader), traderBalance, quoteDecimals, "trader balance");
    }

    function _modifyPosition(PositionId positionId, int256 quantity, ModifyCostResult memory result) internal {
        address payerOrReceiver = trader;
        uint256 callNo = 1; // Call to modifyPosition
        if (result.needsBatchedCall) {
            callNo++; // Extra call to modifyCollateral
        }
        if (quote == WETH) {
            payerOrReceiver = address(contango);
            callNo++; // Extra call to unwrapWETH (we always unwrap in case we sent too much)
            if (result.collateralUsed > 0) {
                callNo++; // Extra call to wrapWETH
            }
        }

        bytes[] memory calls = new bytes[](callNo);
        uint256 callIdx;

        if (quote == WETH && result.collateralUsed > 0) {
            calls[callIdx++] = abi.encodeWithSelector(contango.wrapETH.selector);
        }

        if (result.needsBatchedCall) {
            uint256 modifyPositionCost = (result.cost + result.financingCost).slippage();
            int256 modifyCollateralAmount = result.financingCost - result.debtDelta;
            int256 modifyPositionCollateralAmount = result.collateralUsed + modifyCollateralAmount;

            calls[callIdx++] = abi.encodeWithSelector(
                contango.modifyPosition.selector,
                positionId,
                quantity,
                modifyPositionCost,
                modifyPositionCollateralAmount,
                payerOrReceiver,
                quantity > 0 ? result.baseLendingLiquidity : result.quoteLendingLiquidity
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
                quantity > 0 ? result.baseLendingLiquidity : result.quoteLendingLiquidity
            );
        }

        if (quote == WETH) {
            calls[callIdx++] = abi.encodeWithSelector(contango.unwrapWETH.selector, trader);
        }

        if (result.collateralUsed > 0) {
            _dealCollateral(result.collateralUsed.toUint256());
        }

        vm.prank(trader);
        contango.batch{value: result.collateralUsed > 0 && quote == WETH ? result.collateralUsed.toUint256() : 0}(calls);

        _afterModifyPosition();
    }

    function _modifyCollateral(PositionId positionId, int256 collateral) internal {
        uint256 traderBalance = quoteBalance(trader);
        uint256 treasuryBalance = quote.balanceOf(treasury);
        Position memory position = contango.position(positionId);

        ModifyCostResult memory result = contangoQuoter.modifyCostForPosition(
            ModifyCostParams({
                positionId: positionId,
                quantity: 0,
                collateral: collateral,
                collateralSlippage: collateralSlippage
            })
        );
        require(!result.insufficientLiquidity, "insufficientLiquidity");

        vm.recordLogs();
        _modifyCollateral(
            positionId, result.collateralUsed, result.debtDelta.abs(), collateral > 0 ? result.quoteLendingLiquidity : 0
        );

        {
            Vm.Log memory log = vm.getRecordedLogs().first(
                "PositionUpserted(bytes32,address,uint256,uint256,uint256,int256,uint256,uint256,int256)"
            );
            assertEq(log.topics[1], Symbol.unwrap(symbol));
            assertEq(uint256(log.topics[2]), uint160(address(trader)));
            assertEq(uint256(log.topics[3]), PositionId.unwrap(positionId));

            (
                uint256 openQuantity,
                uint256 openCost,
                int256 _collateral,
                uint256 totalFees,
                uint256 txFees,
                int256 realisedPnL
            ) = abi.decode(log.data, (uint256, uint256, int256, uint256, uint256, int256));

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

        assertEqDecimal(quoteBalance(address(contango)), 0, quoteDecimals, "contango balance");
        // TODO alfredo - is it ok to just accept treasury might go up due to dust sweeping?
        assertGeDecimal(quote.balanceOf(treasury), treasuryBalance, quoteDecimals, "treasury balance");
        assertApproxEqAbsDecimal(
            quoteBalance(trader),
            traderBalance + uint256(result.collateralUsed < 0 ? result.collateralUsed.abs() : 0),
            2,
            quoteDecimals,
            "trader balance"
        );
    }

    function _modifyCollateral(PositionId positionId, int256 collateral, uint256 limitCost, uint256 lendingLiquidity)
        internal
    {
        if (quote == WETH) {
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

        _afterModifyCollateral();
    }

    // position assertions

    function assertPositionWasClosed(PositionId positionId) internal virtual returns (Position memory position) {
        position = contangoView.position(positionId);
        assertEq(position.openQuantity, 0, "openQuantity");
        assertEq(position.openCost, 0, "openCost");
        assertEq(position.collateral, 0, "collateral");
        assertEq(position.protocolFees, 0, "protocolFees");
        assertEq(position.maturity, 0, "maturity");
        assertEq(address(position.feeModel), address(0));

        if (feeModel == IFeeModel(address(0))) {
            assertEq(quote.balanceOf(treasury), 0, "treasury balance");
        } else {
            assertGt(quote.balanceOf(treasury), 0, "treasury balance");
        }
        assertEq(quote.balanceOf(address(contangoView)), 0, "contango balance");
    }
}
