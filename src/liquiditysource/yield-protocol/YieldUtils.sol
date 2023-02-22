//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {IPool} from "@yield-protocol/yieldspace-tv/src/interfaces/IPool.sol";
import "../../libraries/StorageLib.sol";
import "../../libraries/Errors.sol";
import "../../libraries/DataTypes.sol";

import "./YieldStorageLib.sol";

library YieldUtils {
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
        return bytes12(uint96(PositionId.unwrap(positionId)));
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
}
