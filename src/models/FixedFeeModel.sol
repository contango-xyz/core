//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "../interfaces/IFeeModel.sol";
import "solmate/src/utils/FixedPointMathLib.sol";

uint256 constant MAX_FIXED_FEE = 1e18; // 100%
uint256 constant MIN_FIXED_FEE = 0.000001e18; // 0.0001%

contract FixedFeeModel is IFeeModel {
    using FixedPointMathLib for uint256;

    error AboveMaxFee(uint256 fee);
    error BelowMinFee(uint256 fee);

    uint256 public immutable fee; // fee percentage in wad, e.g. 0.0015e18 -> 0.15%

    constructor(uint256 _fee) {
        if (_fee > MAX_FIXED_FEE) revert AboveMaxFee(_fee);
        if (_fee < MIN_FIXED_FEE) revert BelowMinFee(_fee);

        fee = _fee;
    }

    /// @inheritdoc IFeeModel
    function calculateFee(address, PositionId, uint256 cost) external view override returns (uint256 calculatedFee) {
        calculatedFee = cost.mulWadUp(fee);
    }
}
