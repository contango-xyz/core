//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../WithMainnet.sol";

import "./ChainlinkAggregatorV2V3Mock.sol";
import "./UniswapPoolStubTest.t.sol";

contract UniswapPoolStubDAIETHMainnetTest is UniswapPoolStubTest, WithMainnet {
    UniswapPoolStub private sut;

    constructor() {
        // TODO why?
        blockNo = 0;
    }

    function setUp() public override {
        super.setUp();

        ChainlinkAggregatorV2V3Mock oracle = new ChainlinkAggregatorV2V3Mock(8, DAI);
        oracle.set(1000e18);

        IERC20 token0 = WETH < DAI ? WETH : DAI;
        IERC20 token1 = WETH > DAI ? WETH : DAI;

        // Mainnet: token0=DAI, token1=WETH
        sut = new UniswapPoolStub(token0, token1, oracle, true, 1e18);

        token0Decimals = IERC20Metadata(address(token0)).decimals();
        token1Decimals = IERC20Metadata(address(token1)).decimals();

        deal(address(WETH), address(sut), 100_000 ether);
        deal(address(DAI), address(sut), 1_000_000e18);
    }

    function testSwapZeroForOneExactInput() public {
        AssertionData memory assertionData =
            AssertionData({expectedAmount0Delta: 1001e18, expectedAmount1Delta: -1 ether, repaymentToken: DAI});
        sut.swap(address(this), true, 1001e18, 0, abi.encode(assertionData));
    }

    function testSwapZeroForOneExactOutput() public {
        AssertionData memory assertionData =
            AssertionData({expectedAmount0Delta: 1001e18, expectedAmount1Delta: -1 ether, repaymentToken: DAI});
        sut.swap(address(this), true, -1 ether, 0, abi.encode(assertionData));
    }

    function testSwapOneForZeroExactInput() public {
        AssertionData memory assertionData =
            AssertionData({expectedAmount0Delta: -999e18, expectedAmount1Delta: 1 ether, repaymentToken: WETH});
        sut.swap(address(this), false, 1 ether, 0, abi.encode(assertionData));
    }

    function testSwapOneForZeroExactOutput() public {
        AssertionData memory assertionData =
            AssertionData({expectedAmount0Delta: -999e18, expectedAmount1Delta: 1 ether, repaymentToken: WETH});
        sut.swap(address(this), false, -999e18, 0, abi.encode(assertionData));
    }
}
