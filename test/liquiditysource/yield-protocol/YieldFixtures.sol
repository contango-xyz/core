//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import "./WithYieldProtocol.sol";
import "../fixtures/PositionFixtures.sol";

import "src/liquiditysource/yield-protocol/Yield.sol";
import {IPoolStub} from "../../stub/IPoolStub.sol";

// solhint-disable no-empty-blocks
abstract contract YieldFixtures is WithYieldProtocol, PositionFixtures {
    using YieldUtils for PositionId;
    using TestUtils for *;

    YieldInstrument internal instrument;

    bool internal addLiquidity = false;

    constructor(Symbol _symbol, bytes6 _baseSeriesId, bytes6 _quoteSeriesId)
        PositionFixtures(_symbol)
        WithYieldProtocol(_symbol, _baseSeriesId, _quoteSeriesId)
    {}

    function setUp() public virtual override(WithYieldProtocol, ContangoTestBase) {
        super.setUp();
        instrument = contangoYield.yieldInstrumentV2(symbol);
        feeModel = contango.feeModel(symbol);
        vm.label(address(feeModel), "FeeModel");

        quote = instrument.quote;
        quoteDecimals = quote.decimals();
        base = instrument.base;
        baseDecimals = base.decimals();
        maturity = instrument.maturity;
        costBuffer = Yield.BORROWING_BUFFER;

        // catch all maxQuoteDust double the borrowing buffer (create + modification) of quote precision up to precision of 8
        maxQuoteDust = Yield.BORROWING_BUFFER * 2;
        if (quoteDecimals > 8) {
            maxQuoteDust = maxQuoteDust * (10 ** (quoteDecimals - 8));
        }
        maxBaseDust = 1;

        if (addLiquidity) {
            if (base == USDC) {
                _provideLiquidity(instrument.basePool, 1_000_000e6);
            } else if (base == DAI) {
                _provideLiquidity(instrument.basePool, 1_000_000e18);
            } else if (base == WETH9) {
                _provideLiquidity(instrument.basePool, 1_000 ether);
            }

            if (quote == USDC) {
                _provideLiquidity(instrument.quotePool, 1_000_000e6);
            } else if (quote == DAI) {
                _provideLiquidity(instrument.quotePool, 1_000_000e18);
            } else if (quote == WETH9) {
                _provideLiquidity(instrument.quotePool, 1_000 ether);
            }
        }
    }

    function _underlyingBalances(PositionId positionId)
        internal
        view
        override
        returns (UnderlyingBalances memory underlyingBalances)
    {
        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());
        underlyingBalances.borrowing = balances.art;
        underlyingBalances.lending = balances.ink;
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
}
