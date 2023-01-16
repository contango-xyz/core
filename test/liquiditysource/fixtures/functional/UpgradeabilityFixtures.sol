//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/Strings.sol";

import "../PositionFixtures.sol";

// solhint-disable func-name-mixedcase
abstract contract UpgradeabilityFixtures is PositionFixtures {
    event Upgraded(address indexed implementation);

    /// @dev should return address to new contango implementation that adds 4.2e18 to existing positions protocolFees
    function _contangoUpgrade() internal virtual returns (address);

    function testUpgrade() public {
        // given
        (PositionId positionId,) = _openPosition(2 ether);
        Position memory positionBefore = contango.position(positionId);

        // when
        address contangoUpgrade = _contangoUpgrade();

        vm.expectEmit(true, true, true, true);
        emit Upgraded(contangoUpgrade);

        vm.prank(contangoTimelock);
        contango.upgradeTo(contangoUpgrade);

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
        address contangoUpgrade = _contangoUpgrade();

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
        contango.upgradeTo(contangoUpgrade);
    }
}
