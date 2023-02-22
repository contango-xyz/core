//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "solmate/src/tokens/WETH.sol";
import {IContangoLadle} from "@yield-protocol/vault-v2/contracts/other/contango/interfaces/IContangoLadle.sol";
import "@yield-protocol/vault-v2/contracts/other/contango/interfaces/IContangoWitchListener.sol";

import "./interfaces/IContangoYield.sol";
import "./interfaces/IContangoYieldAdmin.sol";
import "./Yield.sol";
import "./YieldUtils.sol";

import "../ContangoBase.sol";

/// @notice Contract that acts as the main entry point to the protocol with yield-protocol as the underlying
/// @dev This is the main entry point to the system when using yield-protocol as the underlying
contract ContangoYield is ContangoBase, IContangoWitchListener, IContangoYield, IContangoYieldAdmin {
    using SafeCast for uint256;
    using YieldUtils for Symbol;

    bytes32 public constant WITCH = keccak256("WITCH");

    // solhint-disable-next-line no-empty-blocks
    constructor(WETH _weth) ContangoBase(_weth) {}

    function initialize(ContangoPositionNFT _positionNFT, address _treasury, IContangoLadle _ladle)
        public
        initializer
    {
        __ContangoBase_init(_positionNFT, _treasury);

        YieldStorageLib.setLadle(_ladle);
        emit LadleSet(_ladle);

        ICauldron cauldron = _ladle.cauldron();
        YieldStorageLib.setCauldron(cauldron);
        emit CauldronSet(cauldron);
    }

    // ============================================== Trading functions ==============================================

    /// @inheritdoc IContango
    function createPosition(
        Symbol symbol,
        address trader,
        uint256 quantity,
        uint256 limitCost,
        uint256 collateral,
        address payer,
        uint256 lendingLiquidity,
        uint24 uniswapFee
    )
        external
        payable
        override
        nonReentrant
        whenNotPaused
        whenNotClosingOnly(quantity.toInt256())
        returns (PositionId)
    {
        return
            Yield.createPosition(symbol, trader, quantity, limitCost, collateral, payer, lendingLiquidity, uniswapFee);
    }

    /// @inheritdoc IContango
    function modifyCollateral(
        PositionId positionId,
        int256 collateral,
        uint256 slippageTolerance,
        address payerOrReceiver,
        uint256 lendingLiquidity
    ) external payable override nonReentrant whenNotPaused {
        Yield.modifyCollateral(positionId, collateral, slippageTolerance, payerOrReceiver, lendingLiquidity);
    }

    /// @inheritdoc IContango
    function modifyPosition(
        PositionId positionId,
        int256 quantity,
        uint256 limitCost,
        int256 collateral,
        address payerOrReceiver,
        uint256 lendingLiquidity,
        uint24 uniswapFee
    ) external payable override nonReentrant whenNotPaused whenNotClosingOnly(quantity) {
        Yield.modifyPosition(positionId, quantity, limitCost, collateral, payerOrReceiver, lendingLiquidity, uniswapFee);
    }

    /// @inheritdoc IContango
    function deliver(PositionId positionId, address payer, address to)
        external
        payable
        override
        nonReentrant
        whenNotPaused
    {
        Yield.deliver(positionId, payer, to);
    }

    // ============================================== Callback functions ==============================================

    // solhint-disable-next-line no-empty-blocks
    function auctionStarted(bytes12 vaultId) external override {}

    function collateralBought(bytes12 vaultId, address, uint256 ink, uint256 art)
        external
        override
        nonReentrant
        onlyRole(WITCH)
    {
        Yield.collateralBought(vaultId, ink, art);
    }

    // solhint-disable-next-line no-empty-blocks
    function auctionEnded(bytes12 vaultId, address owner) external override {}

    /// @inheritdoc IUniswapV3SwapCallback
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external override {
        Yield.uniswapV3SwapCallback(amount0Delta, amount1Delta, data);
    }

    // ============================================== Yield specific functions ==============================================

    function createYieldInstrumentV2(Symbol _symbol, bytes6 _baseId, bytes6 _quoteId, IFeeModel _feeModel)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (YieldInstrument memory instrument)
    {
        ICauldron cauldron = YieldStorageLib.getCauldron();
        (DataTypes.Series memory baseSeries, DataTypes.Series memory quoteSeries) =
            _validInstrumentData(cauldron, _symbol, _baseId, _quoteId);

        StorageLib.getInstrumentFeeModel()[_symbol] = _feeModel;
        IContangoLadle ladle = YieldStorageLib.getLadle();

        (InstrumentStorage memory instrumentStorage, YieldInstrumentStorage memory yieldInstrumentStorage) =
            _createInstrument(ladle, cauldron, _baseId, _quoteId, baseSeries, quoteSeries);

        YieldStorageLib.getJoins()[yieldInstrumentStorage.baseId] = address(ladle.joins(yieldInstrumentStorage.baseId));
        YieldStorageLib.getJoins()[yieldInstrumentStorage.quoteId] =
            address(ladle.joins(yieldInstrumentStorage.quoteId));

        StorageLib.getInstruments()[_symbol] = instrumentStorage;
        YieldStorageLib.getInstruments()[_symbol] = yieldInstrumentStorage;

        instrument = _yieldInstrument(instrumentStorage, yieldInstrumentStorage);
        emitInstrumentCreatedEvent(_symbol, instrument);
    }

    function _yieldInstrument(
        InstrumentStorage memory instrumentStorage,
        YieldInstrumentStorage memory yieldInstrumentStorage
    ) private pure returns (YieldInstrument memory) {
        return YieldInstrument({
            maturity: instrumentStorage.maturity,
            closingOnly: instrumentStorage.closingOnly,
            base: instrumentStorage.base,
            baseId: yieldInstrumentStorage.baseId,
            baseFyToken: yieldInstrumentStorage.baseFyToken,
            basePool: yieldInstrumentStorage.basePool,
            quote: instrumentStorage.quote,
            quoteId: yieldInstrumentStorage.quoteId,
            quoteFyToken: yieldInstrumentStorage.quoteFyToken,
            quotePool: yieldInstrumentStorage.quotePool,
            minQuoteDebt: yieldInstrumentStorage.minQuoteDebt
        });
    }

    function emitInstrumentCreatedEvent(Symbol symbol, YieldInstrument memory instrument) private {
        emit YieldInstrumentCreatedV2({
            symbol: symbol,
            maturity: instrument.maturity,
            baseId: instrument.baseId,
            base: instrument.base,
            baseFyToken: instrument.baseFyToken,
            quoteId: instrument.quoteId,
            quote: instrument.quote,
            quoteFyToken: instrument.quoteFyToken,
            basePool: instrument.basePool,
            quotePool: instrument.quotePool
        });
    }

    function _createInstrument(
        IContangoLadle ladle,
        ICauldron cauldron,
        bytes6 baseId,
        bytes6 quoteId,
        DataTypes.Series memory baseSeries,
        DataTypes.Series memory quoteSeries
    ) private view returns (InstrumentStorage memory instrument_, YieldInstrumentStorage memory yieldInstrument_) {
        yieldInstrument_.baseId = baseId;
        yieldInstrument_.quoteId = quoteId;

        yieldInstrument_.basePool = IPool(ladle.pools(yieldInstrument_.baseId));
        yieldInstrument_.quotePool = IPool(ladle.pools(yieldInstrument_.quoteId));

        yieldInstrument_.baseFyToken = baseSeries.fyToken;
        yieldInstrument_.quoteFyToken = quoteSeries.fyToken;

        DataTypes.Debt memory debt = cauldron.debt(quoteSeries.baseId, yieldInstrument_.baseId);
        yieldInstrument_.minQuoteDebt = debt.min * uint96(10) ** debt.dec;

        instrument_.maturity = baseSeries.maturity;
        instrument_.base = ERC20(yieldInstrument_.baseFyToken.underlying());
        instrument_.quote = ERC20(yieldInstrument_.quoteFyToken.underlying());
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

    function yieldInstrumentV2(Symbol symbol) external view override returns (YieldInstrument memory) {
        (InstrumentStorage memory instrumentStorage, YieldInstrumentStorage memory yieldInstrumentStorage) =
            symbol.loadInstrument();
        return _yieldInstrument(instrumentStorage, yieldInstrumentStorage);
    }
}
