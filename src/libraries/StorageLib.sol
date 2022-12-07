//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {StorageSlot as StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";
import {DataTypes} from "@yield-protocol/vault-v2/contracts/interfaces/DataTypes.sol";
import {IContangoLadle} from "@yield-protocol/vault-v2/contracts/other/contango/interfaces/IContangoLadle.sol";
import {ICauldron} from "@yield-protocol/vault-v2/contracts/interfaces/ICauldron.sol";

import {IFeeModel} from "../interfaces/IFeeModel.sol";
import {ERC20Lib} from "./ERC20Lib.sol";
import "./ErrorLib.sol";
import "./DataTypes.sol";
import "../ContangoPositionNFT.sol";

// solhint-disable no-inline-assembly
library StorageLib {
    event UniswapFeeUpdated(Symbol indexed symbol, uint24 uniswapFee);
    event FeeModelUpdated(Symbol indexed symbol, IFeeModel feeModel);

    /// @dev Offset for the initial slot in lib storage, gives us this number of storage slots available
    /// Make sure it's different from any other StorageLib
    uint256 private constant STORAGE_SLOT_BASE = 1_000_000;

    /// @dev Storage IDs for storage buckets. Each id maps to an internal storage
    /// slot used for a particular mapping
    ///     WARNING: APPEND ONLY
    enum StorageId {
        Unused, // 0
        PositionBalances, // 1
        PositionNotionals, // 2
        InstrumentFeeModel, // 3
        PositionInstrument, // 4
        Instrument // 5
    }

    /// @dev Mapping from a position id to encoded position balances
    function getPositionBalances() internal pure returns (mapping(PositionId => uint256) storage store) {
        return _getUint256ToUint256Mapping(StorageId.PositionBalances);
    }

    /// @dev Mapping from a position id to encoded position notionals
    function getPositionNotionals() internal pure returns (mapping(PositionId => uint256) storage store) {
        return _getUint256ToUint256Mapping(StorageId.PositionNotionals);
    }

    /// @dev Mapping from an instrument symbol to a fee model
    function getInstrumentFeeModel() internal pure returns (mapping(Symbol => IFeeModel) storage store) {
        uint256 slot = getStorageSlot(StorageId.InstrumentFeeModel);
        assembly {
            store.slot := slot
        }
    }

    /// @dev Mapping from a position id to a fee model
    function getInstrumentFeeModel(PositionId positionId) internal view returns (IFeeModel) {
        return getInstrumentFeeModel()[getPositionInstrument()[positionId]];
    }

    /// @dev Mapping from a position id to an instrument symbol
    function getPositionInstrument() internal pure returns (mapping(PositionId => Symbol) storage store) {
        uint256 slot = getStorageSlot(StorageId.PositionInstrument);
        assembly {
            store.slot := slot
        }
    }

    /// @dev Mapping from an instrument symbol to an instrument
    function getInstruments() internal pure returns (mapping(Symbol => Instrument) storage store) {
        uint256 slot = getStorageSlot(StorageId.Instrument);
        assembly {
            store.slot := slot
        }
    }

    function getInstrument(PositionId positionId)
        internal
        view
        returns (Symbol symbol, Instrument storage instrument)
    {
        symbol = StorageLib.getPositionInstrument()[positionId];
        instrument = getInstruments()[symbol];
    }

    function setFeeModel(Symbol symbol, IFeeModel feeModel) internal {
        StorageLib.getInstrumentFeeModel()[symbol] = feeModel;
        emit FeeModelUpdated(symbol, feeModel);
    }

    function setInstrumentUniswapFee(Symbol symbol, uint24 uniswapFee) internal {
        Instrument storage instrument = StorageLib.getInstruments()[symbol];
        if (instrument.uniswapFee == 0) {
            revert InvalidInstrument(symbol);
        }
        instrument.uniswapFee = uniswapFee;
        emit UniswapFeeUpdated(symbol, uniswapFee);
    }

    function _getUint256ToUint256Mapping(StorageId storageId)
        private
        pure
        returns (mapping(PositionId => uint256) storage store)
    {
        uint256 slot = getStorageSlot(storageId);
        assembly {
            store.slot := slot
        }
    }

    /// @dev Get the storage slot given a storage ID.
    /// @param storageId An entry in `StorageId`
    /// @return slot The storage slot.
    function getStorageSlot(StorageId storageId) internal pure returns (uint256 slot) {
        return uint256(storageId) + STORAGE_SLOT_BASE;
    }
}

