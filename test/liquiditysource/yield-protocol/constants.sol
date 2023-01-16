//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "src/libraries/DataTypes.sol";

// solhint-disable const-name-snakecase
// solhint-disable-next-line contract-name-camelcase
library constants {
    bytes6 internal constant ETH_ID = "00";
    bytes6 internal constant DAI_ID = "01";
    bytes6 internal constant USDC_ID = "02";
    bytes6 internal constant FYUSDC2206 = "0206";
    bytes6 internal constant FYETH2212 = "0008";
    bytes6 internal constant FYDAI2212 = "0108";
    bytes6 internal constant FYUSDC2212 = "0208";
    bytes6 internal constant FYETH2303 = "0009";
    bytes6 internal constant FYDAI2303 = "0109";
    bytes6 internal constant FYUSDC2303 = "0209";
    bytes6 internal constant FYETH2306 = 0x0030FF00028B;
    bytes6 internal constant FYDAI2306 = 0x0031FF00028B;
    bytes6 internal constant FYUSDC2306 = 0x0032FF00028B;
    int128 internal constant ONE64 = 18446744073709551616;
    int128 internal constant SECONDS_IN_ONE_YEAR = 31557600;
    uint24 internal constant FEE_0_05 = 500;
    uint24 internal constant FEE_0_3 = 3000;
    uint256 internal constant MATURITY_2206 = 1656039600;
    uint256 internal constant MATURITY_2212 = 1672412400;
    uint256 internal constant MATURITY_2303 = 1680274800;

    Symbol internal constant yETHUSDC2212 = Symbol.wrap("yETHUSDC2212");
    Symbol internal constant yUSDCETH2212 = Symbol.wrap("yUSDCETH2212");
    Symbol internal constant yETHDAI2212 = Symbol.wrap("yETHDAI2212");
    Symbol internal constant yDAIETH2212 = Symbol.wrap("yDAIETH2212");

    Symbol internal constant yETHUSDC2303 = Symbol.wrap("yETHUSDC2303");
    Symbol internal constant yUSDCETH2303 = Symbol.wrap("yUSDCETH2303");
    Symbol internal constant yETHDAI2303 = Symbol.wrap("yETHDAI2303");
    Symbol internal constant yDAIETH2303 = Symbol.wrap("yDAIETH2303");
    Symbol internal constant yDAIUSDC2303 = Symbol.wrap("yDAIUSDC2303");

    Symbol internal constant yETHUSDC2306 = Symbol.wrap("yETHUSDC2306");
    Symbol internal constant yUSDCETH2306 = Symbol.wrap("yUSDCETH2306");
    Symbol internal constant yETHDAI2306 = Symbol.wrap("yETHDAI2306");
    Symbol internal constant yDAIETH2306 = Symbol.wrap("yDAIETH2306");
    Symbol internal constant yDAIUSDC2306 = Symbol.wrap("yDAIUSDC2306");
}
