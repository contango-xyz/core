//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../PositionFixtures.sol";
import "./StubFixtures.sol";

/// @dev relies on StubETHUSDCFixtures._configureStubs()
abstract contract CollateralManagementETHUSDCFixtures is PositionFixtures {
    using TestUtils for *;

    function testAddCollateral() public {
        // Open position
        (PositionId positionId, ModifyCostResult memory result) = _openPosition(2 ether, 1.835293426713062884e18);

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2 ether, quoteDecimals, "open openQuantity");
        assertApproxEqAbsDecimal(
            position.openCost, 1402.134078e6, costBuffer + leverageBuffer, quoteDecimals, "open openCost"
        );
        assertEqDecimal(position.protocolFees, 2.103202e6, quoteDecimals, "open protocolFees");
        assertApproxEqAbsDecimal(position.collateral, 797.896798e6, leverageBuffer, quoteDecimals, "open collateral");

        _assertNoBalances(trader, "trader");

        // Add collateral
        int256 depositCollateral = 100e6;
        result = _modifyCollateral(positionId, depositCollateral);
        assertEqDecimal(result.collateralUsed, depositCollateral, quoteDecimals, "add collateral result.collateralUsed");
        assertEqDecimal(result.cost, 10.497237e6, quoteDecimals, "add collateral result.cost");
        assertEqDecimal(result.debtDelta, -110.497237e6, quoteDecimals, "add collateral result.debtDelta");

        position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2 ether, quoteDecimals, "add collateral openQuantity");

        // open cost - cost
        // 1402.134078 - 10.497237 = 1391.636842
        assertApproxEqAbsDecimal(position.openCost, 1391.636874e6, costBuffer, quoteDecimals, "add collateral openCost");

        // 0.15% debtDelta
        // 110.497237 * 0.0015 = 0.165746 fees (rounded up)
        // open fees + fees
        // 2.103202 + 0.165746 = 2.268948 (rounded up)
        assertEqDecimal(position.protocolFees, 2.268948e6, quoteDecimals, "add collateral protocolFees");

        // open collateral + collateral - fee
        // 797.896798 + 100 - 0.165746 = 897.731052
        assertApproxEqAbsDecimal(
            position.collateral, 897.730821e6, leverageBuffer, quoteDecimals, "add collateral collateral"
        );

        {
            Vm.Log memory _log = recordedLogs.first("CollateralAdded(bytes32,address,uint256,uint256,uint256)");
            assertEq(_log.topics[1], Symbol.unwrap(symbol));
            assertEq(uint256(_log.topics[2]), uint160(address(trader)));
            assertEq(uint256(_log.topics[3]), PositionId.unwrap(positionId));

            (uint256 amount, uint256 cost) = abi.decode(_log.data, (uint256, uint256));

            assertEqDecimal(amount, uint256(depositCollateral), quoteDecimals, "amount");
            assertEqDecimal(cost, uint256(-result.debtDelta), quoteDecimals, "cost");
        }

        _assertNoBalances(trader, "trader");
    }

    function testRemoveCollateral() public {
        // Open position
        (PositionId positionId, ModifyCostResult memory result) = _openPosition(2 ether, 1.835293426713062884e18);

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2 ether, quoteDecimals, "open openQuantity");
        assertApproxEqAbsDecimal(
            position.openCost, 1402.134079e6, costBuffer + leverageBuffer, quoteDecimals, "open openCost"
        );
        assertEqDecimal(position.protocolFees, 2.103202e6, quoteDecimals, "open protocolFees");
        assertApproxEqAbsDecimal(position.collateral, 797.896798e6, leverageBuffer, quoteDecimals, "open collateral");

        _assertNoBalances(trader, "trader");

        // Remove collateral
        int256 withdrawCollateral = -100e6;
        result = _modifyCollateral(positionId, withdrawCollateral);
        assertEqDecimal(
            result.collateralUsed, withdrawCollateral, quoteDecimals, "remove collateral result.collateralUsed"
        );
        assertApproxEqAbsDecimal(result.cost, -11.731843e6, costBuffer, quoteDecimals, "remove collateral result.cost");
        assertApproxEqAbsDecimal(
            result.debtDelta, 111.731843e6, costBuffer, quoteDecimals, "remove collateral result.debtDelta"
        );

        position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2 ether, quoteDecimals, "remove collateral openQuantity");

        // open cost - cost
        // 1402.134079 + 11.731843 = 1413.865922
        assertApproxEqAbsDecimal(
            position.openCost, 1413.865922e6, costBuffer + leverageBuffer, quoteDecimals, "remove collateral openCost"
        );

        // 0.15% debtDelta
        // 111.731843 * 0.0015 = 0.167598 fees (rounded up)
        // open fees + fees
        // 2.103202 + 0.167598 = 2.2708 (rounded up)
        assertEqDecimal(position.protocolFees, 2.2708e6, quoteDecimals, "remove collateral protocolFees");

        // open collateral + collateral - fee
        // 797.896798 - 100 - 0.167598 = 697.7292
        assertApproxEqAbsDecimal(
            position.collateral, 697.7292e6, leverageBuffer, quoteDecimals, "remove collateral collateral"
        );

        {
            Vm.Log memory _log = recordedLogs.first("CollateralRemoved(bytes32,address,uint256,uint256,uint256)");
            assertEq(_log.topics[1], Symbol.unwrap(symbol));
            assertEq(uint256(_log.topics[2]), uint160(address(trader)));
            assertEq(uint256(_log.topics[3]), PositionId.unwrap(positionId));

            (uint256 amount, uint256 cost) = abi.decode(_log.data, (uint256, uint256));

            assertEqDecimal(amount, uint256(-withdrawCollateral), quoteDecimals, "amount");
            assertEqDecimal(cost, uint256(result.debtDelta), quoteDecimals, "cost");
        }

        assertEqDecimal(quote.balanceOf(trader), 100e6, quoteDecimals, "trader USDC balance");
    }
}
