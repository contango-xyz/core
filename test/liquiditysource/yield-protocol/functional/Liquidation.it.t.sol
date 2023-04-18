//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../fixtures/LiquidationFixtures.sol";
import "./WithYieldFixtures.sol";
import {IOraclePoolStub} from "../../../stub/IOraclePoolStub.sol";

contract YieldLiquidationUSDCTest is
    LiquidationFixtures,
    WithYieldFixtures(constants.yETHUSDC2306, constants.FYETH2306, constants.FYUSDC2306)
{
    using SignedMath for int256;
    using SafeCast for int256;
    using YieldUtils for PositionId;

    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();

        stubPrice({
            _base: WETH9,
            _quote: USDC,
            baseUsdPrice: 1000e6,
            quoteUsdPrice: 1e6,
            spread: 1e6,
            uniswapFee: uniswapFee
        });

        vm.etch(address(instrument.basePool), address(new IPoolStub(instrument.basePool)).code);
        vm.etch(address(instrument.quotePool), address(new IPoolStub(instrument.quotePool)).code);

        IPoolStub(address(instrument.basePool)).setBidAsk(0.945e18, 0.955e18);
        IPoolStub(address(instrument.quotePool)).setBidAsk(0.895e6, 0.905e6);

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

        _setPoolStubLiquidity(instrument.basePool, 1_000 ether);
        _setPoolStubLiquidity(instrument.quotePool, 1_000_000e6);
    }

    function testPartiallyLiquidateAndClosePosition() public {
        // Given
        PositionId positionId = _halfOfThePositionWasAuctionedAndImmediatelyBought();

        // When - Close position
        _closePosition(positionId);
    }

    function testPartiallyLiquidateAndDeliverPosition() public {
        // Given
        PositionId positionId = _halfOfThePositionWasAuctionedAndImmediatelyBought();

        // When
        vm.warp(cauldron.series(constants.FYUSDC2306).maturity);

        // Then
        _deliverPosition(positionId);
    }

    function testFullyLiquidateAndClosePosition() public {
        // Given
        PositionId positionId = _allThePositionWasAuctionedAndImmediatelyBought();

        // When - Close position
        _closePosition(positionId);
    }

    function testFullyLiquidateAndDeliverPosition() public {
        // Given
        PositionId positionId = _allThePositionWasAuctionedAndImmediatelyBought();

        // When
        vm.warp(cauldron.series(constants.FYUSDC2306).maturity);

        // Then
        _deliverPosition(positionId);
    }

    function testPositionHasNothingLeftAndClosePosition() public {
        PositionId positionId = _allThePositionWasAuctionedAndBoughtAfterDuration();

        (bool success, bytes memory data) = address(contangoQuoter).call(
            abi.encodeWithSelector(
                contangoQuoter.modifyCostForPositionWithCollateral.selector,
                ModifyCostParams(positionId, -2 ether, collateralSlippage, uniswapFee),
                0
            )
        );
        assertFalse(success);
        assertEq(data, abi.encodeWithSelector(InvalidPosition.selector, positionId));

        vm.expectRevert(abi.encodeWithSelector(InvalidPosition.selector, positionId));
        vm.prank(trader);
        contango.modifyPosition(positionId, -2 ether, 0, 0, trader, HIGH_LIQUIDITY, uniswapFee);
    }

    function testPositionHasNothingLeftAndDeliverPosition() public {
        PositionId positionId = _allThePositionWasAuctionedAndBoughtAfterDuration();
        vm.warp(cauldron.series(constants.FYUSDC2306).maturity);

        vm.expectRevert(abi.encodeWithSelector(InvalidPosition.selector, positionId));
        contangoQuoter.deliveryCostForPosition(positionId);

        vm.expectRevert(abi.encodeWithSelector(InvalidPosition.selector, positionId));
        vm.prank(trader);
        contango.deliver(positionId, trader, trader);
    }

    function testPositionUnderAuction() public {
        (PositionId positionId,) = _openPosition(10 ether, 100e18);
        stubPrice({
            _base: WETH9,
            _quote: USDC,
            baseUsdPrice: 999e6,
            quoteUsdPrice: 1e6,
            spread: 1e6,
            uniswapFee: uniswapFee
        });
        witch.auction(positionId.toVaultId(), liquidator);

        PositionStatus memory result = contangoQuoter.positionStatus(positionId, uniswapFee);
        assertTrue(result.liquidating);

        vm.expectRevert("Only vault owner");
        vm.prank(trader);
        contango.modifyPosition(positionId, -5 ether, 0, 0, trader, HIGH_LIQUIDITY, uniswapFee);
    }

    function testExpiredPositionUnderAuction() public {
        (PositionId positionId,) = _openPosition(10 ether, 100e18);
        vm.warp(cauldron.series(constants.FYUSDC2306).maturity);
        stubPrice({
            _base: WETH9,
            _quote: USDC,
            baseUsdPrice: 999e6,
            quoteUsdPrice: 1e6,
            spread: 1e6,
            uniswapFee: uniswapFee
        });
        witch.auction(positionId.toVaultId(), liquidator);

        PositionStatus memory result = contangoQuoter.positionStatus(positionId, uniswapFee);
        assertTrue(result.liquidating);

        dealAndApprove(address(USDC), trader, 1_000_000e6, address(contango));
        vm.expectRevert("Only vault owner");
        vm.prank(trader);
        contango.deliver(positionId, trader, trader);
    }

    function _halfOfThePositionWasAuctionedAndImmediatelyBought() internal returns (PositionId positionId) {
        (positionId,) = _openPosition(10 ether, 100e18);
        bytes12 vaultId = positionId.toVaultId();
        DataTypes.Balances memory balances = cauldron.balances(vaultId);
        Position memory position = contango.position(positionId);

        stubPrice({
            _base: WETH9,
            _quote: USDC,
            baseUsdPrice: 999e6,
            quoteUsdPrice: 1e6,
            spread: 1e6,
            uniswapFee: uniswapFee
        });

        // When
        witch.auction(vaultId, liquidator);
        (uint256 liquidatorCut,, uint256 artIn) = witch.calcPayout(vaultId, liquidator, type(uint256).max);
        assertEqDecimal(artIn, balances.art / 2, 6, "artIn");
        assertEqDecimal(liquidatorCut, (balances.ink / 2 * 0.8928571428571429e18) / 1e18, baseDecimals, "liquidatorCut");

        _liquidate(vaultId, artIn);

        // Then
        _verifyLiquidationEvent(positionId, position, liquidatorCut, artIn);
    }

    function _allThePositionWasAuctionedAndImmediatelyBought() internal returns (PositionId positionId) {
        (positionId,) = _openPosition(10 ether, 100e18);
        bytes12 vaultId = positionId.toVaultId();
        DataTypes.Balances memory balances = cauldron.balances(vaultId);
        Position memory position = contango.position(positionId);

        vm.prank(yieldTimelock);
        ICauldronExt(address(cauldron)).setDebtLimits({
            baseId: constants.USDC_ID,
            ilkId: constants.FYETH2306,
            max: 100_000,
            min: 5_000,
            dec: 6
        });

        stubPrice({
            _base: WETH9,
            _quote: USDC,
            baseUsdPrice: 999e6,
            quoteUsdPrice: 1e6,
            spread: 1e6,
            uniswapFee: uniswapFee
        });

        // When
        witch.auction(vaultId, liquidator);
        (uint256 liquidatorCut,, uint256 artIn) = witch.calcPayout(vaultId, liquidator, type(uint256).max);
        assertEqDecimal(artIn, balances.art, 6, "artIn");
        assertEqDecimal(liquidatorCut, (balances.ink * 0.8928571428571429e18) / 1e18, baseDecimals, "liquidatorCut");

        _liquidate(vaultId, artIn);

        // Then
        _verifyLiquidationEvent(positionId, position, liquidatorCut, artIn);
    }

    function _allThePositionWasAuctionedAndBoughtAfterDuration() internal returns (PositionId positionId) {
        (positionId,) = _openPosition(10 ether, 100e18);
        bytes12 vaultId = positionId.toVaultId();
        DataTypes.Balances memory balances = cauldron.balances(vaultId);
        Position memory position = contango.position(positionId);

        vm.prank(yieldTimelock);
        ICauldronExt(address(cauldron)).setDebtLimits({
            baseId: constants.USDC_ID,
            ilkId: constants.FYETH2306,
            max: 100_000,
            min: 5_000,
            dec: 6
        });

        stubPrice({
            _base: WETH9,
            _quote: USDC,
            baseUsdPrice: 999e6,
            quoteUsdPrice: 1e6,
            spread: 1e6,
            uniswapFee: uniswapFee
        });

        // When
        witch.auction(vaultId, liquidator);
        skip(10 minutes); // wait until auction completes to obtain 100% of the auctioned collateral
        (uint256 liquidatorCut,, uint256 artIn) = witch.calcPayout(vaultId, liquidator, type(uint256).max);
        assertApproxEqAbsDecimal(artIn, balances.art, 2, 6, "artIn");
        assertApproxEqAbsDecimal(liquidatorCut, balances.ink, 2, 6, "liquidatorCut");

        _liquidate(vaultId, artIn);

        // Then
        _verifyLiquidationEvent(positionId, position, liquidatorCut, artIn);
    }

    function _liquidate(bytes12 vaultId, uint256 artIn) internal {
        dealAndApprove(address(USDC), liquidator, artIn, address(ladle.joins(constants.USDC_ID)));
        vm.recordLogs();
        vm.prank(liquidator);
        witch.payBase(vaultId, liquidator, 0, type(uint128).max);
    }
}
