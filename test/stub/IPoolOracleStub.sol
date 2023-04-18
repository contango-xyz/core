// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IPoolOracle, IPool} from "@yield-protocol/yieldspace-tv/src/interfaces/IPoolOracle.sol";

contract IPoolOracleStub is IPoolOracle {
    function peek(IPool) external pure override returns (uint256) {
        revert("IPoolOracleStub: not implemented");
    }

    function get(IPool) external pure override returns (uint256) {
        revert("IPoolOracleStub: not implemented");
    }

    function updatePool(IPool) external pure override returns (bool) {
        revert("IPoolOracleStub: not implemented");
    }

    function updatePools(IPool[] calldata) external pure override {
        revert("IPoolOracleStub: not implemented");
    }

    function getBuyBasePreview(IPool pool, uint256 baseOut)
        external
        view
        override
        returns (uint256 fyTokenIn, uint256 updateTime)
    {
        return (pool.buyBasePreview(uint128(baseOut)), block.timestamp);
    }

    function getBuyFYTokenPreview(IPool pool, uint256 fyTokenOut)
        external
        view
        override
        returns (uint256 baseIn, uint256 updateTime)
    {
        return (pool.buyFYTokenPreview(uint128(fyTokenOut)), block.timestamp);
    }

    function getSellBasePreview(IPool pool, uint256 baseIn)
        external
        view
        override
        returns (uint256 fyTokenOut, uint256 updateTime)
    {
        return (pool.sellBasePreview(uint128(baseIn)), block.timestamp);
    }

    function getSellFYTokenPreview(IPool pool, uint256 fyTokenIn)
        external
        view
        override
        returns (uint256 baseOut, uint256 updateTime)
    {
        return (pool.sellFYTokenPreview(uint128(fyTokenIn)), block.timestamp);
    }

    function peekBuyBasePreview(IPool pool, uint256 baseOut)
        external
        view
        override
        returns (uint256 fyTokenIn, uint256 updateTime)
    {
        return (pool.buyBasePreview(uint128(baseOut)), block.timestamp);
    }

    function peekBuyFYTokenPreview(IPool pool, uint256 fyTokenOut)
        external
        view
        override
        returns (uint256 baseIn, uint256 updateTime)
    {
        return (pool.buyFYTokenPreview(uint128(fyTokenOut)), block.timestamp);
    }

    function peekSellBasePreview(IPool pool, uint256 baseIn)
        external
        view
        override
        returns (uint256 fyTokenOut, uint256 updateTime)
    {
        return (pool.sellBasePreview(uint128(baseIn)), block.timestamp);
    }

    function peekSellFYTokenPreview(IPool pool, uint256 fyTokenIn)
        external
        view
        override
        returns (uint256 baseOut, uint256 updateTime)
    {
        return (pool.sellFYTokenPreview(uint128(fyTokenIn)), block.timestamp);
    }
}
