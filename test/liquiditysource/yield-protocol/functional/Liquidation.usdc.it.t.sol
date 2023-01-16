//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./WithYieldFixtures.sol";
import {IOraclePoolStub} from "../../../stub/IOraclePoolStub.sol";

contract YieldLiquidationUSDCTest is
    WithYieldFixtures(constants.yETHUSDC2212, constants.FYETH2212, constants.FYUSDC2212)
{
    using SignedMath for int256;
    using Math for uint256;
    using SafeCast for int256;
    using YieldUtils for PositionId;
    using TestUtils for *;

    address liquidator = address(0xb07);

    function setUp() public override {
        super.setUp();

        stubPrice({
            _base: WETH9,
            _quote: USDC,
            baseUsdPrice: 1000e6,
            quoteUsdPrice: 1e6,
            spread: 1e6,
            uniswapFee: uniswapFee
        });

        vm.etch(address(yieldInstrument.basePool), getCode(address(new IPoolStub(yieldInstrument.basePool))));
        vm.etch(address(yieldInstrument.quotePool), getCode(address(new IPoolStub(yieldInstrument.quotePool))));

        IPoolStub(address(yieldInstrument.basePool)).setBidAsk(0.945e18, 0.955e18);
        IPoolStub(address(yieldInstrument.quotePool)).setBidAsk(0.895e6, 0.905e6);

        symbol = Symbol.wrap("yETHUSDC2212-2");
        vm.prank(contangoTimelock);
        (instrument, yieldInstrument) =
            contangoYield.createYieldInstrument(symbol, constants.FYETH2212, constants.FYUSDC2212, feeModel);

        vm.startPrank(yieldTimelock);
        ICompositeMultiOracle compositeOracle = ICompositeMultiOracle(0x750B3a18115fe090Bc621F9E4B90bd442bcd02F2);
        compositeOracle.setSource(
            constants.FYETH2212,
            constants.ETH_ID,
            new IOraclePoolStub(IPoolStub(address(yieldInstrument.basePool)), constants.FYETH2212)
        );
        vm.stopPrank();

        _setPoolStubLiquidity(yieldInstrument.basePool, 1_000 ether);
        _setPoolStubLiquidity(yieldInstrument.quotePool, 1_000_000e6);
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
        vm.warp(cauldron.series(constants.FYUSDC2212).maturity);

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
        vm.warp(cauldron.series(constants.FYUSDC2212).maturity);

        // Then
        _deliverPosition(positionId);
    }

    function testPositionHasNothingLeftAndClosePosition() public {
        PositionId positionId = _allThePositionWasAuctionedAndBoughtAfterDuration();

        (bool success, bytes memory data) = address(contangoQuoter).call(
            abi.encodeWithSelector(
                contangoQuoter.modifyCostForPosition.selector,
                ModifyCostParams(positionId, -2 ether, 0, collateralSlippage, uniswapFee)
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
        vm.warp(cauldron.series(constants.FYUSDC2212).maturity);

        vm.expectRevert(abi.encodeWithSelector(InvalidPosition.selector, positionId));
        contangoQuoter.deliveryCostForPosition(positionId);

        vm.expectRevert(abi.encodeWithSelector(InvalidPosition.selector, positionId));
        vm.prank(trader);
        contango.deliver(positionId, trader, trader);
    }

    function testPositionUnderAuction() public {
        (PositionId positionId,) = _openPosition(10 ether, 3520e6);
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
        (PositionId positionId,) = _openPosition(10 ether, 3520e6);
        vm.warp(cauldron.series(constants.FYUSDC2212).maturity);
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
        (positionId,) = _openPosition(10 ether, 3520e6);
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
        assertEqDecimal(liquidatorCut, (balances.ink * 0.375e18) / 1e18, baseDecimals, "liquidatorCut"); // ink * 0.5 * 0.75 => ink * 0.375

        _liquidate(vaultId, artIn);

        // Then
        _verifyLiquidationEvent(positionId, position, liquidatorCut, artIn);
    }

    function _allThePositionWasAuctionedAndImmediatelyBought() internal returns (PositionId positionId) {
        (positionId,) = _openPosition(10 ether, 3520e6);
        bytes12 vaultId = positionId.toVaultId();
        DataTypes.Balances memory balances = cauldron.balances(vaultId);
        Position memory position = contango.position(positionId);

        vm.prank(yieldTimelock);
        ICauldronExt(address(cauldron)).setDebtLimits({
            baseId: constants.USDC_ID,
            ilkId: constants.FYETH2212,
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
        assertEqDecimal(liquidatorCut, (balances.ink * 0.75e18) / 1e18, baseDecimals, "liquidatorCut"); // ink * 0.75

        _liquidate(vaultId, artIn);

        // Then
        _verifyLiquidationEvent(positionId, position, liquidatorCut, artIn);
    }

    function _allThePositionWasAuctionedAndBoughtAfterDuration() internal returns (PositionId positionId) {
        (positionId,) = _openPosition(10 ether, 3520e6);
        bytes12 vaultId = positionId.toVaultId();
        DataTypes.Balances memory balances = cauldron.balances(vaultId);
        Position memory position = contango.position(positionId);

        vm.prank(yieldTimelock);
        ICauldronExt(address(cauldron)).setDebtLimits({
            baseId: constants.USDC_ID,
            ilkId: constants.FYETH2212,
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

    function _verifyLiquidationEvent(
        PositionId positionId,
        Position memory position,
        uint256 liquidatorCut,
        uint256 artIn
    ) private {
        Vm.Log memory log =
            vm.getRecordedLogs().first("PositionLiquidated(bytes32,address,uint256,uint256,uint256,int256,int256)");
        assertEq(log.topics[1], Symbol.unwrap(symbol));
        assertEq(uint256(log.topics[2]), uint160(address(trader)));
        assertEq(uint256(log.topics[3]), PositionId.unwrap(positionId));
        (uint256 openQuantity, uint256 openCost, int256 collateral, int256 realisedPnL) =
            abi.decode(log.data, (uint256, uint256, int256, int256));
        assertEqDecimal(openQuantity, position.openQuantity - liquidatorCut, baseDecimals, "openQuantity");
        uint256 closedCost = (liquidatorCut * position.openCost).ceilDiv(position.openQuantity);
        assertEqDecimal(openCost, position.openCost - closedCost, 6, "openCost");
        assertEqDecimal(realisedPnL, int256(artIn) - int256(closedCost), 6, "realisedPnL");
        assertEqDecimal(collateral, position.collateral + realisedPnL, 6, "collateral");

        Position memory positionAfter = contango.position(positionId);
        assertEqDecimal(positionAfter.openQuantity, openQuantity, baseDecimals, "openQuantity");
        assertEqDecimal(positionAfter.openCost, openCost, 6, "openCost");
        assertEqDecimal(positionAfter.collateral, collateral, 6, "collateral");
        // We don't charge a fee on liquidation
        assertEqDecimal(positionAfter.protocolFees, position.protocolFees, 6, "protocolFees");
    }
}
