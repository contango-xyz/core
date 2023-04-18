//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../fixtures/functional/UpgradeabilityFixtures.sol";
import "./WithYieldFixtures.sol";

contract YieldUpgradeabilityTest is
    UpgradeabilityFixtures,
    WithYieldFixtures(constants.yETHDAI2306, constants.FYETH2306, constants.FYDAI2306)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }

    function _contangoUpgrade() internal override returns (address) {
        return address(new ContangoV2(WETH9));
    }
}

contract ContangoV2 is ContangoYield {
    // solhint-disable-next-line no-empty-blocks
    constructor(WETH _weth) ContangoYield(_weth) {}

    function position(PositionId positionId)
        public
        view
        override(ContangoBase, IContangoView)
        returns (Position memory _position)
    {
        _position = super.position(positionId);
        _position.protocolFees += 4.2e18;
    }
}
