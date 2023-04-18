//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./ContangoTestBase.sol";

abstract contract WithMainnet is ContangoTestBase {
    constructor() {
        DAI = ERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
        USDC = ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        WBTC = ERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
        WETH9 = WETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
        // Compound only available in mainnet for now
        CUSDC = ERC20(0x39AA39c021dfbaE8faC545936693aC917d5E7563);

        // https://docs.chain.link/data-feeds/price-feeds/addresses?network=ethereum
        chainlinkUsdOracles[DAI] = 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9;
        chainlinkUsdOracles[USDC] = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
        chainlinkUsdOracles[WBTC] = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;
        chainlinkUsdOracles[WETH9] = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

        positionNFT = ContangoPositionNFT(0x361F0201e82c9d701bcA9913191086476A8df53a);
        contangoTimelock = 0x62C66911aF80994A7d3758cD77afd67098AC665e;
        contangoMultisig = 0xe16cfA41902FDA3B0C86f1634F4A2C11af0C7Ece;
        treasury = 0x3bfbc7016ad9780F3509752119E09549353A3843;
        chain = "mainnet";
        chainId = 1;
    }

    function setUp() public virtual override {
        super.setUp();

        vm.label(address(DAI), "DAI");
        vm.label(address(USDC), "USDC");
        vm.label(address(WBTC), "WBTC");
        vm.label(address(WETH9), "WETH");
        vm.label(address(CUSDC), "cUSDC");

        vm.label(chainlinkUsdOracles[DAI], "DAI / USD Oracle");
        vm.label(chainlinkUsdOracles[USDC], "USDC / USD Oracle");
        vm.label(chainlinkUsdOracles[WBTC], "BTC / USD Oracle");
        vm.label(chainlinkUsdOracles[WETH9], "ETH / USD Oracle");

        vm.label(address(positionNFT), "ContangoPositionNFT");
        vm.label(treasury, "Treasury");
    }

    function _deal(address token, address to, uint256 amount) internal override {
        deal(token, to, amount);
        assertGe(ERC20(token).balanceOf(to), amount);
    }
}
