//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../WithMainnet.sol";

import "./ChainlinkAggregatorV2V3Mock.sol";
import "./UniswapPoolStubTest.t.sol";

abstract contract UniswapPoolStubMainnetTest is UniswapPoolStubTest, WithMainnet {
    constructor() {
        blockNo = 15868088;
    }
}

contract UniswapPoolStubETHUSDCMainnetTest is UniswapPoolStubMainnetTest {
    function setUp() public override {
        super.setUp();

        ChainlinkAggregatorV2V3Mock ethOracle = new ChainlinkAggregatorV2V3Mock({_decimals: 8, _priceDecimals: 6})
            .set(1000e6);
        ChainlinkAggregatorV2V3Mock usdcOracle = new ChainlinkAggregatorV2V3Mock({_decimals: 8, _priceDecimals: 6})
            .set(1e6);

        // Mainnet: USDC < WETH9
        sut = new UniswapPoolStub({
            _token0: USDC,
            _token1: WETH9,
            _token0Oracle: usdcOracle,
            _token1Oracle: ethOracle,
            _token0Quoted: true,
            _absoluteSpread: 1e6});

        deal(address(WETH9), address(sut), 100_000 ether);
        deal(address(USDC), address(sut), 1_000_000e6);
    }

    function testSwapZeroForOneExactInput() public {
        AssertionData memory assertionData =
            AssertionData({expectedAmount0Delta: 1001e6, expectedAmount1Delta: -1 ether, repaymentToken: USDC});
        sut.swap(address(this), true, 1001e6, 0, abi.encode(assertionData));
    }

    function testSwapZeroForOneExactOutput() public {
        AssertionData memory assertionData =
            AssertionData({expectedAmount0Delta: 1001e6, expectedAmount1Delta: -1 ether, repaymentToken: USDC});
        sut.swap(address(this), true, -1 ether, 0, abi.encode(assertionData));
    }

    function testSwapOneForZeroExactInput() public {
        AssertionData memory assertionData =
            AssertionData({expectedAmount0Delta: -999e6, expectedAmount1Delta: 1 ether, repaymentToken: WETH9});
        sut.swap(address(this), false, 1 ether, 0, abi.encode(assertionData));
    }

    function testSwapOneForZeroExactOutput() public {
        AssertionData memory assertionData =
            AssertionData({expectedAmount0Delta: -999e6, expectedAmount1Delta: 1 ether, repaymentToken: WETH9});
        sut.swap(address(this), false, -999e6, 0, abi.encode(assertionData));
    }
}

contract UniswapPoolStubUSDCETHMainnetTest is UniswapPoolStubMainnetTest {
    function setUp() public override {
        super.setUp();

        ChainlinkAggregatorV2V3Mock usdcOracle = new ChainlinkAggregatorV2V3Mock({_decimals: 8, _priceDecimals: 18})
            .set(1e18);
        ChainlinkAggregatorV2V3Mock ethOracle = new ChainlinkAggregatorV2V3Mock({_decimals: 8, _priceDecimals: 18})
            .set(1000e18);

        // Mainnet: USDC < WETH9
        sut = new UniswapPoolStub({
            _token0: USDC,
            _token1: WETH9,
            _token0Oracle: usdcOracle,
            _token1Oracle: ethOracle,
            _token0Quoted: false,
            _absoluteSpread: 0.000001e18});

        deal(address(WETH9), address(sut), 100_000 ether);
        deal(address(USDC), address(sut), 1_000_000e6);
    }

    function testSwapZeroForOneExactInput() public {
        AssertionData memory assertionData =
            AssertionData({expectedAmount0Delta: 1001e6, expectedAmount1Delta: -0.999999 ether, repaymentToken: USDC});
        sut.swap(address(this), true, 1001e6, 0, abi.encode(assertionData));
    }

    function testSwapZeroForOneExactOutput() public {
        AssertionData memory assertionData =
            AssertionData({expectedAmount0Delta: 1001.001001e6, expectedAmount1Delta: -1 ether, repaymentToken: USDC});
        sut.swap(address(this), true, -1 ether, 0, abi.encode(assertionData));
    }

    function testSwapOneForZeroExactInput() public {
        AssertionData memory assertionData =
            AssertionData({expectedAmount0Delta: -999.000999e6, expectedAmount1Delta: 1 ether, repaymentToken: WETH9});
        sut.swap(address(this), false, 1 ether, 0, abi.encode(assertionData));
    }

    function testSwapOneForZeroExactOutput() public {
        AssertionData memory assertionData =
            AssertionData({expectedAmount0Delta: -999e6, expectedAmount1Delta: 0.999999 ether, repaymentToken: WETH9});
        sut.swap(address(this), false, -999e6, 0, abi.encode(assertionData));
    }
}

contract UniswapPoolStubETHDAIMainnetTest is UniswapPoolStubMainnetTest {
    function setUp() public override {
        super.setUp();

        ChainlinkAggregatorV2V3Mock ethOracle = new ChainlinkAggregatorV2V3Mock({_decimals: 8, _priceDecimals: 18})
            .set(1000e18);
        ChainlinkAggregatorV2V3Mock daiOracle = new ChainlinkAggregatorV2V3Mock({_decimals: 8, _priceDecimals: 18})
            .set(1e18);

        // Mainnet: DAI < WETH9
        sut = new UniswapPoolStub({
            _token0: DAI,
            _token1: WETH9,
            _token0Oracle: daiOracle,
            _token1Oracle: ethOracle,
            _token0Quoted: true,
            _absoluteSpread: 1e18});

        deal(address(WETH9), address(sut), 100_000 ether);
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
            AssertionData({expectedAmount0Delta: -999e18, expectedAmount1Delta: 1 ether, repaymentToken: WETH9});
        sut.swap(address(this), false, 1 ether, 0, abi.encode(assertionData));
    }

    function testSwapOneForZeroExactOutput() public {
        AssertionData memory assertionData =
            AssertionData({expectedAmount0Delta: -999e18, expectedAmount1Delta: 1 ether, repaymentToken: WETH9});
        sut.swap(address(this), false, -999e18, 0, abi.encode(assertionData));
    }
}
