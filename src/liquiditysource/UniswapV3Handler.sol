//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/SignedMath.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "../libraries/StorageDataTypes.sol";
import "../dependencies/Uniswap.sol";

library UniswapV3Handler {
    using Address for address;
    using SafeCast for uint256;
    using SignedMath for int256;
    using PoolAddress for address;

    error InvalidAmountDeltas(int256 amount0Delta, int256 amount1Delta);
    error InvalidCallbackCaller(address caller);
    error InvalidPoolKey(PoolAddress.PoolKey poolKey);
    error InsufficientHedgeAmount(uint256 hedgeSize, uint256 swapAmount);

    struct Callback {
        CallbackInfo info;
        InstrumentStorage instrument;
        Fill fill;
    }

    struct CallbackInfo {
        Symbol symbol;
        PositionId positionId;
        address trader;
        uint256 limitCost;
        address payerOrReceiver;
        bool open;
        uint256 lendingLiquidity;
        uint24 uniswapFee;
    }

    address internal constant UNISWAP_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

    /// @notice Executes a flash swap on Uni V3, to buy/sell the hedgeSize
    /// @param callback Info collected before the flash swap started
    /// @param instrument The instrument being swapped
    /// @param baseForQuote True if base if being sold
    /// @param to The address to receive the output of the swap
    function flashSwap(Callback memory callback, InstrumentStorage memory instrument, bool baseForQuote, address to)
        internal
    {
        callback.instrument = instrument;

        (address tokenIn, address tokenOut) = baseForQuote
            ? (address(instrument.base), address(instrument.quote))
            : (address(instrument.quote), address(instrument.base));

        bool zeroForOne = tokenIn < tokenOut;

        IUniswapV3Pool(lookupPoolAddress(tokenIn, tokenOut, callback.info.uniswapFee)).swap({
            recipient: to,
            zeroForOne: zeroForOne,
            amountSpecified: baseForQuote ? callback.fill.hedgeSize.toInt256() : -callback.fill.hedgeSize.toInt256(),
            sqrtPriceLimitX96: (zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1),
            data: abi.encode(callback)
        });
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data,
        function(UniswapV3Handler.Callback memory) internal onUniswapCallback
    ) internal {
        if (amount0Delta < 0 && amount1Delta < 0 || amount0Delta > 0 && amount1Delta > 0) {
            revert InvalidAmountDeltas(amount0Delta, amount1Delta);
        }

        Callback memory callback = abi.decode(data, (Callback));
        InstrumentStorage memory instrument = callback.instrument;
        address poolAddress =
            lookupPoolAddress(address(instrument.base), address(instrument.quote), callback.info.uniswapFee);

        if (msg.sender != poolAddress) {
            revert InvalidCallbackCaller(msg.sender);
        }

        bool amount0isBase = instrument.base < instrument.quote;
        uint256 swapAmount = (amount0isBase ? amount0Delta : amount1Delta).abs();

        if (callback.fill.hedgeSize != swapAmount) {
            revert InsufficientHedgeAmount(callback.fill.hedgeSize, swapAmount);
        }

        callback.fill.hedgeCost = (amount0isBase ? amount1Delta : amount0Delta).abs();
        onUniswapCallback(callback);
    }

    function lookupPoolAddress(address token0, address token1, uint24 fee)
        internal
        view
        returns (address poolAddress)
    {
        PoolAddress.PoolKey memory poolKey = PoolAddress.getPoolKey(token0, token1, fee);
        poolAddress = UNISWAP_FACTORY.computeAddress(poolKey);
        if (!poolAddress.isContract()) {
            revert InvalidPoolKey(poolKey);
        }
    }
}
