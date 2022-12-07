//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {MathLib} from "src/libraries/MathLib.sol";

contract MathLibTest is Test {
    function testMulWadDown() public {
        assertEq(MathLib.mulWadDown(2.5e18, 0.5e18), 1.25e18);
        assertEq(MathLib.mulWadDown(3e18, 1e18), 3e18);
        assertEq(MathLib.mulWadDown(369, 271), 0);

        // https://www.wolframalpha.com/input?i=2.555555555555555555*.111111111111111111
        // 0.283950617283950616938271604938271605
        assertEq(MathLib.mulWadDown(2555555555555555555, 111111111111111111), 283950617283950616);
    }

    function testMulWadDownEdgeCases() public {
        assertEq(MathLib.mulWadDown(0, 1e18), 0);
        assertEq(MathLib.mulWadDown(1e18, 0), 0);
        assertEq(MathLib.mulWadDown(0, 0), 0);
    }

    function testMulWadUp() public {
        assertEq(MathLib.mulWadUp(2.5e18, 0.5e18), 1.25e18);
        assertEq(MathLib.mulWadUp(3e18, 1e18), 3e18);
        assertEq(MathLib.mulWadUp(369, 271), 1);

        // https://www.wolframalpha.com/input?i=2.555555555555555555*.111111111111111111
        // 0.283950617283950616938271604938271605
        assertEq(MathLib.mulWadUp(2555555555555555555, 111111111111111111), 283950617283950617);
    }

    function testMulWadUpEdgeCases() public {
        assertEq(MathLib.mulWadUp(0, 1e18), 0);
        assertEq(MathLib.mulWadUp(1e18, 0), 0);
        assertEq(MathLib.mulWadUp(0, 0), 0);
    }

    function testDivWadDown() public {
        assertEq(MathLib.divWadDown(1.25e18, 0.5e18), 2.5e18);
        assertEq(MathLib.divWadDown(3e18, 1e18), 3e18);
        assertEq(MathLib.divWadDown(2, 100000000000000e18), 0);

        // https://www.wolframalpha.com/input?i=2.555555555555555556%2F.111111111111111112
        // 22.999999999999999820000000000000001439999999999999988480000000000
        assertEq(MathLib.divWadDown(2555555555555555556, 111111111111111112), 22999999999999999820);
    }

    function testDivWadDownEdgeCases() public {
        assertEq(MathLib.divWadDown(0, 1e18), 0);
    }

    function testFailDivWadDownZeroDenominator() public pure {
        MathLib.divWadDown(1e18, 0);
    }

    function testDivWadUp() public {
        assertEq(MathLib.divWadUp(1.25e18, 0.5e18), 2.5e18);
        assertEq(MathLib.divWadUp(3e18, 1e18), 3e18);
        assertEq(MathLib.divWadUp(2, 100000000000000e18), 1);

        // https://www.wolframalpha.com/input?i=2.555555555555555556%2F.111111111111111112
        // 22.999999999999999820000000000000001439999999999999988480000000000
        assertEq(MathLib.divWadUp(2555555555555555556, 111111111111111112), 22999999999999999821);
    }

    function testDivWadUpEdgeCases() public {
        assertEq(MathLib.divWadUp(0, 1e18), 0);
    }

    function testFailDivWadUpZeroDenominator() public pure {
        MathLib.divWadUp(1e18, 0);
    }

    function testMulWadDown(uint256 x, uint256 y) public {
        // Ignore cases where x * y overflows.
        unchecked {
            if ((x != 0 && (x * y) / x != y)) return;
        }

        assertEq(MathLib.mulWadDown(x, y), (x * y) / 1e18);
    }

    function testFailMulWadDownOverflow(uint256 x, uint256 y) public pure {
        // Ignore cases where x * y does not overflow.
        unchecked {
            if ((x * y) / x == y) revert();
        }

        MathLib.mulWadDown(x, y);
    }

    function testMulWadUp(uint256 x, uint256 y) public {
        // Ignore cases where x * y overflows.
        unchecked {
            if ((x != 0 && (x * y) / x != y)) return;
        }

        assertEq(MathLib.mulWadUp(x, y), x * y == 0 ? 0 : (x * y - 1) / 1e18 + 1);
    }

    function testFailMulWadUpOverflow(uint256 x, uint256 y) public pure {
        // Ignore cases where x * y does not overflow.
        unchecked {
            if ((x * y) / x == y) revert();
        }

        MathLib.mulWadUp(x, y);
    }

    function testDivWadDown(uint256 x, uint256 y) public {
        // Ignore cases where x * WAD overflows or y is 0.
        unchecked {
            if (y == 0 || (x != 0 && (x * 1e18) / 1e18 != x)) return;
        }

        assertEq(MathLib.divWadDown(x, y), (x * 1e18) / y);
    }

    function testFailDivWadDownOverflow(uint256 x, uint256 y) public pure {
        // Ignore cases where x * WAD does not overflow or y is 0.
        unchecked {
            if (y == 0 || (x * 1e18) / 1e18 == x) revert();
        }

        MathLib.divWadDown(x, y);
    }

    function testFailDivWadDownZeroDenominator(uint256 x) public pure {
        MathLib.divWadDown(x, 0);
    }

    function testDivWadUp(uint256 x, uint256 y) public {
        // Ignore cases where x * WAD overflows or y is 0.
        unchecked {
            if (y == 0 || (x != 0 && (x * 1e18) / 1e18 != x)) return;
        }

        assertEq(MathLib.divWadUp(x, y), x == 0 ? 0 : (x * 1e18 - 1) / y + 1);
    }

    function testFailDivWadUpOverflow(uint256 x, uint256 y) public pure {
        // Ignore cases where x * WAD does not overflow or y is 0.
        unchecked {
            if (y == 0 || (x * 1e18) / 1e18 == x) revert();
        }

        MathLib.divWadUp(x, y);
    }

    function testFailDivWadUpZeroDenominator(uint256 x) public pure {
        // The OZ math lib "fails fast" on the numerator being 0, so it won't fail on 0/0... bit weird
        vm.assume(x > 0);
        MathLib.divWadUp(x, 0);
    }

    function testScaleRoundingCeiling() public {
        assertEqDecimal(
            MathLib.scale({value: 1.12e2, fromPrecision: 1e2, toPrecision: 1e3, roundCeiling: true}),
            1.12e3,
            3,
            "1e2 to 1e3 - round ceiling"
        );
        assertEqDecimal(
            MathLib.scale({value: 1.12e2, fromPrecision: 1e2, toPrecision: 1e2, roundCeiling: true}),
            1.12e2,
            2,
            "1e2 to 1e2 - round ceiling"
        );
        assertEqDecimal(
            MathLib.scale({value: 1.12e2, fromPrecision: 1e2, toPrecision: 1e1, roundCeiling: true}),
            1.2e1,
            1,
            "1e2 to 1e1 - round ceiling"
        );
    }

    function testScaleRoundingFloor() public {
        assertEqDecimal(
            MathLib.scale({value: 1.12e2, fromPrecision: 1e2, toPrecision: 1e3, roundCeiling: false}),
            1.12e3,
            3,
            "1e2 to 1e3 - round floor"
        );
        assertEqDecimal(
            MathLib.scale({value: 1.12e2, fromPrecision: 1e2, toPrecision: 1e2, roundCeiling: false}),
            1.12e2,
            2,
            "1e2 to 1e2 - round floor"
        );
        assertEqDecimal(
            MathLib.scale({value: 1.12e2, fromPrecision: 1e2, toPrecision: 1e1, roundCeiling: false}),
            1.1e1,
            1,
            "1e1 to 1e1 - round floor"
        );
    }
}
