//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../../WithArbitrum.sol";
import "../YieldFixtures.sol";

abstract contract WithYieldFixtures is YieldFixtures, WithArbitrum {
    constructor(Symbol _symbol, bytes6 _baseSeriesId, bytes6 _quoteSeriesId)
        YieldFixtures(_symbol, _baseSeriesId, _quoteSeriesId)
    {
        contango = ContangoYield(payable(0x30E7348163016B3b6E1621A3Cb40e8CF33CE97db));
        contangoView = IContangoView(address(contango));

        witch = IWitch(0x89343a24a217172A569A0bD68763Bf0671A3efd8);
        ladle = IContangoLadle(0x93343C08e2055b7793a3336d659Be348FC1B08f9);
        cauldron = ICauldron(0x44386ddB4C44E7CB8981f97AF89E928Ddd4258DD);
        poolOracle = IPoolOracle(0x210F4e1942bEEc4038743A8f885B870E0c27b414);

        yieldTimelock = address(0xd0a22827Aed2eF5198EbEc0093EA33A4CD641b6c);

        blockNo = 36650929;
    }

    function setUp() public virtual override(YieldFixtures, WithArbitrum) {
        super.setUp();

        vm.label(address(0x9D34dF69958675450ab8E53c8Df5531203398Dc9), "YieldMath");
        vm.label(address(0x30e042468e333Fde8E52Dd237673D7412045D2AC), "ChainlinkUSDMultiOracle");

        // TODO remove when possible
        vm.startPrank(contangoTimelock);
        contango.grantRole(contango.EMERGENCY_BREAK(), contangoMultisig);
        contango.grantRole(contango.OPERATOR(), contangoMultisig);
        vm.stopPrank();
    }
}