library YieldStorageLib {
    using SafeCast for uint256;

    /// @dev Offset for the initial slot in lib storage, gives us this number of storage slots available
    /// Make sure it's different from any other StorageLib
    uint256 private constant YIELD_STORAGE_SLOT_BASE = 2_000_000;

    /// @dev Storage IDs for storage buckets. Each id maps to an internal storage
    /// slot used for a particular mapping
    ///     WARNING: APPEND ONLY
    enum YieldStorageId {
        Unused, // 0
        Instruments, // 1
        Joins, // 2
        Ladle, // 3
        Cauldron, // 4
        PoolView // 5
    }

    error InvalidBaseId(Symbol symbol, bytes6 baseId);
    error InvalidQuoteId(Symbol symbol, bytes6 quoteId);
    error MismatchedMaturity(Symbol symbol, bytes6 baseId, uint256 baseMaturity, bytes6 quoteId, uint256 quoteMaturity);

    event YieldInstrumentCreated(Instrument instrument, YieldInstrument yieldInstrument);
    event LadleSet(IContangoLadle ladle);
    event CauldronSet(ICauldron cauldron);

    function getLadle() internal view returns (IContangoLadle) {
        return IContangoLadle(StorageSlot.getAddressSlot(bytes32(getStorageSlot(YieldStorageId.Ladle))).value);
    }

    function setLadle(IContangoLadle ladle) internal {
        StorageSlot.getAddressSlot(bytes32(getStorageSlot(YieldStorageId.Ladle))).value = address(ladle);
        emit LadleSet(ladle);
    }

    function getCauldron() internal view returns (ICauldron) {
        return ICauldron(StorageSlot.getAddressSlot(bytes32(getStorageSlot(YieldStorageId.Cauldron))).value);
    }

    function setCauldron(ICauldron cauldron) internal {
        StorageSlot.getAddressSlot(bytes32(getStorageSlot(YieldStorageId.Cauldron))).value = address(cauldron);
        emit CauldronSet(cauldron);
    }

    /// @dev Mapping from a symbol to instrument
    function getInstruments() internal pure returns (mapping(Symbol => YieldInstrument) storage store) {
        uint256 slot = getStorageSlot(YieldStorageId.Instruments);
        assembly {
            store.slot := slot
        }
    }

    function createInstrument(Symbol symbol, bytes6 baseId, bytes6 quoteId, uint24 uniswapFee, IFeeModel feeModel)
        internal
        returns (Instrument memory instrument, YieldInstrument memory yieldInstrument)
    {
        ICauldron cauldron = getCauldron();
        (DataTypes.Series memory baseSeries, DataTypes.Series memory quoteSeries) =
            _validInstrumentData(cauldron, symbol, baseId, quoteId);

        StorageLib.getInstrumentFeeModel()[symbol] = feeModel;
        IContangoLadle ladle = getLadle();

        (instrument, yieldInstrument) =
            _createInstrument(ladle, cauldron, baseId, quoteId, uniswapFee, baseSeries, quoteSeries);

        getJoins()[yieldInstrument.baseId] = address(ladle.joins(yieldInstrument.baseId));
        getJoins()[yieldInstrument.quoteId] = address(ladle.joins(yieldInstrument.quoteId));

        StorageLib.getInstruments()[symbol] = instrument;
        getInstruments()[symbol] = yieldInstrument;

        emit YieldInstrumentCreated(instrument, yieldInstrument);
    }

    function _createInstrument(
        IContangoLadle ladle,
        ICauldron cauldron,
        bytes6 baseId,
        bytes6 quoteId,
        uint24 uniswapFee,
        DataTypes.Series memory baseSeries,
        DataTypes.Series memory quoteSeries
    ) private view returns (Instrument memory instrument, YieldInstrument memory yieldInstrument) {
        yieldInstrument.baseId = baseId;
        yieldInstrument.quoteId = quoteId;

        yieldInstrument.basePool = IPool(ladle.pools(yieldInstrument.baseId));
        yieldInstrument.quotePool = IPool(ladle.pools(yieldInstrument.quoteId));

        yieldInstrument.baseFyToken = baseSeries.fyToken;
        yieldInstrument.quoteFyToken = quoteSeries.fyToken;

        DataTypes.Debt memory debt = cauldron.debt(quoteSeries.baseId, yieldInstrument.baseId);
        yieldInstrument.minQuoteDebt = debt.min * uint96(10) ** debt.dec;

        instrument.maturity = baseSeries.maturity;
        instrument.uniswapFee = uniswapFee;
        instrument.base = IERC20Metadata(yieldInstrument.baseFyToken.underlying());
        instrument.quote = IERC20Metadata(yieldInstrument.quoteFyToken.underlying());
    }

    function getJoins() internal pure returns (mapping(bytes12 => address) storage store) {
        uint256 slot = getStorageSlot(YieldStorageId.Joins);
        assembly {
            store.slot := slot
        }
    }

    /// @dev Get the storage slot given a storage ID.
    /// @param storageId An entry in `YieldStorageId`
    /// @return slot The storage slot.
    function getStorageSlot(YieldStorageId storageId) internal pure returns (uint256 slot) {
        return uint256(storageId) + YIELD_STORAGE_SLOT_BASE;
    }

    function _validInstrumentData(ICauldron cauldron, Symbol symbol, bytes6 baseId, bytes6 quoteId)
        private
        view
        returns (DataTypes.Series memory baseSeries, DataTypes.Series memory quoteSeries)
    {
        if (StorageLib.getInstruments()[symbol].maturity != 0) {
            revert InstrumentAlreadyExists(symbol);
        }

        baseSeries = cauldron.series(baseId);
        uint256 baseMaturity = baseSeries.maturity;
        if (baseMaturity == 0 || baseMaturity > type(uint32).max) {
            revert InvalidBaseId(symbol, baseId);
        }

        quoteSeries = cauldron.series(quoteId);
        uint256 quoteMaturity = quoteSeries.maturity;
        if (quoteMaturity == 0 || quoteMaturity > type(uint32).max) {
            revert InvalidQuoteId(symbol, quoteId);
        }

        if (baseMaturity != quoteMaturity) {
            revert MismatchedMaturity(symbol, baseId, baseMaturity, quoteId, quoteMaturity);
        }
    }
}

