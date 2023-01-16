//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import {IOraclePoolStub} from "../../../stub/IOraclePoolStub.sol";

import "../../fixtures/functional/StubFixtures.sol";
import "./WithYieldFixtures.sol";

// solhint-disable no-empty-blocks
abstract contract YieldStubFixtures is WithYieldFixtures, RatesStubFixtures, StubFixturesSetup {
    using SafeCast for uint256;

    constructor(Symbol _symbol, bytes6 _baseSeriesId, bytes6 _quoteSeriesId)
        WithYieldFixtures(_symbol, _baseSeriesId, _quoteSeriesId)
    {}

    function setUp() public virtual override {
        super.setUp();

        vm.etch(address(yieldInstrument.basePool), getCode(address(new IPoolStub(yieldInstrument.basePool))));
        vm.etch(address(yieldInstrument.quotePool), getCode(address(new IPoolStub(yieldInstrument.quotePool))));

        _configureStubs();
    }

    function _stubBaseRates(uint256 bid, uint256 ask) internal override {
        IPoolStub(address(yieldInstrument.basePool)).setBidAsk(bid.toUint128(), ask.toUint128());
    }

    function _stubQuoteRates(uint256 bid, uint256 ask) internal override {
        IPoolStub(address(yieldInstrument.quotePool)).setBidAsk(bid.toUint128(), ask.toUint128());
    }

    function _stubBaseLiquidity(uint256 borrow, uint256 lend) internal override {
        _setPoolStubLiquidity(yieldInstrument.basePool, borrow, lend);
    }

    function _stubQuoteLiquidity(uint256 borrow, uint256 lend) internal override {
        _setPoolStubLiquidity(yieldInstrument.quotePool, borrow, lend);
    }
}

abstract contract YieldStubETHUSDCFixtures is
    StubETHUSDCFixtures,
    YieldStubFixtures(constants.yETHUSDC2212, constants.FYETH2212, constants.FYUSDC2212)
{
    using SafeCast for uint256;

    function setUp() public virtual override {
        super.setUp();

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
    }

    function _stubPrice(int256 price, int256 spread) internal override {
        stubPrice({
            _base: WETH9,
            _quote: USDC,
            baseUsdPrice: price,
            quoteUsdPrice: 1e6,
            spread: spread,
            uniswapFee: uniswapFee
        });
    }

    function _stubDebtLimits(uint256 min, uint256 max) internal override {
        DataTypes.Debt memory debt = cauldron.debt(constants.USDC_ID, constants.FYETH2212);
        uint24 newMin = min > 0 ? min.toUint24() : debt.min;
        uint96 newMax = max > 0 ? max.toUint96() : debt.max;

        vm.prank(yieldTimelock);
        ICauldronExt(address(cauldron)).setDebtLimits({
            baseId: constants.USDC_ID,
            ilkId: constants.FYETH2212,
            max: newMax,
            min: newMin,
            dec: debt.dec
        });
    }
}
