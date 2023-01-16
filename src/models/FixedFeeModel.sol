//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "../interfaces/IFeeModel.sol";
import "solmate/src/utils/FixedPointMathLib.sol";

contract FixedFeeModel is IFeeModel {
    uint256 private immutable fee; // fee percentage in wad, e.g. 0.0015e18 -> 0.15%

    constructor(uint256 _fee) {
        fee = _fee;
    }

    /// @inheritdoc IFeeModel
    function calculateFee(address, PositionId, uint256 cost) external view override returns (uint256 calculatedFee) {
        calculatedFee = FixedPointMathLib.mulWadUp(cost, fee);
    }
}
