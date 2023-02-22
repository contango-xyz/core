//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "solmate/src/tokens/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/SignedMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import {IQuoter} from "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";
import {DataTypes} from "@yield-protocol/vault-v2/contracts/interfaces/DataTypes.sol";
import {ICauldron} from "@yield-protocol/vault-v2/contracts/interfaces/ICauldron.sol";

import "../../libraries/CodecLib.sol";
import "../../ContangoPositionNFT.sol";
import "../../interfaces/IContangoQuoter.sol";
import "../../libraries/QuoterDataTypes.sol";
import "../../libraries/Errors.sol";
import "../../libraries/QuoterLib.sol";
import "./YieldUtils.sol";
import "./YieldQuoterUtils.sol";
import "./interfaces/IContangoYield.sol";

/// @title Contract for quoting position operations
contract ContangoYieldQuoter is IContangoQuoter {
    using SafeCast for uint256;
    using SafeCast for int256;
    using SignedMath for int256;
    using CodecLib for uint256;
    using QuoterLib for IQuoter;
    using YieldUtils for *;
    using YieldQuoterUtils for *;

    ContangoPositionNFT public immutable positionNFT;
    IContangoYield public immutable contangoYield;
    ICauldron public immutable cauldron;
    IQuoter public immutable quoter;
    int256 private collateralSlippage;
    uint128 private maxAvailableDebt;

    constructor(ContangoPositionNFT _positionNFT, IContangoYield _contangoYield, ICauldron _cauldron, IQuoter _quoter) {
        positionNFT = _positionNFT;
        contangoYield = _contangoYield;
        cauldron = _cauldron;
        quoter = _quoter;
    }

    /// @inheritdoc IContangoQuoter
    function positionStatus(PositionId positionId, uint24 uniswapFee)
        external
        override
        returns (PositionStatus memory result)
    {
        (, YieldInstrument memory instrument) = _validatePosition(positionId);
        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());

        result = _positionStatus(balances, instrument, uniswapFee);

        result.liquidating = cauldron.vaults(positionId.toVaultId()).owner != address(contangoYield);
    }

    /// @inheritdoc IContangoQuoter
    function modifyCostForPositionWithCollateral(ModifyCostParams calldata params, int256 collateral)
        external
        override
        returns (ModifyCostResult memory result)
    {
        result = _modifyCostForPosition(params, collateral, 0);
    }

    /// @inheritdoc IContangoQuoter
    function modifyCostForPositionWithLeverage(ModifyCostParams calldata params, uint256 leverage)
        external
        override
        returns (ModifyCostResult memory result)
    {
        result = _modifyCostForPosition(params, 0, leverage);
    }

    /// @inheritdoc IContangoQuoter
    function openingCostForPositionWithCollateral(OpeningCostParams calldata params, uint256 collateral)
        external
        override
        returns (ModifyCostResult memory result)
    {
        result = _openingCostForPosition(params, collateral, 0);
    }

    /// @inheritdoc IContangoQuoter
    function openingCostForPositionWithLeverage(OpeningCostParams calldata params, uint256 leverage)
        external
        override
        returns (ModifyCostResult memory result)
    {
        result = _openingCostForPosition(params, 0, leverage);
    }

    /// @inheritdoc IContangoQuoter
    function deliveryCostForPosition(PositionId positionId) external override returns (uint256) {
        (Position memory position, YieldInstrument memory instrument) = _validateExpiredPosition(positionId);
        DataTypes.Balances memory balances = cauldron.balances(positionId.toVaultId());

        return _deliveryCostForPosition(balances, instrument, position);
    }

    // ============================================== private functions ==============================================

    function _openingCostForPosition(OpeningCostParams calldata params, uint256 collateral, uint256 leverage)
        private
        returns (ModifyCostResult memory result)
    {
        YieldInstrument memory instrument = _instrument(params.symbol);

        _checkClosingOnly(params.symbol, instrument);

        result = _modifyCostForLongPosition(
            DataTypes.Balances({art: 0, ink: 0}),
            instrument,
            int256(params.quantity),
            int256(collateral),
            params.collateralSlippage,
            leverage,
            params.uniswapFee
        );

        result.fee = QuoterLib.fee(contangoYield, positionNFT, PositionId.wrap(0), params.symbol, result.cost.abs());
    }

    function _modifyCostForPosition(ModifyCostParams calldata params, int256 collateral, uint256 leverage)
        private
        returns (ModifyCostResult memory result)
    {
        (Position memory position, YieldInstrument memory instrument) = _validateActivePosition(params.positionId);
        DataTypes.Balances memory balances = cauldron.balances(params.positionId.toVaultId());

        if (params.quantity > 0) {
            _checkClosingOnly(position.symbol, instrument);
        }

        result = _modifyCostForLongPosition(
            balances, instrument, params.quantity, collateral, params.collateralSlippage, leverage, params.uniswapFee
        );
        if (result.needsBatchedCall || params.quantity == 0) {
            uint256 aggregateCost = (result.cost + result.financingCost).abs() + result.debtDelta.abs();
            result.fee = QuoterLib.fee(contangoYield, positionNFT, params.positionId, position.symbol, aggregateCost);
        } else {
            result.fee =
                QuoterLib.fee(contangoYield, positionNFT, params.positionId, position.symbol, result.cost.abs());
        }
    }

    function _checkClosingOnly(Symbol symbol, YieldInstrument memory instrument) private view {
        if (contangoYield.closingOnly()) {
            revert ClosingOnly();
        }
        if (instrument.closingOnly) {
            revert InstrumentClosingOnly(symbol);
        }
    }

    function _positionStatus(DataTypes.Balances memory balances, YieldInstrument memory instrument, uint24 uniswapFee)
        internal
        returns (PositionStatus memory result)
    {
        result.spotCost =
            quoter.spot(address(instrument.base), address(instrument.quote), int128(balances.ink), uniswapFee);
        result.underlyingDebt = balances.art;

        DataTypes.Series memory series = cauldron.series(instrument.quoteId);
        DataTypes.SpotOracle memory spotOracle = cauldron.spotOracles(series.baseId, instrument.baseId);

        (result.underlyingCollateral,) = spotOracle.oracle.get(instrument.baseId, series.baseId, balances.ink);
        result.liquidationRatio = uint256(spotOracle.ratio);
    }

    function _modifyCostForLongPosition(
        DataTypes.Balances memory balances,
        YieldInstrument memory instrument,
        int256 quantity,
        int256 collateral,
        uint256 _collateralSlippage,
        uint256 leverage,
        uint24 uniswapFee
    ) internal returns (ModifyCostResult memory result) {
        collateralSlippage = 1e18 + int256(_collateralSlippage);
        result.minDebt = instrument.minQuoteDebt;
        DataTypes.Series memory series = cauldron.series(instrument.quoteId);
        DataTypes.Debt memory debt = cauldron.debt(series.baseId, instrument.baseId);
        maxAvailableDebt = uint128(debt.max * (10 ** debt.dec)) - debt.sum;
        _evaluateLiquidity(instrument, balances, result, quantity, collateral);

        if (!result.insufficientLiquidity) {
            _assignLiquidity(instrument, balances, result, quantity, collateral);

            if (quantity >= 0) {
                _increasingCostForLongPosition(
                    result, balances, series, instrument, quantity.toUint256(), collateral, leverage, uniswapFee
                );
            } else {
                _closingCostForLongPosition(
                    result, balances, series, instrument, quantity.abs(), collateral, leverage, uniswapFee
                );
            }
        }
    }

    // **** NEW **** //
    function _increasingCostForLongPosition(
        ModifyCostResult memory result,
        DataTypes.Balances memory balances,
        DataTypes.Series memory series,
        YieldInstrument memory instrument,
        uint256 quantity,
        int256 collateral,
        uint256 leverage,
        uint24 uniswapFee
    ) private {
        uint256 hedge;
        int256 quoteQty;

        if (quantity > 0) {
            hedge = instrument.basePool.buyFYTokenPreview.orMint(quantity.toUint128(), result.baseLendingLiquidity);
            quoteQty =
                -int256(quoter.spot(address(instrument.base), address(instrument.quote), -int256(hedge), uniswapFee));
            result.spotCost =
                -int256(quoter.spot(address(instrument.base), address(instrument.quote), -int256(quantity), uniswapFee));
        }

        DataTypes.SpotOracle memory spotOracle = cauldron.spotOracles(series.baseId, instrument.baseId);
        (result.underlyingCollateral,) =
            spotOracle.oracle.get(instrument.baseId, series.baseId, balances.ink + quantity); // ink * spot
        result.liquidationRatio = uint256(spotOracle.ratio);

        _calculateMinCollateral(balances, instrument, result, quoteQty);
        _calculateMaxCollateral(balances, instrument, result, quoteQty);
        _assignCollateralUsed(instrument, balances, result, collateral, leverage, quoteQty);
        _calculateCost(balances, instrument, result, quoteQty);
    }

    /// @notice Quotes the bid rate, the base/quote are derived from the positionId
    // **** NEW **** //
    function _closingCostForLongPosition(
        ModifyCostResult memory result,
        DataTypes.Balances memory balances,
        DataTypes.Series memory series,
        YieldInstrument memory instrument,
        uint256 quantity,
        int256 collateral,
        uint256 leverage,
        uint24 uniswapFee
    ) private {
        uint256 amountRealBaseReceivedFromSellingLendingPosition =
            instrument.basePool.sellFYTokenPreview(quantity.toUint128());

        result.spotCost =
            int256(quoter.spot(address(instrument.base), address(instrument.quote), int256(quantity), uniswapFee));
        int256 hedgeCost = int256(
            quoter.spot(
                address(instrument.base),
                address(instrument.quote),
                int256(amountRealBaseReceivedFromSellingLendingPosition),
                uniswapFee
            )
        );

        DataTypes.SpotOracle memory spotOracle = cauldron.spotOracles(series.baseId, instrument.baseId);
        result.liquidationRatio = uint256(spotOracle.ratio);

        if (balances.ink == quantity) {
            uint256 costRecovered;
            if (balances.art != 0) {
                costRecovered = balances.art
                    - instrument.quotePool.buyFYTokenPreview.orMint(balances.art, result.quoteLendingLiquidity);
            }
            result.cost = hedgeCost + int256(costRecovered);
        } else {
            (result.underlyingCollateral,) =
                spotOracle.oracle.get(instrument.baseId, series.baseId, balances.ink - quantity);
            _calculateMinCollateral(balances, instrument, result, hedgeCost);
            _calculateMaxCollateral(balances, instrument, result, hedgeCost);
            _assignCollateralUsed(instrument, balances, result, collateral, leverage, hedgeCost);
            _calculateCost(balances, instrument, result, hedgeCost);
        }
    }

    function _calculateMinCollateral(
        DataTypes.Balances memory balances,
        YieldInstrument memory instrument,
        ModifyCostResult memory result,
        int256 spotCost
    ) private view {
        uint128 maxDebtAfterModify = ((result.underlyingCollateral * 1e6) / result.liquidationRatio).toUint128();

        if (balances.art < maxDebtAfterModify) {
            uint128 diff = maxDebtAfterModify - balances.art;
            uint128 maxBorrowableAmount = uint128(Math.min(instrument.quotePool.maxFYTokenIn.cap(), maxAvailableDebt));
            uint256 refinancingRoomPV =
                instrument.quotePool.sellFYTokenPreview(diff > maxBorrowableAmount ? maxBorrowableAmount : diff);
            result.minCollateral -= spotCost + int256(refinancingRoomPV);
        }

        if (balances.art > maxDebtAfterModify) {
            uint128 diff = balances.art - maxDebtAfterModify;
            uint256 minDebtThatHasToBeBurnedPV = instrument.quotePool.buyFYTokenPreview.orMint(diff);

            result.minCollateral = int256(minDebtThatHasToBeBurnedPV) - spotCost;
        }

        if (collateralSlippage != 1e18) {
            result.minCollateral = result.minCollateral > 0
                ? SignedMath.min((result.minCollateral * collateralSlippage) / 1e18, -spotCost)
                : (result.minCollateral * 1e18) / collateralSlippage;
        }
    }

    function _calculateMaxCollateral(
        DataTypes.Balances memory balances,
        YieldInstrument memory instrument,
        ModifyCostResult memory result,
        int256 spotCost
    ) private view {
        // this covers the case where there is no existing debt, which applies to new positions or fully liquidated positions
        if (balances.art == 0) {
            uint256 minDebtPV = instrument.quotePool.sellFYTokenPreview(result.minDebt);
            result.maxCollateral = int256(spotCost.abs()) - int256(minDebtPV);
        } else {
            uint128 maxDebtThatCanBeBurned = balances.art - result.minDebt;
            uint256 maxDebtThatCanBeBurnedPV = instrument.quotePool.buyFYTokenPreview.orMint(maxDebtThatCanBeBurned);
            result.maxCollateral = int256(maxDebtThatCanBeBurnedPV) - spotCost;
        }

        if (collateralSlippage != 1e18) {
            result.maxCollateral = result.maxCollateral < 0
                ? (result.maxCollateral * collateralSlippage) / 1e18
                : (result.maxCollateral * 1e18) / collateralSlippage;
        }
    }

    // NEEDS BATCHED CALL
    // * decrease and withdraw more than we get from spot
    // * decrease and post at the same time SUPPORTED
    // * increase and withdraw at the same time ???
    // * increase and post more than what we need to pay the spot

    function _calculateCost(
        DataTypes.Balances memory balances,
        YieldInstrument memory instrument,
        ModifyCostResult memory result,
        int256 spotCost
    ) private view {
        int256 quoteUsedToRepayDebt = result.collateralUsed + spotCost;
        result.underlyingDebt = balances.art;
        uint128 debtDelta128;

        if (quoteUsedToRepayDebt > 0) {
            debtDelta128 = instrument.quotePool.sellBasePreview.orMint(uint128(uint256(quoteUsedToRepayDebt)));
            result.debtDelta = -int128(debtDelta128);
            result.underlyingDebt -= debtDelta128;
            if (spotCost < 0) {
                // this means we're increasing, and posting more than what we need to pay the spot
                result.needsBatchedCall = true;
            }
        }
        if (quoteUsedToRepayDebt < 0) {
            debtDelta128 = instrument.quotePool.buyBasePreview(quoteUsedToRepayDebt.abs().toUint128());
            result.debtDelta = int128(debtDelta128);
            result.underlyingDebt += debtDelta128;
            if (spotCost > 0) {
                // this means that we're decreasing, and withdrawing more than we get from the spot
                result.needsBatchedCall = true;
            }
        }
        result.financingCost = result.debtDelta + quoteUsedToRepayDebt;
        result.cost -= result.collateralUsed + result.debtDelta;
    }

    function _assignLiquidity(
        YieldInstrument memory instrument,
        DataTypes.Balances memory balances,
        ModifyCostResult memory result,
        int256 quantity,
        int256 collateral
    ) private view {
        // Opening / Increasing
        if (quantity > 0) {
            result.baseLendingLiquidity = instrument.basePool.maxFYTokenOut.cap();
        }

        // Add collateral
        if (balances.art != 0 && collateral > 0) {
            result.quoteLendingLiquidity = instrument.quotePool.maxBaseIn.cap();
        }

        // Decrease position
        if (quantity < 0) {
            result.quoteLendingLiquidity = instrument.quotePool.maxBaseIn.cap();
        }

        // Close position
        if (quantity == -int128(balances.ink)) {
            result.quoteLendingLiquidity = instrument.quotePool.maxFYTokenOut.cap();
        }
    }

    function _evaluateLiquidity(
        YieldInstrument memory instrument,
        DataTypes.Balances memory balances,
        ModifyCostResult memory result,
        int256 quantity,
        int256 collateral
    ) private view {
        // If we're opening a new position
        if (balances.art == 0 && quantity > 0) {
            result.insufficientLiquidity =
                Math.min(instrument.quotePool.maxFYTokenIn.cap(), maxAvailableDebt) < result.minDebt;
        }

        // If we're withdrawing from a position
        if (quantity == 0 && collateral < 0) {
            result.insufficientLiquidity = instrument.quotePool.maxBaseOut.cap() < collateral.abs();
        }

        // If we're reducing a position
        if (quantity < 0) {
            result.insufficientLiquidity = instrument.basePool.maxFYTokenIn.cap() < quantity.abs();
        }
    }

    function _assignCollateralUsed(
        YieldInstrument memory instrument,
        DataTypes.Balances memory balances,
        ModifyCostResult memory result,
        int256 collateral,
        uint256 leverage,
        int256 hedgeCost
    ) private view {
        collateral =
            leverage > 0 ? _deriveCollateralFromLeverage(instrument, balances, result, leverage, hedgeCost) : collateral;

        // if 'collateral' is above the max, use result.maxCollateral
        result.collateralUsed = SignedMath.min(collateral, result.maxCollateral);
        // if result.collateralUsed is lower than max, but still lower than the min, use the min
        result.collateralUsed = SignedMath.max(result.minCollateral, result.collateralUsed);
    }

    // leverage = 1 / ((underlyingCollateral - underlyingDebt) / underlyingCollateral)
    // leverage = underlyingCollateral / (underlyingCollateral - underlyingDebt)
    // underlyingDebt = -underlyingCollateral / leverage + underlyingCollateral
    // collateral = hedgeCost - underlyingDebtPV
    function _deriveCollateralFromLeverage(
        YieldInstrument memory instrument,
        DataTypes.Balances memory balances,
        ModifyCostResult memory result,
        uint256 leverage,
        int256 hedgeCost
    ) internal view returns (int256 collateral) {
        uint256 debtFV = (
            ((-int256(result.underlyingCollateral) * 1e18) / int256(leverage)) + int256(result.underlyingCollateral)
        ).toUint256();

        int256 debtPV;

        if (debtFV > balances.art) {
            // Debt needs to increase to reach the desired leverage
            debtPV = -int128(instrument.quotePool.sellFYTokenPreview(debtFV.toUint128() - balances.art));
        } else {
            // Debt needs to be burnt to reach the desired leverage
            debtPV = int128(instrument.quotePool.buyFYTokenPreview.orMint(balances.art - debtFV.toUint128()));
        }

        collateral = debtPV - hedgeCost;
    }

    function _deliveryCostForPosition(
        DataTypes.Balances memory balances,
        YieldInstrument memory instrument,
        Position memory position
    ) internal returns (uint256) {
        return cauldron.debtToBase(instrument.quoteId, balances.art) + position.protocolFees;
    }

    function _validatePosition(PositionId positionId)
        private
        view
        returns (Position memory position, YieldInstrument memory instrument)
    {
        position = contangoYield.position(positionId);
        if (position.openQuantity == 0 && position.openCost == 0) {
            if (position.collateral <= 0) {
                revert InvalidPosition(positionId);
            }
        }
        instrument = _instrument(position.symbol);
    }

    function _validateActivePosition(PositionId positionId)
        private
        view
        returns (Position memory position, YieldInstrument memory instrument)
    {
        (position, instrument) = _validatePosition(positionId);

        // solhint-disable-next-line not-rely-on-time
        uint256 timestamp = block.timestamp;
        if (instrument.maturity <= timestamp) {
            revert PositionExpired(positionId, instrument.maturity, timestamp);
        }
    }

    function _validateExpiredPosition(PositionId positionId)
        private
        view
        returns (Position memory position, YieldInstrument memory instrument)
    {
        (position, instrument) = _validatePosition(positionId);

        // solhint-disable-next-line not-rely-on-time
        uint256 timestamp = block.timestamp;
        if (instrument.maturity > timestamp) {
            revert PositionActive(positionId, instrument.maturity, timestamp);
        }
    }

    function _instrument(Symbol symbol) private view returns (YieldInstrument memory) {
        return contangoYield.yieldInstrumentV2(symbol);
    }

    receive() external payable {
        revert ViewOnly();
    }
}
