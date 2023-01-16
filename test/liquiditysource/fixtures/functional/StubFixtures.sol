//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

abstract contract PriceStubFixtures {
    function _stubPrice(int256 price, int256 spread) internal virtual;
}

abstract contract RatesStubFixtures {
    function _stubBaseRates(uint256 bid, uint256 ask) internal virtual;
    function _stubQuoteRates(uint256 bid, uint256 ask) internal virtual;

    function _stubBaseLiquidity(uint256 borrow, uint256 lend) internal virtual;
    function _stubQuoteLiquidity(uint256 borrow, uint256 lend) internal virtual;
}

abstract contract VaultStubFixtures {
    function _stubDebtLimits(uint256 min, uint256 max) internal virtual;
}

abstract contract StubFixturesSetup {
    function _configureStubs() internal virtual;
}

abstract contract StubETHUSDCFixtures is PriceStubFixtures, RatesStubFixtures, VaultStubFixtures, StubFixturesSetup {
    function _configureStubs() internal override {
        _stubPrice({price: 700e6, spread: 1e6});

        _stubBaseRates({bid: 0.945e18, ask: 0.955e18});
        _stubQuoteRates({bid: 0.895e6, ask: 0.905e6});

        _stubDebtLimits({min: 100, max: 0});

        _stubBaseLiquidity({borrow: 1_000 ether, lend: 1_000 ether});
        _stubQuoteLiquidity({borrow: 1_000_000e6, lend: 1_000_000e6});
    }
}