library ConfigStorageLib {
    bytes32 private constant TREASURY = keccak256("ConfigStorageLib.TREASURY");
    bytes32 private constant NFT = keccak256("ConfigStorageLib.NFT");
    bytes32 private constant CLOSING_ONLY = keccak256("ConfigStorageLib.CLOSING_ONLY");
    bytes32 private constant TRUSTED_TOKENS = keccak256("ConfigStorageLib.TRUSTED_TOKENS");
    bytes32 private constant PROXY_HASH = keccak256("ConfigStorageLib.PROXY_HASH");

    event TreasurySet(address treasury);
    event PositionNFTSet(address positionNFT);
    event ClosingOnlySet(bool closingOnly);
    event TokenTrusted(address indexed token, bool trusted);
    event ProxyHashSet(bytes32 proxyHash);

    function getTreasury() internal view returns (address) {
        return StorageSlot.getAddressSlot(TREASURY).value;
    }

    function setTreasury(address treasury) internal {
        StorageSlot.getAddressSlot(TREASURY).value = treasury;
        emit TreasurySet(address(treasury));
    }

    function getPositionNFT() internal view returns (ContangoPositionNFT) {
        return ContangoPositionNFT(StorageSlot.getAddressSlot(NFT).value);
    }

    function setPositionNFT(ContangoPositionNFT nft) internal {
        StorageSlot.getAddressSlot(NFT).value = address(nft);
        emit PositionNFTSet(address(nft));
    }

    function getClosingOnly() internal view returns (bool) {
        return StorageSlot.getBooleanSlot(CLOSING_ONLY).value;
    }

    function setClosingOnly(bool closingOnly) internal {
        StorageSlot.getBooleanSlot(CLOSING_ONLY).value = closingOnly;
        emit ClosingOnlySet(closingOnly);
    }

    function isTrustedToken(address token) internal view returns (bool) {
        return _getAddressToBoolMapping(TRUSTED_TOKENS)[token];
    }

    function setTrustedToken(address token, bool trusted) internal {
        _getAddressToBoolMapping(TRUSTED_TOKENS)[token] = trusted;
        emit TokenTrusted(token, trusted);
    }

    function getProxyHash() internal view returns (bytes32) {
        return StorageSlot.getBytes32Slot(PROXY_HASH).value;
    }

    function setProxyHash(bytes32 proxyHash) internal {
        StorageSlot.getBytes32Slot(PROXY_HASH).value = proxyHash;
        emit ProxyHashSet(proxyHash);
    }

    function _getAddressToBoolMapping(bytes32 slot) private pure returns (mapping(address => bool) storage store) {
        assembly {
            store.slot := slot
        }
    }
}
