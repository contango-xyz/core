//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../WithArbitrum.sol";

import "./ChainlinkAggregatorV2V3Mock.sol";
import "./UniswapPoolStubTest.t.sol";

abstract contract UniswapPoolStubArbitrumTest is UniswapPoolStubTest, WithArbitrum {
    constructor() {
        blockNo = 23_346_716;
    }
}

contract UniswapPoolStubETHUSDCArbitrumTest is UniswapPoolStubArbitrumTest {
    function setUp() public override {
        super.setUp();

        ChainlinkAggregatorV2V3Mock ethOracle = new ChainlinkAggregatorV2V3Mock({_decimals: 8, _priceDecimals: 6})
            .set(1000e6);
        ChainlinkAggregatorV2V3Mock usdcOracle = new ChainlinkAggregatorV2V3Mock({_decimals: 8, _priceDecimals: 6})
            .set(1e6);

        // Arbitrum: USDC > WETH9
        sut = new UniswapPoolStub({
            _token0: WETH9,
            _token1: USDC,
            _token0Oracle: ethOracle,
            _token1Oracle: usdcOracle,
            _token0Quoted: false,
            _absoluteSpread: 1e6});

        deal(address(WETH9), address(sut), 100_000 ether);
        deal(address(USDC), address(sut), 1_000_000e6);
    }

    function testSwapZeroForOneExactInput() public {
        AssertionData memory assertionData =
            AssertionData({expectedAmount0Delta: 1 ether, expectedAmount1Delta: -999e6, repaymentToken: WETH9});
        sut.swap(address(this), true, 1 ether, 0, abi.encode(assertionData));
    }

    function testSwapZeroForOneExactOutput() public {
        AssertionData memory assertionData =
            AssertionData({expectedAmount0Delta: 1 ether, expectedAmount1Delta: -999e6, repaymentToken: WETH9});
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

contract UniswapPoolStubUSDCETHArbitrumTest is UniswapPoolStubArbitrumTest {
    function setUp() public override {
        super.setUp();

        ChainlinkAggregatorV2V3Mock ethOracle = new ChainlinkAggregatorV2V3Mock({_decimals: 8, _priceDecimals: 18})
            .set(1000e18);
        ChainlinkAggregatorV2V3Mock usdcOracle = new ChainlinkAggregatorV2V3Mock({_decimals: 8, _priceDecimals: 18})
            .set(1e18);

        // Arbitrum: USDC > WETH9
        sut = new UniswapPoolStub({
            _token0: WETH9,
            _token1: USDC,
            _token0Oracle: ethOracle,
            _token1Oracle: usdcOracle,
            _token0Quoted: true,
            _absoluteSpread: 0.000001e18});

        deal(address(WETH9), address(sut), 100_000 ether);
        deal(address(USDC), address(sut), 1_000_000e6);
    }

    function testSwapZeroForOneExactInput() public {
        AssertionData memory assertionData =
            AssertionData({expectedAmount0Delta: 1 ether, expectedAmount1Delta: -999.000999e6, repaymentToken: WETH9});
        sut.swap(address(this), true, 1 ether, 0, abi.encode(assertionData));
    }

    function testSwapZeroForOneExactOutput() public {
        AssertionData memory assertionData =
            AssertionData({expectedAmount0Delta: 0.999999 ether, expectedAmount1Delta: -999e6, repaymentToken: WETH9});
        sut.swap(address(this), true, -999e6, 0, abi.encode(assertionData));
    }

    function testSwapOneForZeroExactInput() public {
        AssertionData memory assertionData =
            AssertionData({expectedAmount0Delta: -0.999999 ether, expectedAmount1Delta: 1001e6, repaymentToken: USDC});
        sut.swap(address(this), false, 1001e6, 0, abi.encode(assertionData));
    }

    function testSwapOneForZeroExactOutput() public {
        AssertionData memory assertionData =
            AssertionData({expectedAmount0Delta: -1 ether, expectedAmount1Delta: 1001.001001e6, repaymentToken: USDC});
        sut.swap(address(this), false, -1 ether, 0, abi.encode(assertionData));
    }
}

contract UniswapPoolStubETHDAIArbitrumTest is UniswapPoolStubArbitrumTest {
    function setUp() public override {
        super.setUp();

        ChainlinkAggregatorV2V3Mock ethOracle = new ChainlinkAggregatorV2V3Mock({_decimals: 8, _priceDecimals: 18})
            .set(1000e18);
        ChainlinkAggregatorV2V3Mock daiOracle = new ChainlinkAggregatorV2V3Mock({_decimals: 8, _priceDecimals: 18})
            .set(1e18);

        // Arbitrum: DAI > WETH9
        sut = new UniswapPoolStub({
            _token0: WETH9,
            _token1: DAI,
            _token0Oracle: ethOracle,
            _token1Oracle: daiOracle,
            _token0Quoted: false,
            _absoluteSpread: 1e18});

        deal(address(WETH9), address(sut), 100_000 ether);
        deal(address(DAI), address(sut), 1_000_000e18);
    }

    function testSwapZeroForOneExactInput() public {
        AssertionData memory assertionData =
            AssertionData({expectedAmount0Delta: 1 ether, expectedAmount1Delta: -999e18, repaymentToken: WETH9});
        sut.swap(address(this), true, 1 ether, 0, abi.encode(assertionData));
    }

    function testSwapZeroForOneExactOutput() public {
        AssertionData memory assertionData =
            AssertionData({expectedAmount0Delta: 1 ether, expectedAmount1Delta: -999e18, repaymentToken: WETH9});
        sut.swap(address(this), true, -999e18, 0, abi.encode(assertionData));
    }

    function testSwapOneForZeroExactInput() public {
        AssertionData memory assertionData =
            AssertionData({expectedAmount0Delta: -1 ether, expectedAmount1Delta: 1001e18, repaymentToken: DAI});
        sut.swap(address(this), false, 1001e18, 0, abi.encode(assertionData));
    }

    function testSwapOneForZeroExactOutput() public {
        AssertionData memory assertionData =
            AssertionData({expectedAmount0Delta: -1 ether, expectedAmount1Delta: 1001e18, repaymentToken: DAI});
        sut.swap(address(this), false, -1 ether, 0, abi.encode(assertionData));
    }
}
