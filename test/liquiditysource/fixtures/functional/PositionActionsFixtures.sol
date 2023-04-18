//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../PositionFixtures.sol";
import "./StubFixtures.sol";

/// @dev relies on StubETHUSDCFixtures._configureStubs()
abstract contract PositionActionsETHUSDCFixtures is PriceStubFixtures, PositionFixtures {
    using SafeCast for int256;
    using SignedMath for int256;
    using TestUtils for *;

    function _assertUnderlyingBalances(PositionId positionId, uint256 lending, uint256 borrowing) internal virtual;

    function _expectAboveMaxCollateralRevert() internal virtual;

    function _expectExcessiveDebtBurnRevert() internal virtual;

    function testOpen() public {
        (PositionId positionId, ModifyCostResult memory result) = _openPosition(2 ether, 1.835293426713062884e18);
        assertApproxEqAbsDecimal(result.collateralUsed, 800e6, 300, quoteDecimals, "open result.collateralUsed");
        assertEqDecimal(result.fee, 2.103202e6, quoteDecimals, "open result.fee");

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2 ether, baseDecimals, "openQuantity");
        assertEqDecimal(position.protocolFees, 2.103202e6, quoteDecimals, "protocolFees");
        // posted collateral - fees
        // 800 - 2.103202 = 797.896798
        assertApproxEqAbsDecimal(position.collateral, 797.896798e6, leverageBuffer, quoteDecimals, "collateral");

        {
            Vm.Log memory _log =
                recordedLogs.first("ContractBought(bytes32,address,uint256,uint256,uint256,uint256,uint256,int256)");
            assertEq(_log.topics[1], Symbol.unwrap(symbol));
            assertEq(uint256(_log.topics[2]), uint160(address(trader)));
            assertEq(uint256(_log.topics[3]), PositionId.unwrap(positionId));

            Fill memory fill = abi.decode(_log.data, (Fill));

            assertEqDecimal(fill.size, position.openQuantity, baseDecimals, "fill.size");
            assertEqDecimal(fill.cost, position.openCost, quoteDecimals, "fill.cost");
            assertEqDecimal(fill.collateral, result.collateralUsed, quoteDecimals, "fill.collateral");
            // 2 * 0.955 (ask rate) = 1.91 ETH
            assertApproxEqAbsDecimal(fill.hedgeSize, 1.91e18, maxBaseDust, baseDecimals, "fill.hedgeSize");
            // 1.91 * 701 = 1338.91 (total USDC needed)
            assertApproxEqAbsDecimal(fill.hedgeCost, 1338.91e6, costBuffer, quoteDecimals, "fill.hedgeCost");
        }

        _assertNoBalances(trader, "trader");
    }

    function testIncrease() public {
        // Open
        (PositionId positionId, ModifyCostResult memory result) = _openPosition(1 ether, 1.252768618647210334e18);

        _assertLeverage(result, 1.252768618647210334e18, 0);

        assertApproxEqAbsDecimal(
            result.cost, -683.469274e6, costBuffer + leverageBuffer, quoteDecimals, "open result.cost"
        );
        assertApproxEqAbsDecimal(
            result.collateralUsed, 550e6, leverageBuffer, quoteDecimals, "open result.collateralUsed"
        );
        assertEqDecimal(result.fee, 1.025204e6, quoteDecimals, "open result.fee");
        assertApproxEqAbsDecimal(
            result.underlyingDebt,
            133.469274e6,
            costBuffer + leverageBuffer,
            quoteDecimals,
            "open result.underlyingDebt"
        );

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 1 ether, baseDecimals, "open openQuantity");
        assertApproxEqAbsDecimal(
            position.openCost, 683.469274e6, costBuffer + leverageBuffer, quoteDecimals, "open openCost"
        );
        assertEqDecimal(position.protocolFees, 1.025204e6, quoteDecimals, "open protocolFees");
        // posted collateral - fees
        // 550 - 1.025204 = 548.974796
        assertApproxEqAbsDecimal(position.collateral, 548.974796e6, leverageBuffer, quoteDecimals, "open collateral");

        _assertNoBalances(trader, "trader");

        // Increase
        uint256 increaseQuantity = 0.5 ether;
        result = _modifyPosition({positionId: positionId, quantity: int256(increaseQuantity), collateral: 0});
        assertApproxEqAbsDecimal(
            result.cost, -373.997207e6, costBuffer + leverageBuffer, quoteDecimals, "increase result.cost"
        );
        assertEqDecimal(result.fee, 0.560996e6, quoteDecimals, "increase result.fee");
        assertEqDecimal(result.collateralUsed, 0, quoteDecimals, "decrease collateralUsed");

        position = contango.position(positionId);
        // open quantity + increase quantity
        // 1 + 0.5 = 1.5
        assertEqDecimal(position.openQuantity, 1.5 ether, baseDecimals, "increase openQuantity");
        // open cost + increase cost
        // 683.469274 + 373.997207 = 1057.466481
        assertApproxEqAbsDecimal(
            position.openCost, 1057.466481e6, costBuffer * 2 + leverageBuffer, quoteDecimals, "increase openCost"
        );
        // open fees + increase fees
        // 1.025204 + 0.560996 = 1.5862
        assertEqDecimal(position.protocolFees, 1.5862e6, quoteDecimals, "increase protocolFees");
        // open collateral - increase fees
        // 548.974796 - 0.560996 = 548.4138
        assertApproxEqAbsDecimal(position.collateral, 548.4138e6, leverageBuffer, quoteDecimals, "increase collateral");

        {
            Vm.Log memory _log =
                recordedLogs.first("ContractBought(bytes32,address,uint256,uint256,uint256,uint256,uint256,int256)");
            assertEq(_log.topics[1], Symbol.unwrap(symbol));
            assertEq(uint256(_log.topics[2]), uint160(address(trader)));
            assertEq(uint256(_log.topics[3]), PositionId.unwrap(positionId));

            Fill memory fill = abi.decode(_log.data, (Fill));

            assertEqDecimal(fill.size, increaseQuantity, baseDecimals, "fill.size");
            assertApproxEqAbsDecimal(fill.cost, 373.997207e6, costBuffer, quoteDecimals, "fill.cost");
            assertEqDecimal(fill.collateral, 0, quoteDecimals, "fill.collateral");
            // 0.5 * 0.955 (ask rate) = 0.4775 ETH
            assertApproxEqAbsDecimal(fill.hedgeSize, 0.4775e18, maxBaseDust, baseDecimals, "fill.hedgeSize");
            // 0.4775 * 701 = 334.7275 (total USDC needed)
            assertApproxEqAbsDecimal(fill.hedgeCost, 334.7275e6, costBuffer, quoteDecimals, "fill.hedgeCost");
        }

        _assertNoBalances(trader, "trader");
    }

    function testDecrease() public {
        // Open
        (PositionId positionId, ModifyCostResult memory result) = _openPosition(2 ether, 1.835293426713062884e18);
        assertApproxEqAbsDecimal(
            result.cost, -1402.134079e6, costBuffer + leverageBuffer, quoteDecimals, "open result.cost"
        );
        assertApproxEqAbsDecimal(
            result.collateralUsed, 800e6, leverageBuffer, quoteDecimals, "open result.collateralUsed"
        );
        assertEqDecimal(result.fee, 2.103202e6, quoteDecimals, "open result.fee");
        assertApproxEqAbsDecimal(
            result.underlyingDebt,
            602.134079e6,
            costBuffer + leverageBuffer,
            quoteDecimals,
            "open result.underlyingDebt"
        );

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(
            position.openCost, 1402.134079e6, costBuffer + leverageBuffer, quoteDecimals, "openCost"
        );
        assertEqDecimal(position.protocolFees, 2.103202e6, quoteDecimals, "protocolFees");
        // posted collateral - fees
        // 800 - 2.103202 = 797.896798
        assertApproxEqAbsDecimal(position.collateral, 797.896798e6, leverageBuffer, quoteDecimals, "collateral");

        _assertNoBalances(trader, "trader");

        // Decrease
        uint256 decreaseQuantity = 0.5 ether;
        result = _modifyPosition({positionId: positionId, quantity: -int256(decreaseQuantity), collateral: 0});
        assertEqDecimal(result.cost, 364.947513e6, quoteDecimals, "decrease result.cost");
        assertEqDecimal(result.fee, 0.547422e6, quoteDecimals, "decrease result.fee");
        assertEqDecimal(result.collateralUsed, 0, quoteDecimals, "decrease collateralUsed");

        position = contango.position(positionId);
        // open quantity - decrease quantity
        // 2 - 0.5 = 1.5
        assertEqDecimal(position.openQuantity, 1.5 ether, baseDecimals, "decrease openQuantity");
        // (decrease quantity * open cost) / open quantity
        // (0.5 * 1402.134079) / 2 = 350.53351975 closed cost
        // open cost - closed cost
        // 1402.134079 - 350.53351975 = 1051.600559
        assertApproxEqAbsDecimal(
            position.openCost, 1051.600559e6, costBuffer + leverageBuffer, quoteDecimals, "decrease openCost"
        );
        assertEqDecimal(position.protocolFees, 2.650624e6, quoteDecimals, "decrease protocolFees");
        // collateral increases because we close as much debt as possible and don't remove any equity,
        // therefore recovering more cost than we close
        // open collateral - decrease fees + (cost - closedCost)
        // 797.896798 - 0.547422 + (364.947513 - 350.53351975) = 811.763369
        assertApproxEqAbsDecimal(
            position.collateral, 811.763369e6, costBuffer + leverageBuffer, quoteDecimals, "decrease collateral"
        );

        {
            Vm.Log memory _log =
                recordedLogs.first("ContractSold(bytes32,address,uint256,uint256,uint256,uint256,uint256,int256)");
            assertEq(_log.topics[1], Symbol.unwrap(symbol));
            assertEq(uint256(_log.topics[2]), uint160(address(trader)));
            assertEq(uint256(_log.topics[3]), PositionId.unwrap(positionId));

            Fill memory fill = abi.decode(_log.data, (Fill));

            assertEqDecimal(fill.size, decreaseQuantity, baseDecimals, "fill.size");
            assertApproxEqAbsDecimal(fill.cost, 364.947513e6, costBuffer, quoteDecimals, "fill.cost");
            assertEqDecimal(fill.collateral, 0, quoteDecimals, "fill.collateral");
            // 0.5 * 0.945 (bid rate) = 0.4725 ETH
            assertApproxEqAbsDecimal(fill.hedgeSize, 0.4725e18, 1, baseDecimals, "fill.hedgeSize");
            // 0.4725 * 699 = 330.2775 (total USDC received)
            assertEqDecimal(fill.hedgeCost, 330.2775e6, quoteDecimals, "fill.hedgeCost");
        }

        _assertNoBalances(trader, "trader");
    }

    function testClose() public {
        // Open
        (PositionId positionId, ModifyCostResult memory result) = _openPosition(2 ether, 1.835293426713062884e18);
        assertApproxEqAbsDecimal(
            result.cost, -1402.134079e6, costBuffer + leverageBuffer, quoteDecimals, "open result.cost"
        );
        assertApproxEqAbsDecimal(
            result.collateralUsed, 800e6, leverageBuffer, quoteDecimals, "open result.collateralUsed"
        );
        assertEqDecimal(result.fee, 2.103202e6, quoteDecimals, "open result.fee");
        assertApproxEqAbsDecimal(
            result.underlyingDebt,
            602.134079e6,
            costBuffer + leverageBuffer,
            quoteDecimals,
            "open result.underlyingDebt"
        );

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(
            position.openCost, 1402.134079e6, costBuffer + leverageBuffer, quoteDecimals, "openCost"
        );
        assertEqDecimal(position.protocolFees, 2.103202e6, quoteDecimals, "protocolFees");
        // posted collateral - fees
        // 800 - 2.103202 = 797.896798
        assertApproxEqAbsDecimal(position.collateral, 797.896798e6, leverageBuffer, quoteDecimals, "collateral");

        _assertNoBalances(trader, "trader");

        // Close
        result = _closePosition(positionId);
        assertApproxEqAbsDecimal(
            result.cost, 1378.312738e6, costBuffer + leverageBuffer, quoteDecimals, "close result.cost"
        );
        assertEqDecimal(result.fee, 2.06747e6, quoteDecimals, "close result.fee");

        // open cost + close cost
        // -1402.134079 + 1378.312738 = -23.821341 pnl
        // open collateral - close fees + pnl
        // 797.896798 - 2.06747 - 23.821341 = 772.007987
        assertApproxEqAbsDecimal(
            quote.balanceOf(trader), 772.007987e6, costBuffer + leverageBuffer, quoteDecimals, "trader quote balance"
        );

        {
            Vm.Log memory _log =
                recordedLogs.first("ContractSold(bytes32,address,uint256,uint256,uint256,uint256,uint256,int256)");
            assertEq(_log.topics[1], Symbol.unwrap(symbol));
            assertEq(uint256(_log.topics[2]), uint160(address(trader)));
            assertEq(uint256(_log.topics[3]), PositionId.unwrap(positionId));

            Fill memory fill = abi.decode(_log.data, (Fill));

            assertEqDecimal(fill.size, position.openQuantity, baseDecimals, "fill.size");
            assertApproxEqAbsDecimal(fill.cost, 1378.312738e6, costBuffer + leverageBuffer, quoteDecimals, "fill.cost");
            assertEqDecimal(fill.collateral, 0, quoteDecimals, "fill.collateral");
            // 2 * 0.945 (bid rate) = 1.89 ETH
            assertApproxEqAbsDecimal(fill.hedgeSize, 1.89e18, 1, baseDecimals, "fill.hedgeSize");
            // 1.89 * 699 = 1321.11 (total USDC received)
            assertEqDecimal(fill.hedgeCost, 1321.11e6, quoteDecimals, "fill.hedgeCost");
        }
    }

    function testIncreaseAndDeposit() public {
        // Open
        (PositionId positionId, ModifyCostResult memory result) = _openPosition(1 ether, 1.400994e18);

        assertApproxEqAbsDecimal(
            result.cost, -689.335196e6, costBuffer + leverageBuffer, quoteDecimals, "open result.cost"
        );
        assertApproxEqAbsDecimal(
            result.collateralUsed, 500e6, leverageBuffer, quoteDecimals, "open result.collateralUsed"
        );
        assertEqDecimal(result.fee, 1.034003e6, quoteDecimals, "open result.fee");
        assertApproxEqAbsDecimal(
            result.underlyingDebt,
            189.335196e6,
            costBuffer + leverageBuffer,
            quoteDecimals,
            "open result.underlyingDebt"
        );

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 1 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(
            position.openCost, 689.335196e6, costBuffer + leverageBuffer, quoteDecimals, "openCost"
        );
        assertEqDecimal(position.protocolFees, 1.034003e6, quoteDecimals, "protocolFees");
        // posted collateral - fees
        // 500 - 1.034003 = 498.965997
        assertApproxEqAbsDecimal(position.collateral, 498.965997e6, leverageBuffer, quoteDecimals, "collateral");

        _assertNoBalances(trader, "trader");

        // Increase
        uint256 increaseQuantity = 0.5 ether;
        int256 depositCollateral = 50e6;
        result =
            _modifyPosition({positionId: positionId, quantity: int256(increaseQuantity), collateral: depositCollateral});
        assertApproxEqAbsDecimal(result.cost, -368.131285e6, costBuffer, quoteDecimals, "increase result.cost");
        assertEqDecimal(result.fee, 0.552197e6, quoteDecimals, "increase result.fee");
        assertEqDecimal(result.collateralUsed, 50e6, quoteDecimals, "decrease collateralUsed");

        position = contango.position(positionId);
        // open quantity + increase quantity
        // 1 + 0.5 = 1.5
        assertEqDecimal(position.openQuantity, 1.5 ether, baseDecimals, "increase openQuantity");
        // open cost + increase cost
        // 689.335196 + 368.131285 = 1057.466481
        assertApproxEqAbsDecimal(
            position.openCost, 1057.466481e6, costBuffer * 2 + leverageBuffer, quoteDecimals, "increase openCost"
        );
        // open fee + increase fee
        // 1.034003 + 0.552197 = 1.5862
        assertEqDecimal(position.protocolFees, 1.5862e6, quoteDecimals, "increase protocolFees");
        // open collateral - increase fee + collateral posted
        // 498.965997 - 0.552197 + 50 = 548.4138
        assertApproxEqAbsDecimal(position.collateral, 548.4138e6, leverageBuffer, quoteDecimals, "increase collateral");

        {
            Vm.Log memory _log =
                recordedLogs.first("ContractBought(bytes32,address,uint256,uint256,uint256,uint256,uint256,int256)");
            assertEq(_log.topics[1], Symbol.unwrap(symbol));
            assertEq(uint256(_log.topics[2]), uint160(address(trader)));
            assertEq(uint256(_log.topics[3]), PositionId.unwrap(positionId));

            Fill memory fill = abi.decode(_log.data, (Fill));

            assertEqDecimal(fill.size, increaseQuantity, baseDecimals, "fill.size");
            assertApproxEqAbsDecimal(fill.cost, 368.131285e6, costBuffer, quoteDecimals, "fill.cost");
            assertEqDecimal(fill.collateral, depositCollateral, quoteDecimals, "fill.collateral");
            // 0.5 * 0.955 (ask rate) = 0.4775 ETH
            assertApproxEqAbsDecimal(fill.hedgeSize, 0.4775e18, maxBaseDust, baseDecimals, "fill.hedgeSize");
            // 0.4775 * 701 = 334.7275 (total USDC needed)
            assertApproxEqAbsDecimal(fill.hedgeCost, 334.7275e6, costBuffer, quoteDecimals, "fill.hedgeCost");
        }

        _assertNoBalances(trader, "trader");
    }

    function testIncreaseAndWithdraw() public {
        // Open
        (PositionId positionId, ModifyCostResult memory result) = _openPosition(1 ether, 1.400994e18);

        assertApproxEqAbsDecimal(
            result.cost, -689.335196e6, costBuffer + leverageBuffer, quoteDecimals, "open result.cost"
        );
        assertApproxEqAbsDecimal(
            result.collateralUsed, 500e6, leverageBuffer, quoteDecimals, "open result.collateralUsed"
        );
        assertEqDecimal(result.fee, 1.034003e6, quoteDecimals, "open result.fee");
        assertApproxEqAbsDecimal(
            result.underlyingDebt,
            189.335196e6,
            costBuffer + leverageBuffer,
            quoteDecimals,
            "open result.underlyingDebt"
        );

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 1 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(
            position.openCost, 689.335196e6, costBuffer + leverageBuffer, quoteDecimals, "openCost"
        );
        assertEqDecimal(position.protocolFees, 1.034003e6, quoteDecimals, "protocolFees");
        // posted collateral - fees
        // 500 - 1.034003 = 498.965997
        assertApproxEqAbsDecimal(position.collateral, 498.965997e6, leverageBuffer, quoteDecimals, "collateral");

        _assertNoBalances(trader, "trader");

        // Increase
        uint256 increaseQuantity = 0.5 ether;
        int256 withdrawCollateral = -50e6;
        result = _modifyPosition({
            positionId: positionId,
            quantity: int256(increaseQuantity),
            collateral: withdrawCollateral
        });
        assertApproxEqAbsDecimal(result.cost, -379.863129e6, costBuffer, quoteDecimals, "increase result.cost");
        assertEqDecimal(result.fee, 0.569795e6, quoteDecimals, "increase result.fee");
        assertEqDecimal(result.collateralUsed, withdrawCollateral, quoteDecimals, "increase result.collateralUsed");

        position = contango.position(positionId);
        // open quantity + increase quantity
        // 1 + 0.5 = 1.5
        assertEqDecimal(position.openQuantity, 1.5 ether, baseDecimals, "increase openQuantity");
        // open cost + increase cost
        // 689.335196 + 379.863128 = 1069.198324
        assertApproxEqAbsDecimal(position.openCost, 1069.198324e6, costBuffer * 2, quoteDecimals, "increase openCost");
        // open fee + increase fee
        // 1.034003 + 0.569795 = 1.603798
        assertEqDecimal(position.protocolFees, 1.603798e6, quoteDecimals, "increase protocolFees");
        // open collateral - increase fee - collateral withdrawn
        // 498.965997 - 0.569795 - 50 = 448.396202
        assertApproxEqAbsDecimal(
            position.collateral, 448.396202e6, leverageBuffer, quoteDecimals, "increase collateral"
        );

        {
            Vm.Log memory _log =
                recordedLogs.first("ContractBought(bytes32,address,uint256,uint256,uint256,uint256,uint256,int256)");
            assertEq(_log.topics[1], Symbol.unwrap(symbol));
            assertEq(uint256(_log.topics[2]), uint160(address(trader)));
            assertEq(uint256(_log.topics[3]), PositionId.unwrap(positionId));

            Fill memory fill = abi.decode(_log.data, (Fill));

            assertEqDecimal(fill.size, increaseQuantity, baseDecimals, "fill.size");
            assertApproxEqAbsDecimal(fill.cost, 379.863128e6, costBuffer, quoteDecimals, "fill.cost");
            assertEqDecimal(fill.collateral, withdrawCollateral, quoteDecimals, "fill.collateral");
            // 0.5 * 0.955 (ask rate) = 0.4775 ETH
            assertApproxEqAbsDecimal(fill.hedgeSize, 0.4775e18, maxBaseDust, baseDecimals, "fill.hedgeSize");
            // 0.4775 * 701 = 334.7275 (total USDC needed)
            assertApproxEqAbsDecimal(fill.hedgeCost, 334.7275e6, costBuffer, quoteDecimals, "fill.hedgeCost");
        }

        assertEqDecimal(quote.balanceOf(trader), uint256(-withdrawCollateral), quoteDecimals, "trader quote balance");
    }

    function testDecreaseAndDeposit() public {
        // Open
        (PositionId positionId, ModifyCostResult memory result) = _openPosition(2 ether, 1.835293426713062884e18);
        assertApproxEqAbsDecimal(
            result.cost, -1402.134079e6, costBuffer + leverageBuffer, quoteDecimals, "open result.cost"
        );
        assertApproxEqAbsDecimal(
            result.collateralUsed, 800e6, leverageBuffer, quoteDecimals, "open result.collateralUsed"
        );
        assertEqDecimal(result.fee, 2.103202e6, quoteDecimals, "open result.fee");
        assertApproxEqAbsDecimal(
            result.underlyingDebt,
            602.134079e6,
            costBuffer + leverageBuffer,
            quoteDecimals,
            "open result.underlyingDebt"
        );

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(
            position.openCost, 1402.134079e6, costBuffer + leverageBuffer, quoteDecimals, "openCost"
        );
        assertEqDecimal(position.protocolFees, 2.103202e6, quoteDecimals, "protocolFees");
        // posted collateral - fees
        // 800 - 2.103202 = 797.896798
        assertApproxEqAbsDecimal(position.collateral, 797.896798e6, leverageBuffer, quoteDecimals, "collateral");

        _assertNoBalances(trader, "trader");

        // Decrease
        uint256 decreaseQuantity = 0.5 ether;
        int256 depositCollateral = 50e6;
        result = _modifyPosition({
            positionId: positionId,
            quantity: -int256(decreaseQuantity),
            collateral: depositCollateral
        });
        assertEqDecimal(result.cost, 370.196132e6, quoteDecimals, "decrease result.cost");
        assertEqDecimal(result.fee, 0.555295e6, quoteDecimals, "decrease result.fee");
        assertEqDecimal(result.collateralUsed, 50e6, quoteDecimals, "decrease collateralUsed");

        position = contango.position(positionId);
        // open quantity - decrease quantity
        // 2 - 0.5 = 1.5
        assertEqDecimal(position.openQuantity, 1.5 ether, baseDecimals, "decrease openQuantity");
        // (decrease quantity * open cost) / open quantity
        // (0.5 * 1402.134079) / 2 = 350.53351975 closed cost
        // open cost - closed cost
        // 1402.134079 - 350.53351975 = 1051.600559
        assertApproxEqAbsDecimal(
            position.openCost, 1051.600559e6, costBuffer + leverageBuffer, quoteDecimals, "decrease openCost"
        );
        // open fees + decrease fees
        // 2.103202 + 0.555295 = 2.658497
        assertEqDecimal(position.protocolFees, 2.658497e6, quoteDecimals, "decrease protocolFees");
        // open collateral - decrease fees + (cost - closedCost) + deposited collateral
        // 797.896798 - 0.555295 + (370.196132 - 350.53351975) + 50 = 867.004115
        assertApproxEqAbsDecimal(
            position.collateral, 867.004115e6, costBuffer + leverageBuffer, quoteDecimals, "decrease collateral"
        );

        {
            Vm.Log memory _log =
                recordedLogs.first("ContractSold(bytes32,address,uint256,uint256,uint256,uint256,uint256,int256)");
            assertEq(_log.topics[1], Symbol.unwrap(symbol));
            assertEq(uint256(_log.topics[2]), uint160(address(trader)));
            assertEq(uint256(_log.topics[3]), PositionId.unwrap(positionId));

            Fill memory fill = abi.decode(_log.data, (Fill));

            assertEqDecimal(fill.size, decreaseQuantity, baseDecimals, "fill.size");
            assertApproxEqAbsDecimal(fill.cost, 370.196132e6, costBuffer, quoteDecimals, "fill.cost");
            assertEqDecimal(fill.collateral, depositCollateral, quoteDecimals, "fill.collateral");
            // 0.5 * 0.945 (bid rate) = 0.4725 ETH
            assertApproxEqAbsDecimal(fill.hedgeSize, 0.4725e18, maxBaseDust, baseDecimals, "fill.hedgeSize");
            // 0.4725 * 699 = 330.2775 (total USDC received)
            assertEqDecimal(fill.hedgeCost, 330.2775e6, quoteDecimals, "fill.hedgeCost");
        }

        _assertNoBalances(trader, "trader");
    }

    function testDecreaseAndWithdraw() public {
        // Open
        (PositionId positionId, ModifyCostResult memory result) = _openPosition(2 ether, 1.835293426713062884e18);
        assertApproxEqAbsDecimal(
            result.cost, -1402.134079e6, costBuffer + leverageBuffer, quoteDecimals, "open result.cost"
        );
        assertApproxEqAbsDecimal(
            result.collateralUsed, 800e6, leverageBuffer, quoteDecimals, "open result.collateralUsed"
        );
        assertEqDecimal(result.fee, 2.103202e6, quoteDecimals, "open result.fee");
        assertApproxEqAbsDecimal(
            result.underlyingDebt,
            602.134079e6,
            costBuffer + leverageBuffer,
            quoteDecimals,
            "open result.underlyingDebt"
        );

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(
            position.openCost, 1402.134079e6, costBuffer + leverageBuffer, quoteDecimals, "openCost"
        );
        assertEqDecimal(position.protocolFees, 2.103202e6, quoteDecimals, "protocolFees");
        // posted collateral - fees
        // 800 - 2.103202 = 797.896798
        assertApproxEqAbsDecimal(position.collateral, 797.896798e6, leverageBuffer, quoteDecimals, "collateral");

        _assertNoBalances(trader, "trader");

        // Decrease
        uint256 decreaseQuantity = 0.5 ether;
        int256 withdrawCollateral = -50e6;
        result = _modifyPosition({
            positionId: positionId,
            quantity: -int256(decreaseQuantity),
            collateral: withdrawCollateral
        });
        assertEqDecimal(result.cost, 359.698895e6, quoteDecimals, "decrease result.cost");
        assertEqDecimal(result.fee, 0.539549e6, quoteDecimals, "decrease result.fee");
        assertEqDecimal(result.collateralUsed, withdrawCollateral, quoteDecimals, "decrease result.collateralUsed");

        position = contango.position(positionId);
        // open quantity - decrease quantity
        // 2 - 0.5 = 1.5
        assertEqDecimal(position.openQuantity, 1.5 ether, baseDecimals, "decrease openQuantity");
        // (decrease quantity * open cost) / open quantity
        // (0.5 * 1402.134079) / 2 = 350.53351975 closed cost
        // open cost - closed cost
        // 1402.134079 - 350.53351975 = 1051.600559
        assertApproxEqAbsDecimal(
            position.openCost, 1051.600559e6, costBuffer + leverageBuffer, quoteDecimals, "decrease openCost"
        );
        // open fees + decrease fees
        // 2.103202 + 0.539549 = 2.642751
        assertEqDecimal(position.protocolFees, 2.642751e6, quoteDecimals, "decrease protocolFees");
        // open collateral - decrease fees + (cost - closedCost) - withdrawn collateral
        // 797.896798 - 0.539549 + (359.698895 - 350.53351975) - 50 = 756.522624
        assertApproxEqAbsDecimal(
            position.collateral, 756.522624e6, costBuffer + leverageBuffer, quoteDecimals, "decrease collateral"
        );

        {
            Vm.Log memory _log =
                recordedLogs.first("ContractSold(bytes32,address,uint256,uint256,uint256,uint256,uint256,int256)");
            assertEq(_log.topics[1], Symbol.unwrap(symbol));
            assertEq(uint256(_log.topics[2]), uint160(address(trader)));
            assertEq(uint256(_log.topics[3]), PositionId.unwrap(positionId));

            Fill memory fill = abi.decode(_log.data, (Fill));

            assertEqDecimal(fill.size, decreaseQuantity, baseDecimals, "fill.size");
            assertApproxEqAbsDecimal(fill.cost, 359.698895e6, costBuffer, quoteDecimals, "fill.cost");
            assertEqDecimal(fill.collateral, withdrawCollateral, quoteDecimals, "fill.collateral");
            // 0.5 * 0.945 (bid rate) = 0.4725 ETH
            assertApproxEqAbsDecimal(fill.hedgeSize, 0.4725e18, maxBaseDust, baseDecimals, "fill.hedgeSize");
            // 0.4725 * 699 = 330.2775 (total USDC received)
            assertEqDecimal(fill.hedgeCost, 330.2775e6, quoteDecimals, "fill.hedgeCost");
        }

        assertEqDecimal(quote.balanceOf(trader), 50e6, quoteDecimals, "trader quote balance");
    }

    function testOpenAndClosePositionSimple() public {
        (PositionId positionId,) = _openPosition(2 ether, 1.835293426713062884e18);

        _assertUnderlyingBalances({positionId: positionId, lending: 2 ether, borrowing: 602.134079e6});

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(
            position.openCost, 1402.134079e6, costBuffer + leverageBuffer, quoteDecimals, "openCost"
        );
        assertApproxEqAbsDecimal(
            position.collateral, 797.896798e6, costBuffer + leverageBuffer, quoteDecimals, "collateral"
        );

        _closePosition(positionId);
    }

    function testCanNotOpenRightAboveMaxCollateral() public {
        ModifyCostResult memory result = contangoQuoter.openingCostForPositionWithCollateral(
            OpeningCostParams(symbol, 2 ether, collateralSlippage, uniswapFee), uint256(type(int256).max)
        );

        uint256 collateral = result.collateralUsed.toUint256() + 2e6;
        dealAndApprove(address(quote), trader, collateral, address(contango));

        _expectAboveMaxCollateralRevert();

        vm.prank(trader);
        contango.createPosition(symbol, trader, 2 ether, 1420e6, collateral, trader, HIGH_LIQUIDITY, uniswapFee);
    }

    function testOpenReduceAndClosePosition() public {
        (PositionId positionId,) = _openPosition(2 ether, 1.835293426713062884e18);

        _assertUnderlyingBalances({positionId: positionId, lending: 2 ether, borrowing: 602.134079e6});

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(
            position.openCost, 1402.134079e6, costBuffer + leverageBuffer, quoteDecimals, "openCost"
        );
        assertApproxEqAbsDecimal(
            position.collateral, 797.896798e6, costBuffer + leverageBuffer, quoteDecimals, "collateral"
        );
        assertEqDecimal(position.protocolFees, 2.103202e6, quoteDecimals, "fees");

        // Reduce position
        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: -0.25 ether,
            collateralSlippage: collateralSlippage,
            uniswapFee: uniswapFee
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPositionWithCollateral(modifyParams, 0);
        assertEq(result.collateralUsed, 0, "collateralUsed");
        assertEqDecimal(result.cost, 182.473756e6, quoteDecimals, "cost");

        _modifyPosition(positionId, modifyParams.quantity, result);

        _assertUnderlyingBalances({positionId: positionId, lending: 1.75 ether, borrowing: 419.660323e6});

        position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 1.75 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(
            position.openCost, 1226.867319e6, costBuffer + leverageBuffer, quoteDecimals, "openCost"
        );
        assertApproxEqAbsDecimal(
            position.collateral, 804.830083e6, costBuffer + leverageBuffer, quoteDecimals, "collateral"
        );
        assertEqDecimal(position.protocolFees, 2.376913e6, quoteDecimals, "fees");

        _closePosition(positionId);
    }

    function testOpenReduceWithdrawAllCollateralAndClosePosition() public {
        (PositionId positionId,) = _openPosition(2 ether, 1.835293426713062884e18);

        Position memory positionBefore = contango.position(positionId);

        // Reduce position
        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: -0.25 ether,
            collateralSlippage: collateralSlippage,
            uniswapFee: uniswapFee
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPositionWithCollateral(modifyParams, 0);

        result = contangoQuoter.modifyCostForPositionWithCollateral(modifyParams, result.minCollateral);

        uint256 expectedCostAfterDecrease = ((positionBefore.openCost * 0.875e3) / 1e3) + uint256(result.financingCost);

        _modifyPosition(positionId, modifyParams.quantity, result);

        assertEqDecimal(quote.balanceOf(trader), uint256(-result.minCollateral), quoteDecimals, "trader balance");
        assertApproxEqAbsDecimal(quote.balanceOf(address(contango)), 0, costBuffer, quoteDecimals, "contango balance");

        // TODO alfredo - add a collateral ratio check here

        Position memory positionAfter = contango.position(positionId);
        assertEqDecimal(positionAfter.openCost, expectedCostAfterDecrease, quoteDecimals, "openCost");
        assertLtDecimal(positionAfter.collateral, positionBefore.collateral, quoteDecimals, "collateral");

        assertApproxEqAbsDecimal(
            positionAfter.protocolFees, positionBefore.protocolFees + result.fee, costBuffer, quoteDecimals, "fees"
        );

        _closePosition(positionId);
    }

    function testOpenReduceWithdrawSomeClosedFundsAndClosePosition() public {
        (PositionId positionId,) = _openPosition(2 ether, 1.835293426713062884e18);

        _assertUnderlyingBalances({positionId: positionId, lending: 2 ether, borrowing: 602.134079e6});

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(
            position.openCost, 1402.134079e6, costBuffer + leverageBuffer, quoteDecimals, "openCost"
        );
        assertApproxEqAbsDecimal(
            position.collateral, 797.896798e6, costBuffer + leverageBuffer, quoteDecimals, "collateral"
        );
        assertEqDecimal(position.protocolFees, 2.103202e6, quoteDecimals, "fees");

        // Reduce position
        int256 collateral = -100e6; // Withdraw some of the proceeds of the reduction
        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: -0.25 ether,
            collateralSlippage: collateralSlippage,
            uniswapFee: uniswapFee
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPositionWithCollateral(modifyParams, collateral);
        assertEqDecimal(result.spotCost, 174.75e6, quoteDecimals, "spotCost");
        assertEqDecimal(result.collateralUsed, -100e6, quoteDecimals, "collateralUsed");
        assertEqDecimal(result.cost, 171.976519e6, quoteDecimals, "cost");

        _modifyPosition(positionId, modifyParams.quantity, result);

        assertEqDecimal(quote.balanceOf(trader), uint256(-result.collateralUsed), quoteDecimals, "trader balance");
        assertApproxEqAbsDecimal(quote.balanceOf(address(contango)), 0, costBuffer, quoteDecimals, "contango balance");

        _assertUnderlyingBalances({positionId: positionId, lending: 1.75 ether, borrowing: 530.15756e6});

        position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 1.75 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(
            position.openCost, 1226.867319e6, costBuffer + leverageBuffer, quoteDecimals, "openCost"
        );
        assertApproxEqAbsDecimal(
            position.collateral, 694.348592e6, costBuffer + leverageBuffer, quoteDecimals, "collateral"
        );
        assertEqDecimal(position.protocolFees, 2.361167e6, quoteDecimals, "fees");

        _closePosition(positionId);
    }

    function testOpenReduceWithdrawAllCollateralAndProfitsAndClosePosition() public {
        (PositionId positionId,) = _openPosition(2 ether, 1.835293426713062884e18);

        _assertUnderlyingBalances({positionId: positionId, lending: 2 ether, borrowing: 602.134079e6});

        Position memory positionBefore = contango.position(positionId);

        _stubPrice(2000e6, 1e6);

        assertEq(quote.balanceOf(trader), 0, "trader balance");

        // Reduce position
        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: -0.25 ether,
            collateralSlippage: collateralSlippage,
            uniswapFee: uniswapFee
        });
        ModifyCostResult memory result =
            contangoQuoter.modifyCostForPositionWithCollateral(modifyParams, type(int256).min);

        uint256 expectedCostAfterDecrease = ((positionBefore.openCost * 0.875e3) / 1e3) + uint256(result.financingCost);

        _modifyPosition(positionId, modifyParams.quantity, result);

        assertEqDecimal(quote.balanceOf(trader), uint256(-result.collateralUsed), quoteDecimals, "trader balance");
        assertEqDecimal(quote.balanceOf(address(contango)), 0, quoteDecimals, "contango balance");

        // TODO alfredo - add a collateral ratio check here

        Position memory positionAfter = contango.position(positionId);
        assertEqDecimal(positionAfter.openCost, expectedCostAfterDecrease, quoteDecimals, "openCost (calculated)");

        _closePosition(positionId);
    }

    function testCanNotReducePositionWithoutWithdrawingExcessQuote() public {
        (PositionId positionId,) = _openPosition(2 ether, 1.835293426713062884e18);
        clearBalance(trader, quote);

        _assertUnderlyingBalances({positionId: positionId, lending: 2 ether, borrowing: 602.134079e6});

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(
            position.openCost, 1402.134079e6, costBuffer + leverageBuffer, quoteDecimals, "openCost"
        );
        assertApproxEqAbsDecimal(
            position.collateral, 797.896798e6, costBuffer + leverageBuffer, quoteDecimals, "collateral"
        );

        // Reduce position
        ModifyCostResult memory result = contangoQuoter.modifyCostForPositionWithCollateral(
            ModifyCostParams(positionId, -1.25 ether, collateralSlippage, uniswapFee), 0
        );
        assertLtDecimal(result.maxCollateral, 0, quoteDecimals, "excessQuote");

        _expectExcessiveDebtBurnRevert();

        vm.prank(trader);
        contango.modifyPosition(
            positionId, -1.25 ether, result.cost.abs(), 0, trader, result.quoteLendingLiquidity, uniswapFee
        );
    }

    function testOpenReduceDepositAndClosePosition() public {
        (PositionId positionId,) = _openPosition(2 ether, 1.835293426713062884e18);

        _assertUnderlyingBalances({positionId: positionId, lending: 2 ether, borrowing: 602.134079e6});

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(
            position.openCost, 1402.134079e6, costBuffer + leverageBuffer, quoteDecimals, "openCost"
        );
        assertApproxEqAbsDecimal(
            position.collateral, 797.896798e6, costBuffer + leverageBuffer, quoteDecimals, "collateral"
        );
        assertEqDecimal(position.protocolFees, 2.103202e6, quoteDecimals, "fees");

        // Reduce position
        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: -0.25 ether,
            collateralSlippage: collateralSlippage,
            uniswapFee: uniswapFee
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPositionWithCollateral(modifyParams, 100e6);
        assertEqDecimal(result.collateralUsed, 100e6, quoteDecimals, "collateralUsed");
        assertEqDecimal(result.cost, 192.970994e6, quoteDecimals, "cost");

        _modifyPosition(positionId, modifyParams.quantity, result);

        assertEqDecimal(quote.balanceOf(trader), 0, quoteDecimals, "trader balance");
        assertApproxEqAbsDecimal(quote.balanceOf(address(contango)), 0, costBuffer, quoteDecimals, "contango balance");

        _assertUnderlyingBalances({positionId: positionId, lending: 1.75 ether, borrowing: 309.163085e6});

        position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 1.75 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(
            position.openCost, 1226.867319e6, costBuffer + leverageBuffer, quoteDecimals, "openCost"
        );
        assertApproxEqAbsDecimal(
            position.collateral, 915.311575e6, costBuffer + leverageBuffer, quoteDecimals, "collateral"
        );
        assertEqDecimal(position.protocolFees, 2.392659e6, quoteDecimals, "fees");

        _closePosition(positionId);
    }

    // TODO alfredo - could only exist in the integration tests
    function testOpenReduceDepositMaxAndClosePosition() public {
        (PositionId positionId,) = _openPosition(2 ether, 1.835293426713062884e18);

        // Reduce position
        _modifyPosition({positionId: positionId, quantity: -0.25 ether, collateral: type(int256).max});

        assertEqDecimal(quote.balanceOf(trader), 0, quoteDecimals, "trader balance");
        assertApproxEqAbsDecimal(quote.balanceOf(address(contango)), 0, costBuffer, quoteDecimals, "contango balance");

        // TODO alfredo - add a collateral ratio check here

        _closePosition(positionId);
    }

    function testCanNotReduceAndDepositTooMuch() public {
        (PositionId positionId,) = _openPosition(2 ether, 1.835293426713062884e18);

        // Reduce position
        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: -0.25 ether,
            collateralSlippage: collateralSlippage,
            uniswapFee: uniswapFee
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPositionWithCollateral(modifyParams, 0);

        int256 collateral = result.maxCollateral + 1e6;
        dealAndApprove(address(quote), trader, uint256(collateral), address(contango));

        _expectAboveMaxCollateralRevert();

        vm.prank(trader);
        contango.modifyPosition(
            positionId,
            modifyParams.quantity,
            result.cost.abs(),
            collateral,
            trader,
            result.quoteLendingLiquidity,
            uniswapFee
        );
    }

    function testOpenIncreaseNoCollateralAndClosePosition() public {
        (PositionId positionId,) = _openPosition(2 ether, 1.835293426713062884e18);

        _assertUnderlyingBalances({positionId: positionId, lending: 2 ether, borrowing: 602.134079e6});

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(
            position.openCost, 1402.134079e6, costBuffer + leverageBuffer, quoteDecimals, "openCost"
        );
        assertApproxEqAbsDecimal(
            position.collateral, 797.896798e6, costBuffer + leverageBuffer, quoteDecimals, "collateral"
        );

        // Increase position
        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: 0.25 ether,
            collateralSlippage: collateralSlippage,
            uniswapFee: uniswapFee
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPositionWithCollateral(modifyParams, 0);

        assertEq(result.collateralUsed, 0, "collateralUsed");

        dealAndApprove(address(USDC), trader, uint256(result.collateralUsed), address(contango));
        _modifyPosition(positionId, modifyParams.quantity, result);

        costBufferMultiplier++;
        _assertUnderlyingBalances({positionId: positionId, lending: 2.25 ether, borrowing: 789.132683e6});

        position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2.25 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(
            position.openCost, 1589.132683e6, costBuffer * 2 + leverageBuffer, quoteDecimals, "openCost"
        );
        assertApproxEqAbsDecimal(
            position.collateral, 797.6163e6, costBuffer + leverageBuffer, quoteDecimals, "collateral"
        );

        _closePosition(positionId);
    }

    function testOpenIncreaseDepositAndClosePosition() public {
        (PositionId positionId,) = _openPosition(2 ether, 1.835293426713062884e18);

        _assertUnderlyingBalances({positionId: positionId, lending: 2 ether, borrowing: 602.134079e6});

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(
            position.openCost, 1402.134079e6, costBuffer + leverageBuffer, quoteDecimals, "openCost"
        );
        assertApproxEqAbsDecimal(
            position.collateral, 797.896798e6, costBuffer + leverageBuffer, quoteDecimals, "collateral"
        );

        // Increase position
        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: 0.25 ether,
            collateralSlippage: collateralSlippage,
            uniswapFee: uniswapFee
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPositionWithCollateral(modifyParams, 100e6);

        dealAndApprove(address(USDC), trader, uint256(result.collateralUsed), address(contango));
        _modifyPosition(positionId, modifyParams.quantity, result);

        costBufferMultiplier++;
        _assertUnderlyingBalances({positionId: positionId, lending: 2.25 ether, borrowing: 677.400839e6});

        position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2.25 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(
            position.openCost, 1577.400839e6, costBuffer * 2 + leverageBuffer, quoteDecimals, "openCost"
        );
        assertApproxEqAbsDecimal(
            position.collateral, 897.633897e6, costBuffer + leverageBuffer, quoteDecimals, "collateral"
        );

        _closePosition(positionId);
    }

    function testOpenIncreaseDepositMaxAndClosePosition() public {
        (PositionId positionId,) = _openPosition(2 ether, 1.835293426713062884e18);

        Position memory positionBefore = contango.position(positionId);

        // Increase position
        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: 0.25 ether,
            collateralSlippage: collateralSlippage,
            uniswapFee: uniswapFee
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPositionWithCollateral(modifyParams, 10000e6);

        assertEqDecimal(result.collateralUsed, result.maxCollateral, quoteDecimals, "collateral");

        dealAndApprove(address(quote), trader, uint256(result.collateralUsed), address(contango));
        _modifyPosition(positionId, modifyParams.quantity, result);

        Position memory positionAfter = contango.position(positionId);

        assertApproxEqAbsDecimal(
            positionAfter.openCost,
            positionBefore.openCost + result.cost.abs() + leverageBuffer,
            costBuffer + leverageBuffer,
            quoteDecimals,
            "openCost"
        );
        assertApproxEqAbsDecimal(
            positionAfter.protocolFees,
            positionBefore.protocolFees + result.fee,
            costBuffer,
            quoteDecimals,
            "protocolFees"
        );
        assertApproxEqAbsDecimal(
            positionAfter.collateral,
            positionBefore.collateral + result.collateralUsed - int256(result.fee),
            costBuffer,
            quoteDecimals,
            "collateral"
        );

        _closePosition(positionId);
    }

    function testOpenPositionOnBehalfOfSomeoneElse() public {
        address proxy = address(0x99);

        ModifyCostResult memory result = contangoQuoter.openingCostForPositionWithCollateral(
            OpeningCostParams(symbol, 2 ether, collateralSlippage, uniswapFee), 800e6
        );

        dealAndApprove(address(quote), proxy, result.collateralUsed.toUint256(), address(contango));

        vm.prank(proxy);
        PositionId positionId = contango.createPosition(
            symbol,
            trader,
            2 ether,
            result.cost.slippage(),
            result.collateralUsed.toUint256(),
            proxy,
            result.baseLendingLiquidity,
            uniswapFee
        );

        _assertUnderlyingBalances({positionId: positionId, lending: 2 ether, borrowing: 602.134079e6});

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(
            position.openCost, 1402.134079e6, costBuffer + leverageBuffer, quoteDecimals, "openCost"
        );
        assertApproxEqAbsDecimal(
            position.collateral, 797.896798e6, costBuffer + leverageBuffer, quoteDecimals, "collateral"
        );

        _closePosition(positionId);
    }

    function testOpenIncreaseWithdrawMaxAndClosePosition() public {
        (PositionId positionId,) = _openPosition(2 ether, 1.835293426713062884e18);

        _assertUnderlyingBalances({positionId: positionId, lending: 2 ether, borrowing: 602.134079e6});

        Position memory positionBefore = contango.position(positionId);
        assertEqDecimal(positionBefore.openQuantity, 2 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(
            positionBefore.openCost, 1402.134079e6, costBuffer + leverageBuffer, quoteDecimals, "openCost"
        );
        assertApproxEqAbsDecimal(
            positionBefore.collateral, 797.896798e6, costBuffer + leverageBuffer, quoteDecimals, "collateral"
        );

        // Increase position
        ModifyCostParams memory modifyParams = ModifyCostParams({
            positionId: positionId,
            quantity: 0.25 ether,
            collateralSlippage: collateralSlippage,
            uniswapFee: uniswapFee
        });
        ModifyCostResult memory result = contangoQuoter.modifyCostForPositionWithCollateral(modifyParams, -10_000e6);
        // Deal with subtle precision issues right at the edge
        uint256 collateralBuffer = 4;
        result = contangoQuoter.modifyCostForPositionWithCollateral(
            modifyParams, result.collateralUsed + int256(collateralBuffer)
        );

        _modifyPosition(positionId, modifyParams.quantity, result);

        assertEq(quote.balanceOf(trader), uint256(-result.collateralUsed), "trader balance");

        // TODO alfredo - add a collateral ratio check here

        Position memory positionAfter = contango.position(positionId);
        assertApproxEqAbsDecimal(
            positionAfter.openCost,
            positionBefore.openCost + result.cost.abs() + leverageBuffer,
            costBuffer + leverageBuffer,
            quoteDecimals,
            "openCost"
        );
        assertApproxEqAbsDecimal(
            positionAfter.collateral,
            positionBefore.collateral + result.collateralUsed - int256(result.fee),
            costBuffer + collateralBuffer,
            quoteDecimals,
            "collateral"
        );

        _closePosition(positionId);
    }
}
