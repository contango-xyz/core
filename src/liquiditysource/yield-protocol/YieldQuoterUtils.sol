//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import {IPool} from "@yield-protocol/yieldspace-tv/src/interfaces/IPool.sol";
import "solmate/src/utils/FixedPointMathLib.sol";
import "../../libraries/Errors.sol";
import "../../libraries/DataTypes.sol";

library YieldQuoterUtils {
    using FixedPointMathLib for *;

    uint256 private constant SCALE_FACTOR_FOR_18_DECIMALS = 1;
    uint256 private constant SCALE_FACTOR_FOR_6_DECIMALS = 1e12;

    uint256 private constant LIQ_PRECISION_LIMIT_FOR_18_DECIMALS = 1e13;
    uint256 private constant LIQ_PRECISION_LIMIT_FOR_6_DECIMALS = 1e3;

    function liquidityHaircut(uint256 liquidity) internal pure returns (uint128) {
        // Using 95% of the liquidity to avoid reverts
        return uint128(liquidity.mulWadDown(0.95e18));
    }

    /// @dev Ignores liquidity values that are too small to be useful
    function cap(function() view external returns (uint128) f) internal view returns (uint128) {
        uint128 liquidity = liquidityHaircut(f());

        if (liquidity > 0) {
            IPool pool = IPool(f.address);
            uint256 scaleFactor = pool.scaleFactor();
            if (
                scaleFactor == SCALE_FACTOR_FOR_18_DECIMALS && liquidity <= LIQ_PRECISION_LIMIT_FOR_18_DECIMALS
                    || scaleFactor == SCALE_FACTOR_FOR_6_DECIMALS && liquidity <= LIQ_PRECISION_LIMIT_FOR_6_DECIMALS
            ) {
                liquidity = 0;
            } else if (f.selector == IPool.maxFYTokenOut.selector) {
                uint128 balance = uint128(pool.fyToken().balanceOf(f.address));
                if (balance < liquidity) {
                    liquidity = balance;
                }
            }
        }

        return liquidity;
    }

    function orMint(function(uint128) external view returns (uint128) previewFN, uint128 param)
        internal
        view
        returns (uint128 result)
    {
        if (param == 0) return 0;

        IPool pool = IPool(previewFN.address);

        if (previewFN.selector == IPool.buyFYTokenPreview.selector) {
            return _capPreview(previewFN, param, cap(pool.maxFYTokenOut));
        }

        if (previewFN.selector == IPool.sellBasePreview.selector) {
            return _capPreview(previewFN, param, cap(pool.maxBaseIn));
        }

        revert InvalidSelector(previewFN.selector);
    }

    function orMint(function(uint128) external view returns (uint128) previewFN, uint128 param, uint256 liquidity)
        internal
        view
        returns (uint128 result)
    {
        if (param == 0) return 0;

        if (
            previewFN.selector != IPool.buyFYTokenPreview.selector
                && previewFN.selector != IPool.sellBasePreview.selector
        ) revert InvalidSelector(previewFN.selector);

        return _capPreview(previewFN, param, liquidity);
    }

    function _capPreview(function(uint128) external view returns (uint128) previewFN, uint128 param, uint256 liquidity)
        private
        view
        returns (uint128)
    {
        if (liquidity == 0) return param;
        return liquidity > param ? previewFN(param) : previewFN(uint128(liquidity)) + (param - uint128(liquidity));
    }
}
