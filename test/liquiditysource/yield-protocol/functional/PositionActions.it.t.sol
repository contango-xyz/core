//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../fixtures/functional/PositionActionsFixtures.sol";
import "./YieldStubFixtures.sol";

contract YieldPositionActionsETHUSDCTest is PositionActionsETHUSDCFixtures, YieldStubETHUSDCFixtures {
    using SignedMath for int256;
    using SafeCast for int256;
    using SafeCast for uint256;
    using YieldUtils for PositionId;

    function setUp() public override(YieldStubETHUSDCFixtures, ContangoTestBase) {
        super.setUp();

        collateralSlippage = 0;
    }

    function _expectAboveMaxCollateralRevert() internal override {
        vm.expectRevert("Min debt not reached");
    }

    function _expectExcessiveDebtBurnRevert() internal override {
        vm.expectRevert("Result below zero");
    }

    function _assertUnderlyingBalances(PositionId positionId, uint256 lending, uint256 borrowing) internal override {
        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertEqDecimal(balances.ink, lending, baseDecimals, "ink");
        assertApproxEqAbsDecimal(balances.art, borrowing, costBuffer * costBufferMultiplier, quoteDecimals, "art");
    }

    // function testOpenAndClosePositionMaxCollateral() public {
    //     (PositionId positionId, ModifyCostResult memory result) = _openPosition(2 ether, 2000e6);
    //     assertEqDecimal(result.collateralUsed, 1248.16059e6, quoteDecimals, "collateralUsed");

    //     DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
    //     assertEqDecimal(balances.ink, 2 ether, baseDecimals, "ink");
    //     assertApproxEqAbsDecimal(balances.art, 101.395988e6, Yield.BORROWING_BUFFER, quoteDecimals, "art");

    //     Position memory position = contango.position(positionId);
    //     assertEqDecimal(position.openQuantity, 2 ether, baseDecimals, "openQuantity");
    //     assertEqDecimal(position.openCost, 1349.556578e6,6, "openCost");
    //     assertApproxEqAbsDecimal(position.collateral, 1246.136255e6, Yield.BORROWING_BUFFER, quoteDecimals, "collateral");
    //     assertEqDecimal(position.protocolFees, 2.024335e6, quoteDecimals, "fees");

    //     _closePosition(positionId);
    // }

    // TODO alfredo - see if assertions can be changed on the tests below to have them shared
    // these tests had to be defined separately on Notional and Yield side due to collateralisation requirements being different (e.g. Notional max CR requirement)

    function testOpenAndClosePositionFullCollateral() public {
        uint256 collateral = 10_000e6;
        dealAndApprove(address(quote), trader, collateral, address(contango));

        vm.prank(trader);
        PositionId positionId =
            contango.createPosition(symbol, trader, 2 ether, 1420e6, collateral, trader, HIGH_LIQUIDITY, uniswapFee);

        // TODO alfredo - revisit if we should allow a position without min borrowing or align with Notional impl
        _assertUnderlyingBalances({positionId: positionId, lending: 2 ether, borrowing: 0});

        Position memory position = contango.position(positionId);
        assertEqDecimal(position.openQuantity, 2 ether, baseDecimals, "openQuantity");
        assertApproxEqAbsDecimal(position.openCost, 1338.91e6, costBuffer, quoteDecimals, "openCost");
        assertApproxEqAbsDecimal(position.collateral, 1336.901635e6, costBuffer, quoteDecimals, "collateral");
        assertEqDecimal(position.protocolFees, 2.008365e6, quoteDecimals, "fees");

        assertEq(
            USDC.balanceOf(trader), collateral - uint256(position.collateral) - position.protocolFees, "user balance"
        );

        _closePosition(positionId);
    }
}
