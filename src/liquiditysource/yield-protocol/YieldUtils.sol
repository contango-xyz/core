//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {IPool} from "@yield-protocol/yieldspace-tv/src/interfaces/IPool.sol";

import "../../libraries/StorageLib.sol";
import "../../libraries/Errors.sol";
import "../../libraries/DataTypes.sol";

import "./YieldStorageLib.sol";

library YieldUtils {
    using SafeCast for *;

    error PositionIdTooLarge(PositionId positionId);

    function loadInstrument(Symbol symbol)
        internal
        view
        returns (InstrumentStorage storage instrument, YieldInstrumentStorage storage yieldInstrument)
    {
        instrument = StorageLib.getInstruments()[symbol];
        if (instrument.maturity == 0) {
            revert InvalidInstrument(symbol);
        }
        yieldInstrument = YieldStorageLib.getInstruments()[symbol];
    }

    function toVaultId(PositionId positionId) internal pure returns (bytes12) {
        // position id limit because uint48.max is added to it when using baseVaultId
        if (PositionId.unwrap(positionId) > type(uint48).max) {
            // realistically unlikely to hit this limit because 2^48 is 281+ trillion
            revert PositionIdTooLarge(positionId);
        }
        return bytes12(uint96(PositionId.unwrap(positionId)));
    }

    function toBaseVaultId(PositionId positionId) internal pure returns (bytes12) {
        return bytes12(uint96(PositionId.unwrap(positionId)) + type(uint48).max);
    }

    function buyFYTokenPreviewFixed(IPool pool, uint128 fyTokenOut) internal view returns (uint128 baseIn) {
        baseIn = buyFYTokenPreviewZero(pool, fyTokenOut);
        // Math is not exact anymore with the PoolEuler, so we need to transfer a bit more to the pool
        baseIn = baseIn == 0 ? 0 : baseIn + 1;
    }

    function buyFYTokenPreviewZero(IPool pool, uint128 fyTokenOut) internal view returns (uint128 baseIn) {
        baseIn = fyTokenOut == 0 ? 0 : pool.buyFYTokenPreview(fyTokenOut);
    }

    function sellBasePreviewZero(IPool pool, uint128 baseIn) internal view returns (uint128 fyTokenOut) {
        fyTokenOut = baseIn == 0 ? 0 : pool.sellBasePreview(baseIn);
    }

    function sellFYTokenPreviewZero(IPool pool, uint128 fyTokenIn) internal view returns (uint128 baseOut) {
        baseOut = fyTokenIn == 0 ? 0 : pool.sellFYTokenPreview(fyTokenIn);
    }

    function closeLendingPositionPreview(ICauldron cauldron, IPool basePool, PositionId positionId, uint256 quantity)
        internal
        view
        returns (uint256 baseToSell)
    {
        uint256 amountToUnwrap = baseToSell = Math.min(quantity, cauldron.balances(toBaseVaultId(positionId)).ink);
        uint256 fyTokenToSell = quantity - amountToUnwrap;
        if (fyTokenToSell > 0) {
            baseToSell += basePool.sellFYTokenPreview(fyTokenToSell.toUint128());
        }
    }
}
