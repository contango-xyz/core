//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./DataTypes.sol";

error ClosingOnly();

error InstrumentClosingOnly(Symbol symbol);

error InstrumentAlreadyExists(Symbol symbol);

error InstrumentExpired(Symbol symbol, uint32 maturity, uint256 timestamp);

error InvalidInstrument(Symbol symbol);

error InvalidPayer(PositionId positionId, address payer);

error InvalidPosition(PositionId positionId);

error InvalidPositionDecrease(PositionId positionId, int256 decreaseQuantity, uint256 currentQuantity);

error InvalidQuantity(int256 quantity);

error NotPositionOwner(PositionId positionId, address msgSender, address actualOwner);

error PositionActive(PositionId positionId, uint32 maturity, uint256 timestamp);

error PositionExpired(PositionId positionId, uint32 maturity, uint256 timestamp);

error ViewOnly();

error OnlyFromWETH(address sender);

error InvalidSelector(bytes4 selector);
