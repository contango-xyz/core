//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../PositionFixtures.sol";

// solhint-disable func-name-mixedcase
abstract contract SettersFixtures is PositionFixtures {
    using SignedMath for int256;

    function testSetFeeModel() public {
        IFeeModel newFeeModel = IFeeModel(address(0xfee));

        vm.expectEmit(true, false, false, false);
        emit FeeModelUpdated(symbol, newFeeModel);
        vm.prank(contangoTimelock);
        contango.setFeeModel(symbol, newFeeModel);

        assertEq(address(contango.feeModel(symbol)), address(newFeeModel));
    }

    function testPauseUnpause() public {
        vm.prank(contangoMultisig);
        contango.pause();
        assertTrue(contango.paused());

        vm.prank(contangoMultisig);
        contango.unpause();
        assertFalse(contango.paused());
    }

    function testAddTrustedToken() public {
        address token = utils.getNextUserAddress("token");

        vm.expectEmit(true, true, true, true);
        emit TokenTrusted(token, true);
        vm.prank(contangoTimelock);
        contango.setTrustedToken(token, true);

        vm.expectEmit(true, true, true, true);
        emit TokenTrusted(token, false);
        vm.prank(contangoTimelock);
        contango.setTrustedToken(token, false);
    }
}
