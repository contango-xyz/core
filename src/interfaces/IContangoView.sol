//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../libraries/DataTypes.sol";
import "./IFeeModel.sol";

/// @title Interface to state querying
interface IContangoView {
    function closingOnly() external view returns (bool);
    function feeModel(Symbol symbol) external view returns (IFeeModel);
    function position(PositionId positionId) external view returns (Position memory _position);
}
