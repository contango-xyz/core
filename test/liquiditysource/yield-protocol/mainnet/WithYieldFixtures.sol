//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../../WithMainnet.sol";
import "../YieldFixtures.sol";

abstract contract WithYieldFixtures is YieldFixtures, WithMainnet {
    constructor(Symbol _symbol, bytes6 _baseSeriesId, bytes6 _quoteSeriesId)
        YieldFixtures(_symbol, _baseSeriesId, _quoteSeriesId)
    {
        contango = ContangoYield(payable(0x6008DbC83cd0A752b44a7E1b1A1E8b7355a90e17));
        contangoView = IContangoView(address(contango));

        witch = IWitch(0xB132C10acabCB8966Fa38e5AE9745039b7c8008b);
        ladle = IContangoLadle(0x30E7348163016B3b6E1621A3Cb40e8CF33CE97db);
        cauldron = ICauldron(0xf2F7c33234160387e5Dc82B1412b522AB44876C7);
        poolOracle = IPoolOracle(0x96bF9aB0E421a3da31D4506c967A825312455767);

        yieldTimelock = address(0x3b870db67a45611CF4723d44487EAF398fAc51E3);

        blockNo = 16175593;
    }

    function setUp() public virtual override(YieldFixtures, WithMainnet) {
        super.setUp();

        // TODO remove when possible
        vm.startPrank(contangoTimelock);
        contango.grantRole(contango.EMERGENCY_BREAK(), contangoMultisig);
        contango.grantRole(contango.OPERATOR(), contangoMultisig);
        vm.stopPrank();
    }
}
