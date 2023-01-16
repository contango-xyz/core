//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import "./UniswapPoolStub.sol";

contract UniswapPoolStubTest is IUniswapV3SwapCallback, Test {
    struct AssertionData {
        int256 expectedAmount0Delta;
        int256 expectedAmount1Delta;
        ERC20 repaymentToken;
    }

    UniswapPoolStub internal sut;

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data)
        external
        virtual
        override
    {
        AssertionData memory assertionData = abi.decode(data, (AssertionData));

        assertEqDecimal(amount0Delta, assertionData.expectedAmount0Delta, sut.token0().decimals(), "amount0Delta");
        assertEqDecimal(amount1Delta, assertionData.expectedAmount1Delta, sut.token1().decimals(), "amount1Delta");

        uint256 repayment = uint256(amount0Delta > 0 ? amount0Delta : amount1Delta);
        deal(address(assertionData.repaymentToken), address(this), repayment);
        assertionData.repaymentToken.transfer(msg.sender, repayment);
    }
}
