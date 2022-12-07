//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./ContangoTestBase.sol";

abstract contract WithArbitrum is ContangoTestBase {
    constructor() {
        DAI = IERC20Metadata(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);
        USDC = IERC20Metadata(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
        WETH = IWETH9(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
        positionNFT = ContangoPositionNFT(0x497931c260a6f76294465f7BBB5071802e97E109);
        treasury = address(0x643178CF8AEc063962654CAc256FD1f7fe06ac28);
        contangoTimelock = address(0xe213C68563EE4c519183AE6c8Fc15d60bEaD95bb);
        chain = "arbitrum";
        chainId = 42161;
    }

    function setUp() public virtual override {
        super.setUp();

        vm.label(address(DAI), "DAI");
        vm.label(address(USDC), "USDC");
        vm.label(address(WETH), "WETH");
        vm.label(address(positionNFT), "ContangoPositionNFT");
        vm.label(treasury, "Treasury");

        deal(address(USDC), treasury, 0); // Clean treasury
        deal(address(WETH), treasury, 0); // Clean treasury
        deal(address(DAI), treasury, 0); // Clean treasury
    }

    function _deal(address token, address to, uint256 amount) internal override {
        if (token == address(WETH)) {
            hoax(to, amount);
            WETH.deposit{value: amount}();
        } else if (token == address(USDC)) {
            vm.prank(0x096760F208390250649E3e8763348E783AEF5562);
            IUSDC(address(USDC)).bridgeMint(to, amount);
        } else {
            deal(token, to, amount);
        }
        assertGe(IERC20(token).balanceOf(to), amount);
    }
}

interface IUSDC {
    function bridgeMint(address account, uint256 amount) external;
}
