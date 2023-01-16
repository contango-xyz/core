//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../fixtures/functional/CollateralManagementFixtures.sol";
import "./YieldStubFixtures.sol";

contract YieldCollateralManagementTest is CollateralManagementETHUSDCFixtures, YieldStubETHUSDCFixtures {
    function setUp() public override(YieldStubETHUSDCFixtures, ContangoTestBase) {
        super.setUp();
    }
}
