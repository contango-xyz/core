//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./ContangoTestBase.sol";

abstract contract WithMainnet is ContangoTestBase {
    constructor() {
        DAI = IERC20Metadata(0x6B175474E89094C44Da98b954EedeAC495271d0F);
        USDC = IERC20Metadata(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        WBTC = IERC20Metadata(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
        WETH = IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        positionNFT = ContangoPositionNFT(0x361F0201e82c9d701bcA9913191086476A8df53a);
        contangoTimelock = address(0x62C66911aF80994A7d3758cD77afd67098AC665e);
        treasury = address(0x3bfbc7016ad9780F3509752119E09549353A3843);
        chain = "mainnet";
        chainId = 1;
    }

    function setUp() public virtual override {
        super.setUp();

        vm.label(address(DAI), "DAI");
        vm.label(address(USDC), "USDC");
        vm.label(address(WETH), "WETH");
        vm.label(address(positionNFT), "ContangoPositionNFT");
        vm.label(treasury, "Treasury");
    }

    function _deal(address token, address to, uint256 amount) internal override {
        deal(token, to, amount);
        assertGe(IERC20(token).balanceOf(to), amount);
    }
}
