//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import "src/models/FixedFeeModel.sol";

contract FixedFeeModelTest is Test {
    using FixedPointMathLib for uint256;

    FixedFeeModel private sut;

    function testAboveMaxFeeRevert(uint256 fee) public {
        fee = bound(fee, MAX_FIXED_FEE + 1, type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(FixedFeeModel.AboveMaxFee.selector, fee));
        sut = new FixedFeeModel(fee);
    }

    function testBelowMinFeeRevert(uint256 fee) public {
        fee = bound(fee, 0, MIN_FIXED_FEE - 1);
        vm.expectRevert(abi.encodeWithSelector(FixedFeeModel.BelowMinFee.selector, fee));
        sut = new FixedFeeModel(fee);
    }

    function testCalculateFees() public {
        // given
        uint256 feeRate = 0.0015e18;
        uint256 cost = 10_000e18;
        uint256 expectedFees = 15e18;

        sut = new FixedFeeModel(feeRate);

        // when
        uint256 actualFees = sut.calculateFee(address(this), PositionId.wrap(1), cost);

        // then
        assertEq(expectedFees, actualFees);
    }

    function testCalculateFees6Decimals() public {
        // given
        uint256 feeRate = 0.0015e18;
        uint256 cost = 10_000e6;
        uint256 expectedFees = 15e6;

        sut = new FixedFeeModel(feeRate);

        // when
        uint256 actualFees = sut.calculateFee(address(this), PositionId.wrap(1), cost);

        // then
        assertEq(expectedFees, actualFees);
    }

    function testCalculateFeeFuzzInput(uint256 feeRate, address trader, PositionId positionId, uint128 cost) public {
        feeRate = bound(feeRate, MIN_FIXED_FEE, MAX_FIXED_FEE);

        // given
        vm.assume(cost != 0);

        sut = new FixedFeeModel(feeRate);

        uint256 expectedFees = uint256(cost).mulWadUp(feeRate);

        // when
        uint256 actualFees = sut.calculateFee(trader, positionId, cost);

        // then
        assertEq(expectedFees, actualFees);
    }
}
