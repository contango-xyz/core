//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import {CompositeMultiOracle} from "@yield-protocol/vault-v2/src/oracles/composite/CompositeMultiOracle.sol";
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
        poolOracle = IPoolOracle(0xedc965dcD634B0A9843569577654669225955E8A);
        compositeOracle = CompositeMultiOracle(0x750B3a18115fe090Bc621F9E4B90bd442bcd02F2);
        identityOracle = IOracle(0xce3d36e19De6A7b66e851c5B7e468E35Dc83d29d);

        yieldTimelock = address(0xd0a22827Aed2eF5198EbEc0093EA33A4CD641b6c);

        chain = "arbitrum";
        blockNo = 81417005;
    }

    function setUp() public virtual override(YieldFixtures, WithArbitrum) {
        super.setUp();
        skip(10 minutes);

        vm.label(address(0x9D34dF69958675450ab8E53c8Df5531203398Dc9), "YieldMath");
        vm.label(address(0x30e042468e333Fde8E52Dd237673D7412045D2AC), "ChainlinkUSDMultiOracle");
    }
}
