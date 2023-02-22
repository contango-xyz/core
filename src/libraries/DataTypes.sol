//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../interfaces/IFeeModel.sol";
import "solmate/src/tokens/ERC20.sol";
import {IFYToken} from "@yield-protocol/vault-v2/contracts/interfaces/IFYToken.sol";
import {IPool} from "@yield-protocol/yieldspace-tv/src/interfaces/IPool.sol";

type Symbol is bytes32;

type PositionId is uint256;

struct Position {
    Symbol symbol;
    uint256 openQuantity; // total quantity to which the trader is exposed
    uint256 openCost; // total amount that the trader exchanged for base
    int256 collateral; // Trader collateral
    uint256 protocolFees; // Fees this position accrued
    uint32 maturity; // Position maturity
    IFeeModel feeModel; // Fee model for this position
}

// Represents an execution of a trade, kinda similar to an execution report in FIX
struct Fill {
    uint256 size; // Size of the fill (base ccy)
    uint256 cost; // Amount of quote traded in exchange for the base
    uint256 hedgeSize; // Actual amount of base ccy traded on the spot market
    uint256 hedgeCost; // Actual amount of quote ccy traded on the spot market
    int256 collateral; // Amount of collateral added/removed by this fill
}

struct YieldInstrument {
    uint32 maturity;
    bool closingOnly;
    bytes6 baseId;
    ERC20 base;
    IFYToken baseFyToken;
    IPool basePool;
    bytes6 quoteId;
    ERC20 quote;
    IFYToken quoteFyToken;
    IPool quotePool;
    uint96 minQuoteDebt;
}
