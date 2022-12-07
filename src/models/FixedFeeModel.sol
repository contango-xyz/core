//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {PositionId, IFeeModel} from "../interfaces/IFeeModel.sol";
import {MathLib} from "../libraries/MathLib.sol";

contract FixedFeeModel is IFeeModel {
    using MathLib for uint256;

    uint256 private immutable fee; // fee percentage in wad, e.g. 0.0015e18 -> 0.15%

    constructor(uint256 _fee) {
        fee = _fee;
    }

    /// @inheritdoc IFeeModel
    /// @dev Calculate a fixed percentage fee
    function calculateFee(address, PositionId, uint256 cost) external view override returns (uint256 calculatedFee) {
        calculatedFee = cost.mulWadUp(fee);
    }
}
