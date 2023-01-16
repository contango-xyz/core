// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import "./ContangoTestBase.sol";

abstract contract ContangoTest is ContangoTestBase {
    struct StubUniswapPoolParams {
        address poolAddress;
        ERC20 token0;
        ERC20 token1;
        AggregatorV3Interface token0Oracle;
        AggregatorV3Interface token1Oracle;
        bool token0Quoted;
        int256 spread;
    }

    function stubPrice(ERC20 _base, ERC20 _quote, int256 baseUsdPrice, int256 quoteUsdPrice, uint24 uniswapFee)
        internal
    {
        stubPrice({
            _base: _base,
            _quote: _quote,
            baseUsdPrice: baseUsdPrice,
            quoteUsdPrice: quoteUsdPrice,
            spread: 0,
            uniswapFee: uniswapFee
        });
    }

    function stubPrice(
        ERC20 _base,
        ERC20 _quote,
        int256 baseUsdPrice,
        int256 quoteUsdPrice,
        int256 spread,
        uint24 uniswapFee
    ) internal {
        uint8 quoteDecimals = _quote.decimals();
        ChainlinkAggregatorV2V3Mock baseUsdOracle =
            stubChainlinkPrice(baseUsdPrice, chainlinkUsdOracles[_base], quoteDecimals);
        ChainlinkAggregatorV2V3Mock quoteUsdOracle =
            stubChainlinkPrice(quoteUsdPrice, chainlinkUsdOracles[_quote], quoteDecimals);
        stubUniswapPrice(_base, _quote, baseUsdOracle, quoteUsdOracle, spread, uniswapFee);
    }

    function stubChainlinkPrice(int256 price, address chainlinkAggregator, uint8 priceDecimals)
        internal
        returns (ChainlinkAggregatorV2V3Mock oracle)
    {
        uint8 decimals = ChainlinkAggregatorV2V3Mock(chainlinkAggregator).decimals();
        if (!stubbedAddresses[chainlinkAggregator]) {
            vm.etch(chainlinkAggregator, getCode(address(new ChainlinkAggregatorV2V3Mock(decimals, priceDecimals))));
            stubbedAddresses[chainlinkAggregator] = true;
        }

        oracle = ChainlinkAggregatorV2V3Mock(chainlinkAggregator).set(price);
    }

    function stubUniswapPrice(
        ERC20 _base,
        ERC20 _quote,
        AggregatorV3Interface baseOracle,
        AggregatorV3Interface quoteOracle,
        int256 spread,
        uint24 uniswapFee
    ) internal {
        ERC20 token0 = _base < _quote ? _base : _quote;
        ERC20 token1 = _base > _quote ? _base : _quote;

        AggregatorV3Interface token0Oracle = _base < _quote ? baseOracle : quoteOracle;
        AggregatorV3Interface token1Oracle = _base > _quote ? baseOracle : quoteOracle;

        address poolAddress = PoolAddress.computeAddress(
            uniswapAddresses.UNISWAP_FACTORY, PoolAddress.getPoolKey(address(token0), address(token1), uniswapFee)
        );

        if (!stubbedAddresses[poolAddress]) {
            _stubUniswapPool(
                StubUniswapPoolParams({
                    poolAddress: poolAddress,
                    token0: token0,
                    token1: token1,
                    token0Oracle: token0Oracle,
                    token1Oracle: token1Oracle,
                    token0Quoted: _quote == token0,
                    spread: spread
                })
            );
        }
    }

    function _stubUniswapPool(StubUniswapPoolParams memory params) private {
        vm.etch(
            params.poolAddress,
            getCode(
                address(
                    new UniswapPoolStub({
                        _token0: params.token0,
                        _token1: params.token1,
                        _token0Oracle: params.token0Oracle,
                        _token1Oracle: params.token1Oracle,
                        _token0Quoted: params.token0Quoted,
                        _absoluteSpread: params.spread})
                )
            )
        );
        stubbedAddresses[params.poolAddress] = true;
        vm.label(params.poolAddress, "UniswapPoolStub");
    }

    // solhint-disable-next-line var-name-mixedcase
    function getCode(address who) internal view returns (bytes memory o_code) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // retrieve the size of the code, this needs assembly
            let size := extcodesize(who)
            // allocate output byte array - this could also be done without assembly
            // by using o_code = new bytes(size)
            o_code := mload(0x40)
            // new "memory end" including padding
            mstore(0x40, add(o_code, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            // store length in memory
            mstore(o_code, size)
            // actually retrieve the code, this needs assembly
            extcodecopy(who, add(o_code, 0x20), 0, size)
        }
    }
}
