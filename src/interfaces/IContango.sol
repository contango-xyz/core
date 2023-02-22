//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./IContangoView.sol";

uint256 constant MIN_DEBT_MULTIPLIER = 5;

interface IContangoEvents {
    /// @dev due to solidity technical limitations, the actual events are declared again where they are emitted, e.g. ExecutionProcessorLib

    event PositionUpserted(
        Symbol indexed symbol,
        address indexed trader,
        PositionId indexed positionId,
        uint256 openQuantity,
        uint256 openCost,
        int256 collateral,
        uint256 totalFees,
        uint256 txFees,
        int256 realisedPnL
    );

    event PositionLiquidated(
        Symbol indexed symbol,
        address indexed trader,
        PositionId indexed positionId,
        uint256 openQuantity,
        uint256 openCost,
        int256 collateral,
        int256 realisedPnL
    );

    event PositionClosed(
        Symbol indexed symbol,
        address indexed trader,
        PositionId indexed positionId,
        uint256 closedQuantity,
        uint256 closedCost,
        int256 collateral,
        uint256 totalFees,
        uint256 txFees,
        int256 realisedPnL
    );

    event PositionDelivered(
        Symbol indexed symbol,
        address indexed trader,
        PositionId indexed positionId,
        address to,
        uint256 deliveredQuantity,
        uint256 deliveryCost,
        uint256 totalFees
    );

    event ContractBought(
        Symbol indexed symbol,
        address indexed trader,
        PositionId indexed positionId,
        uint256 size,
        uint256 cost,
        uint256 hedgeSize,
        uint256 hedgeCost,
        int256 collateral
    );
    event ContractSold(
        Symbol indexed symbol,
        address indexed trader,
        PositionId indexed positionId,
        uint256 size,
        uint256 cost,
        uint256 hedgeSize,
        uint256 hedgeCost,
        int256 collateral
    );

    event CollateralAdded(
        Symbol indexed symbol, address indexed trader, PositionId indexed positionId, uint256 amount, uint256 cost
    );
    event CollateralRemoved(
        Symbol indexed symbol, address indexed trader, PositionId indexed positionId, uint256 amount, uint256 cost
    );
}

/// @title Interface to allow for position management
interface IContango is IContangoView, IContangoEvents {
    // ====================================== Errors ======================================

    /// @dev when opening/modifying position, if resulting cost is less than min debt * MIN_DEBT_MULTIPLIER
    error PositionIsTooSmall(uint256 openCost, uint256 minCost);

    // ====================================== Functions ======================================

    /// @notice Creates a new position in the system by performing a trade of `quantity` at `limitCost` with `collateral`
    /// @param symbol Symbol of the instrument to be traded
    /// @param trader Which address will own the position
    /// @param quantity Desired position size. Always expressed in base currency, can't be zero
    /// @param limitCost The worst price the user is willing to accept (slippage). Always expressed in quote currency
    /// @param collateral Amount the user will post to secure the leveraged trade. Always expressed in quote currency
    /// @param payer Which address will post the `collateral`
    /// @param lendingLiquidity Liquidity for the lending leg, we'll mint tokens 1:1 if said liquidity is not enough
    /// @param uniswapFee The fee (pool) to be used for the trade
    /// @return positionId Id of the newly created position
    function createPosition(
        Symbol symbol,
        address trader,
        uint256 quantity,
        uint256 limitCost,
        uint256 collateral,
        address payer,
        uint256 lendingLiquidity,
        uint24 uniswapFee
    ) external payable returns (PositionId positionId);

    /// @notice Modifies an existing position, changing its size & collateral (optional)
    /// @param positionId the id of an exiting position, the caller of this method must be its owner
    /// @param quantity Quantity to be increased (> 0) or decreased (< 0). Always expressed in base currency, can't be zero
    /// @param limitCost The worst price the user is willing to accept (slippage). Always expressed in quote currency
    /// @param collateral < 0 ? How much equity should be sent to `payerOrReceiver` : How much collateral will be taken from `payerOrReceiver` and added to the position
    /// @param payerOrReceiver Which address will receive the funds if `collateral` > 0, or which address will pay for them if `collateral` > 0
    /// @param lendingLiquidity Deals with low liquidity, when decreasing, pay debt 1:1, when increasing lend tokens 1:1
    /// @param uniswapFee The fee (pool) to be used for the trade
    function modifyPosition(
        PositionId positionId,
        int256 quantity,
        uint256 limitCost,
        int256 collateral,
        address payerOrReceiver,
        uint256 lendingLiquidity,
        uint24 uniswapFee
    ) external payable;

    /// @notice Modifies an existing position, adding or removing collateral
    /// @param positionId the id of an exiting position, the caller of this method must be its owner
    /// @param collateral < 0 ? How much equity should be sent to `payerOrReceiver` : How much collateral will be taken from `payerOrReceiver` and added to the position
    /// @param slippageTolerance the min/max amount the trader is willing to receive/pay
    /// @param payerOrReceiver Which address will pay/receive the `collateral`
    /// @param lendingLiquidity Liquidity for the lending leg, we'll mint tokens 1:1 if said liquidity is not enough. Ignored if `collateral` < 0
    function modifyCollateral(
        PositionId positionId,
        int256 collateral,
        uint256 slippageTolerance,
        address payerOrReceiver,
        uint256 lendingLiquidity
    ) external payable;

    /// @notice Delivers an expired position by receiving the remaining payment for the leveraged position and physically delivering it
    /// @param positionId the id of an expired position, the caller of this method must be its owner
    /// @param payer Which address will pay for the remaining cost
    /// @param to Which address will receive the base currency
    function deliver(PositionId positionId, address payer, address to) external payable;
}
