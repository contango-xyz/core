//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import "./WithYieldProtocol.sol";
import "../PositionFixtures.sol";

import "src/liquiditysource/yield-protocol/Yield.sol";
import {IPoolStub} from "../../stub/IPoolStub.sol";

// solhint-disable no-empty-blocks
abstract contract YieldFixtures is WithYieldProtocol, PositionFixtures {
    using YieldUtils for PositionId;
    using TestUtils for *;

    YieldInstrument internal yieldInstrument;

    bool internal addLiquidity = false;

    constructor(Symbol _symbol, bytes6 _baseSeriesId, bytes6 _quoteSeriesId)
        PositionFixtures(_symbol)
        WithYieldProtocol(_baseSeriesId, _quoteSeriesId)
    {}

    function setUp() public virtual override (WithYieldProtocol, ContangoTestBase) {
        super.setUp();
        (instrument, yieldInstrument) = contangoYield.yieldInstrument(symbol);
        feeModel = contango.feeModel(symbol);
        vm.label(address(feeModel), "FeeModel");

        quote = instrument.quote;
        quoteDecimals = quote.decimals();
        base = instrument.base;
        baseDecimals = base.decimals();

        if (addLiquidity) {
            if (base == USDC) {
                _provideLiquidity(yieldInstrument.basePool, 1_000_000e6);
            } else if (base == DAI) {
                _provideLiquidity(yieldInstrument.basePool, 1_000_000e18);
            } else if (base == WETH) {
                _provideLiquidity(yieldInstrument.basePool, 1_000 ether);
            }

            if (quote == USDC) {
                _provideLiquidity(yieldInstrument.quotePool, 1_000_000e6);
            } else if (quote == DAI) {
                _provideLiquidity(yieldInstrument.quotePool, 1_000_000e18);
            } else if (quote == WETH) {
                _provideLiquidity(yieldInstrument.quotePool, 1_000 ether);
            }
        }
    }

    // TODO make this dynamic when the inverse contracts PR is merged
    function stubPriceWETHUSDC(int256 price) internal {
        stubPriceWETHUSDC(price, 0);
    }

    function stubPriceWETHUSDC(int256 price, int256 spread) internal {
        // ETH / USD
        ChainlinkAggregatorV2V3Mock wethUsd =
            stubChainlinkPrice(price, 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612, 8, USDC);
        // USDC / USD
        stubChainlinkPrice(1e6, 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3, 8, USDC);

        stubUniswapPrice(wethUsd, spread, WETH, USDC, constants.FEE_0_05);
    }

    function _setPoolStubLiquidity(IPool pool, uint256 liquidity) internal {
        _setPoolStubLiquidity(pool, liquidity, liquidity);
    }

    function _setPoolStubLiquidity(IPool pool, uint256 borrowing, uint256 lending) internal {
        deal(address(pool.fyToken()), address(pool), lending);
        deal(address(pool.baseToken()), address(pool), borrowing);
        IPoolStub(address(pool)).sync();
    }

    function _provideLiquidity(IPool pool, uint256 liquidity) internal {
        deal(address(pool.fyToken()), address(this), liquidity / 10);
        pool.fyToken().transfer(address(pool), liquidity / 10);

        deal(address(pool.baseToken()), address(this), liquidity * 100);
        pool.baseToken().transfer(address(pool), liquidity * 100);

        pool.mint(address(1), address(1), 0, type(uint256).max);

        deal(address(pool.fyToken()), address(this), liquidity / 10);
        pool.fyToken().transfer(address(pool), liquidity / 10);
        pool.sellFYToken(address(1), 0);
    }

    function _fee(address _trader, PositionId _positionId, uint256 _cost) internal view returns (uint256) {
        return address(feeModel) != address(0) ? feeModel.calculateFee(_trader, _positionId, _cost) : 0;
    }

    // ==================== position fixtures ====================

    // TODO alfredo - make it generic when notional's version is implemented

    function _deliverPosition(PositionId positionId) internal {
        uint256 traderBalance = quoteBalance(trader);
        uint256 treasuryBalance = quote.balanceOf(treasury);
        Position memory position = contango.position(positionId);
        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());

        uint256 deliveryCost = contangoQuoter.deliveryCostForPosition(positionId);
        assertEqDecimal(deliveryCost, balances.art + position.protocolFees, quoteDecimals, "deliveryCost");
        dealAndApprove(address(quote), trader, deliveryCost, address(contango));

        vm.recordLogs();
        vm.prank(trader);
        contango.deliver(positionId, trader, trader);

        assertPositionWasClosedInternal(positionId);

        Vm.Log memory log =
            vm.getRecordedLogs().first("PositionDelivered(bytes32,address,uint256,address,uint256,uint256,uint256)");
        assertEq(log.topics[1], Symbol.unwrap(symbol));
        assertEq(uint256(log.topics[2]), uint160(address(trader)));
        assertEq(uint256(log.topics[3]), PositionId.unwrap(positionId));

        (address to, uint256 deliveredQuantity, uint256 _deliveryCost, uint256 totalFees) =
            abi.decode(log.data, (address, uint256, uint256, uint256));

        assertEq(to, trader, "to");
        assertEqDecimal(deliveredQuantity, position.openQuantity, baseDecimals, "deliveredQuantity");
        // We don't charge a fee on delivery
        assertEqDecimal(totalFees, position.protocolFees, quoteDecimals, "totalFees");
        assertEqDecimal(_deliveryCost, balances.art, quoteDecimals, "deliveryCost 2 ");

        assertEqDecimal(quoteBalance(address(contango)), 0, quoteDecimals, "contango balance");
        assertEqDecimal(quote.balanceOf(treasury), treasuryBalance + totalFees, quoteDecimals, "treasury balance");
        assertEqDecimal(quoteBalance(trader), traderBalance, quoteDecimals, "trader quote balance");
        assertEqDecimal(base.balanceOf(trader), position.openQuantity, quoteDecimals, "trader base balance");
    }

    function assertPositionWasClosedInternal(PositionId positionId) internal returns (Position memory position) {
        position = assertPositionWasClosed(positionId);

        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        assertEq(balances.ink, 0, "ink");
        assertEq(balances.art, 0, "art");
    }
}
