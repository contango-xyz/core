//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/Strings.sol";
import "./WithYieldFixtures.sol";

contract UpgradeabilityTest is WithYieldFixtures(constants.yETHDAI2212, constants.FYETH2212, constants.FYDAI2212) {
    event Upgraded(address indexed implementation);

    function testUpgrade() public {
        // given
        (PositionId positionId,) = _openPosition(2 ether);
        Position memory positionBefore = contango.position(positionId);

        // when
        ContangoV2 contangoV2 = new ContangoV2(WETH);

        vm.expectEmit(true, true, true, true);
        emit Upgraded(address(contangoV2));

        vm.prank(contangoTimelock);
        contango.upgradeTo(address(contangoV2));

        // then
        Position memory positionAfter = contango.position(positionId);
        assertEq(Symbol.unwrap(positionAfter.symbol), Symbol.unwrap(positionBefore.symbol));
        assertEq(positionAfter.openQuantity, positionBefore.openQuantity);
        assertEq(positionAfter.openCost, positionBefore.openCost);
        assertEq(positionAfter.collateral, positionBefore.collateral);
        assertEq(positionAfter.protocolFees, positionBefore.protocolFees + 4.2e18);
        assertEq(positionAfter.maturity, positionBefore.maturity);
        assertEq(address(positionAfter.feeModel), address(positionBefore.feeModel));
    }

    function testCanNotUpgradePermissionDenied() public {
        // given
        ContangoV2 contangoV2 = new ContangoV2(WETH);

        // expect
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(uint160(address(trader)), 20),
                " is missing role ",
                Strings.toHexString(uint256(contango.DEFAULT_ADMIN_ROLE()), 32)
            )
        );

        // when
        vm.prank(trader);
        contango.upgradeTo(address(contangoV2));
    }
}

contract ContangoV2 is ContangoYield {
    constructor(IWETH9 _weth) ContangoYield(_weth) {}

    function position(PositionId positionId) public view override returns (Position memory _position) {
        _position = super.position(positionId);
        _position.protocolFees += 4.2e18;
    }
}
