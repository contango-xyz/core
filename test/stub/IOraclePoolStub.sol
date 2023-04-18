//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@yield-protocol/vault-v2/src/interfaces/IOracle.sol";
import "./IPoolStub.sol";

contract IOraclePoolStub is IOracle {
    bytes32 public asset;
    IPoolStub public immutable pool;

    constructor(IPoolStub _pool, bytes32 _asset) {
        pool = _pool;
        asset = _asset;
    }

    function peek(bytes32 base, bytes32, /* quote */ uint256 amount)
        public
        view
        override
        returns (uint256 value, uint256 updateTime)
    {
        value =
            base == asset ? pool.sellFYTokenPreviewUnsafe(uint128(amount)) : pool.sellBasePreviewUnsafe(uint128(amount));
        updateTime = block.timestamp;
    }

    function get(bytes32 base, bytes32 quote, uint256 amount)
        public
        view
        override
        returns (uint256 value, uint256 updateTime)
    {
        return peek(base, quote, amount);
    }
}
