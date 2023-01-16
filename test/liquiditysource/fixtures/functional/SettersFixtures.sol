//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../PositionFixtures.sol";

// solhint-disable func-name-mixedcase
abstract contract SettersFixtures is PositionFixtures {
    using SignedMath for int256;

    event FeeModelUpdated(Symbol indexed symbol, IFeeModel feeModel);
    event UniswapFeeUpdated(Symbol indexed symbol, uint24 uniswapFee);

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
}
