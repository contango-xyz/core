//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import "./UniswapPoolStub.sol";

contract UniswapPoolStubTest is IUniswapV3SwapCallback, Test {
    struct AssertionData {
        int256 expectedAmount0Delta;
        int256 expectedAmount1Delta;
        IERC20 repaymentToken;
    }

    uint8 internal token0Decimals;
    uint8 internal token1Decimals;

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data)
        external
        virtual
        override
    {
        AssertionData memory assertionData = abi.decode(data, (AssertionData));

        assertEqDecimal(amount0Delta, assertionData.expectedAmount0Delta, token0Decimals, "amount0Delta");
        assertEqDecimal(amount1Delta, assertionData.expectedAmount1Delta, token1Decimals, "amount1Delta");

        uint256 repayment = uint256(amount0Delta > 0 ? amount0Delta : amount1Delta);
        deal(address(assertionData.repaymentToken), address(this), repayment);
        assertionData.repaymentToken.transfer(msg.sender, repayment);
    }
}
