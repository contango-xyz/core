//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../WithArbitrum.sol";

import "./ChainlinkAggregatorV2V3Mock.sol";
import "./UniswapPoolStubTest.t.sol";

contract UniswapPoolStubETHUSDCArbitrumTest is UniswapPoolStubTest, WithArbitrum {
    UniswapPoolStub private sut;

    constructor() {
        blockNo = 23_346_716;
    }

    function setUp() public override {
        super.setUp();

        ChainlinkAggregatorV2V3Mock oracle = new ChainlinkAggregatorV2V3Mock(8, USDC);
        oracle.set(1000e6);

        IERC20 token0 = WETH < USDC ? WETH : USDC;
        IERC20 token1 = WETH > USDC ? WETH : USDC;

        // Arbitrum: token0=WETH, token1=USDC
        sut = new UniswapPoolStub(token0, token1, oracle, false, 1e6);

        token0Decimals = IERC20Metadata(address(token0)).decimals();
        token1Decimals = IERC20Metadata(address(token1)).decimals();

        deal(address(WETH), address(sut), 100_000 ether);
        deal(address(USDC), address(sut), 1_000_000e6);
    }

    function testSwapZeroForOneExactInput() public {
        AssertionData memory assertionData =
            AssertionData({expectedAmount0Delta: 1 ether, expectedAmount1Delta: -999e6, repaymentToken: WETH});
        sut.swap(address(this), true, 1 ether, 0, abi.encode(assertionData));
    }

    function testSwapZeroForOneExactOutput() public {
        AssertionData memory assertionData =
            AssertionData({expectedAmount0Delta: 1 ether, expectedAmount1Delta: -999e6, repaymentToken: WETH});
        sut.swap(address(this), true, -999e6, 0, abi.encode(assertionData));
    }

    function testSwapOneForZeroExactInput() public {
        AssertionData memory assertionData =
            AssertionData({expectedAmount0Delta: -1 ether, expectedAmount1Delta: 1001e6, repaymentToken: USDC});
        sut.swap(address(this), false, 1001e6, 0, abi.encode(assertionData));
    }

    function testSwapOneForZeroExactOutput() public {
        AssertionData memory assertionData =
            AssertionData({expectedAmount0Delta: -1 ether, expectedAmount1Delta: 1001e6, repaymentToken: USDC});
        sut.swap(address(this), false, -1 ether, 0, abi.encode(assertionData));
    }
}
