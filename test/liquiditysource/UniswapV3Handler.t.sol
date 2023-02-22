//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import "src/liquiditysource/UniswapV3Handler.sol";

import "../WithArbitrum.sol";

contract UniswapV3HandlerTest is WithArbitrum {
    constructor() {
        blockNo = 36650929;
    }

    function testLookupPoolAddress() public {
        // https://info.uniswap.org/#/arbitrum/pools/0xc31e54c7a869b9fcbecc14363cf510d1c41fa443
        address pool = UniswapV3Handler.lookupPoolAddress(address(WETH9), address(USDC), 500);
        assertEq(pool, 0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443);
    }

    function testLookupPoolAddressWithInvalidAddress() public {
        // given
        address token0 = address(0);
        address token1 = address(1);
        uint24 fee = 0;

        // expect
        vm.expectRevert(abi.encodeWithSelector(UniswapV3Handler.InvalidPoolKey.selector, token0, token1, fee));

        // when
        UniswapV3Handler.lookupPoolAddress(address(0), address(1), 0);
    }
}
