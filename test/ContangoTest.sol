// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import "./ContangoTestBase.sol";

abstract contract ContangoTest is ContangoTestBase {
    function stubChainlinkPrice(int256 price, address chainlinkAggregator, uint8 decimals, IERC20Metadata token)
        internal
        returns (ChainlinkAggregatorV2V3Mock oracle)
    {
        if (!stubbedAddresses[chainlinkAggregator]) {
            vm.etch(address(chainlinkAggregator), getCode(address(new ChainlinkAggregatorV2V3Mock(decimals, token))));
            stubbedAddresses[chainlinkAggregator] = true;
        }

        oracle = ChainlinkAggregatorV2V3Mock(chainlinkAggregator);
        oracle.set(price);
    }

    function stubUniswapPrice(AggregatorV3Interface oracle, int256 spread, IERC20 _base, IERC20 _quote, uint24 fee)
        internal
    {
        IERC20 token0 = _base < _quote ? _base : _quote;
        IERC20 token1 = _base > _quote ? _base : _quote;

        address poolAddress = PoolAddress.computeAddress(
            uniswapAddresses.UNISWAP_FACTORY, PoolAddress.getPoolKey(address(token0), address(token1), fee)
        );

        if (!stubbedAddresses[poolAddress]) {
            vm.etch(
                poolAddress, getCode(address(new UniswapPoolStub(token0, token1, oracle, _quote == token0, spread)))
            );
            stubbedAddresses[poolAddress] = true;
            vm.label(poolAddress, "UniswapPoolStub");
        }
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
