//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./PositionFixtures.sol";

abstract contract LiquidationFixtures is PositionFixtures {
    using Math for uint256;
    using TestUtils for *;

    address internal immutable liquidator = address(0xbadb01);

    uint256 internal realisedPnlApprox;

    function _verifyLiquidationEvent(
        PositionId positionId,
        Position memory position,
        uint256 liquidatorCut,
        uint256 liquidatorDeposit
    ) internal {
        Vm.Log memory log =
            vm.getRecordedLogs().first("PositionLiquidated(bytes32,address,uint256,uint256,uint256,int256,int256)");
        assertEq(log.topics[1], Symbol.unwrap(symbol));
        assertEq(uint256(log.topics[2]), uint160(address(trader)));
        assertEq(uint256(log.topics[3]), PositionId.unwrap(positionId));
        (uint256 openQuantity, uint256 openCost, int256 collateral, int256 realisedPnL) =
            abi.decode(log.data, (uint256, uint256, int256, int256));
        assertEqDecimal(openQuantity, position.openQuantity - liquidatorCut, baseDecimals, "openQuantity");
        uint256 closedCost = (liquidatorCut * position.openCost).ceilDiv(position.openQuantity);
        assertEqDecimal(openCost, position.openCost - closedCost, quoteDecimals, "openCost");
        assertApproxEqAbsDecimal(
            realisedPnL, int256(liquidatorDeposit) - int256(closedCost), realisedPnlApprox, quoteDecimals, "realisedPnL"
        );
        assertEqDecimal(collateral, position.collateral + realisedPnL, quoteDecimals, "collateral");

        Position memory positionAfter = contango.position(positionId);
        assertEqDecimal(positionAfter.openQuantity, openQuantity, baseDecimals, "openQuantity");
        assertEqDecimal(positionAfter.openCost, openCost, quoteDecimals, "openCost");
        assertEqDecimal(positionAfter.collateral, collateral, quoteDecimals, "collateral");
        // We don't charge a fee on liquidation
        assertEqDecimal(positionAfter.protocolFees, position.protocolFees, quoteDecimals, "protocolFees");
    }
}
