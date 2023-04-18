//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import "solmate/src/tokens/WETH.sol";
import "src/liquiditysource/yield-protocol/ContangoYieldQuoter.sol";
import "src/liquiditysource/yield-protocol/ContangoYield.sol";

contract QuoterBugFix61182114 is Test {
    IQuoter internal quoter = IQuoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);
    IContangoYield internal contango = IContangoYield(payable(0x30E7348163016B3b6E1621A3Cb40e8CF33CE97db));
    ICauldron internal cauldron = ICauldron(0x44386ddB4C44E7CB8981f97AF89E928Ddd4258DD);
    ContangoPositionNFT internal positionNFT = ContangoPositionNFT(0x497931c260a6f76294465f7BBB5071802e97E109);

    ContangoYieldQuoter public contangoQuoter;

    function testBug1() public {
        vm.createSelectFork("arbitrum", 61182114);

        contangoQuoter = new ContangoYieldQuoter(positionNFT, contango, cauldron, quoter);

        ContangoYield impl = new ContangoYield(WETH(payable(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1)));
        vm.prank(0xe213C68563EE4c519183AE6c8Fc15d60bEaD95bb); // contango timelock
        ContangoYield(payable(address(contango))).upgradeTo(address(impl));

        contangoQuoter.modifyCostForPositionWithLeverage(
            ModifyCostParams(PositionId.wrap(841), -2 ether, 0.001e18, 500), 2e18
        );
    }

    function testBug2() public {
        vm.createSelectFork("arbitrum", 79973205);

        contangoQuoter = new ContangoYieldQuoter(positionNFT, contango, cauldron, quoter);

        skip(10 minutes);

        contangoQuoter.modifyCostForPositionWithLeverage(
            ModifyCostParams(PositionId.wrap(843), 199.5e18, 0.001e18, 500), 6.68e18
        );
    }
}
