//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {SlippageLib} from "src/liquiditysource/SlippageLib.sol";

contract SlippageLibTest is Test {
    function testRequireCostAboveTolerance(uint256 cost, uint256 slippageTolerance) public {
        vm.assume(cost < slippageTolerance);

        vm.expectRevert(abi.encodeWithSelector(SlippageLib.CostBelowTolerance.selector, slippageTolerance, cost));
        SlippageLib.requireCostAboveTolerance(cost, slippageTolerance);
    }

    function testRequireCostAboveToleranceBoundaries() public pure {
        SlippageLib.requireCostAboveTolerance(1e18, 1e18);
    }

    function testRequireCostBelowTolerance(uint256 cost, uint256 slippageTolerance) public {
        vm.assume(cost > slippageTolerance);

        vm.expectRevert(abi.encodeWithSelector(SlippageLib.CostAboveTolerance.selector, slippageTolerance, cost));
        SlippageLib.requireCostBelowTolerance(cost, slippageTolerance);
    }

    function testRequireCostBelowToleranceBoundaries() public pure {
        SlippageLib.requireCostBelowTolerance(1e18, 1e18);
    }
}
