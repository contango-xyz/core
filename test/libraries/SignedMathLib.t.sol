//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import "@openzeppelin/contracts/utils/math/SignedMath.sol";

import {SignedMathLib} from "src/libraries/SignedMathLib.sol";
import {MathLib} from "src/libraries/MathLib.sol";

contract SignedMathLibTest is Test {
    using SignedMath for int256;

    function testFailAbsi() public pure {
        SignedMathLib.absi(type(int256).min);
    }

    function testAbsi(int256 x) public {
        vm.assume(x > type(int256).min);

        int256 abs = SignedMathLib.absi(x);
        assertGe(abs, 0);
        if (x < 0) {
            assertEq(abs, -x);
        } else {
            assertEq(abs, x);
        }
    }

    function testAbsiEdges() public {
        assertEq(SignedMathLib.absi(type(int256).max), type(int256).max);
        assertEq(SignedMathLib.absi(type(int256).min + 1), -(type(int256).min + 1));
    }

    function testDivUp(int256 x, int256 y) public {
        vm.assume(x > type(int256).min && y > type(int256).min);
        vm.assume(y != 0);

        int256 z = SignedMathLib.divUp(x, y);
        int256 mod = x % y;

        if (mod == 0) {
            assertEq(z, x / y);
        } else {
            assertEq(SignedMathLib.absi(z), (SignedMathLib.absi(x) / SignedMathLib.absi(y)) + 1);
        }
    }

    function testSignum(int256 x) public {
        int256 s = SignedMathLib.signum(x);
        if (x == 0) {
            assertEq(s, 0);
        } else if (x > 0) {
            assertEq(s, 1);
        } else {
            assertEq(s, -1);
        }
    }

    function testMulWadDownNegative() public {
        assertEq(SignedMathLib.mulWadDown(-2.5e18, 0.5e18), -1.25e18);
        assertEq(SignedMathLib.mulWadDown(-3e18, 1e18), -3e18);
        assertEq(SignedMathLib.mulWadDown(-369, 271), 0);

        // https://www.wolframalpha.com/input?i=-2.555555555555555555*.111111111111111111
        // -0.283950617283950616938271604938271605
        assertEq(SignedMathLib.mulWadDown(-2555555555555555555, 111111111111111111), -283950617283950616);
    }

    function testMulWadUpNegative() public {
        assertEq(SignedMathLib.mulWadUp(-2.5e18, 0.5e18), -1.25e18);
        assertEq(SignedMathLib.mulWadUp(-3e18, 1e18), -3e18);
        assertEq(SignedMathLib.mulWadUp(-369, 271), 1);

        // https://www.wolframalpha.com/input?i=-2.555555555555555555*.111111111111111111
        // -0.283950617283950616938271604938271605
        assertEq(SignedMathLib.mulWadUp(-2555555555555555555, 111111111111111111), -283950617283950617);
    }

    function testDivWadDownNegative() public {
        assertEq(SignedMathLib.divWadDown(-1.25e18, 0.5e18), -2.5e18);
        assertEq(SignedMathLib.divWadDown(-3e18, 1e18), -3e18);
        assertEq(SignedMathLib.divWadDown(-2, 100000000000000e18), 0);

        // https://www.wolframalpha.com/input?i=-2.555555555555555556%2F.111111111111111112
        // -22.999999999999999820000000000000001439999999999999988480000000000
        assertEq(SignedMathLib.divWadDown(-2555555555555555556, 111111111111111112), -22999999999999999820);
    }

    function testDivWadUpNegative() public {
        assertEq(SignedMathLib.divWadUp(-1.25e18, 0.5e18), -2.5e18);
        assertEq(SignedMathLib.divWadUp(-3e18, 1e18), -3e18);
        assertEq(SignedMathLib.divWadUp(-2, 100000000000000e18), 1);

        // https://www.wolframalpha.com/input?i=-2.555555555555555556%2F.111111111111111112
        // -22.999999999999999820000000000000001439999999999999988480000000000
        assertEq(SignedMathLib.divWadUp(-2555555555555555556, 111111111111111112), -22999999999999999821);
    }

    function testMulWadDown() public {
        assertEq(SignedMathLib.mulWadDown(2.5e18, 0.5e18), 1.25e18);
        assertEq(SignedMathLib.mulWadDown(3e18, 1e18), 3e18);
        assertEq(SignedMathLib.mulWadDown(369, 271), 0);

        // https://www.wolframalpha.com/input?i=2.555555555555555555*.111111111111111111
        // 0.283950617283950616938271604938271605
        assertEq(SignedMathLib.mulWadDown(2555555555555555555, 111111111111111111), 283950617283950616);
    }

    function testMulWadDownEdgeCases() public {
        assertEq(SignedMathLib.mulWadDown(0, 1e18), 0);
        assertEq(SignedMathLib.mulWadDown(1e18, 0), 0);
        assertEq(SignedMathLib.mulWadDown(0, 0), 0);
    }

    function testMulWadUp() public {
        assertEq(SignedMathLib.mulWadUp(2.5e18, 0.5e18), 1.25e18);
        assertEq(SignedMathLib.mulWadUp(3e18, 1e18), 3e18);
        assertEq(SignedMathLib.mulWadUp(369, 271), 1);

        // https://www.wolframalpha.com/input?i=2.555555555555555555*.111111111111111111
        // 0.283950617283950616938271604938271605
        assertEq(SignedMathLib.mulWadUp(2555555555555555555, 111111111111111111), 283950617283950617);
    }

    function testMulWadUpEdgeCases() public {
        assertEq(SignedMathLib.mulWadUp(0, 1e18), 0);
        assertEq(SignedMathLib.mulWadUp(1e18, 0), 0);
        assertEq(SignedMathLib.mulWadUp(0, 0), 0);
    }

    function testDivWadDown() public {
        assertEq(SignedMathLib.divWadDown(1.25e18, 0.5e18), 2.5e18);
        assertEq(SignedMathLib.divWadDown(3e18, 1e18), 3e18);
        assertEq(SignedMathLib.divWadDown(2, 100000000000000e18), 0);

        // https://www.wolframalpha.com/input?i=2.555555555555555556%2F.111111111111111112
        // 22.999999999999999820000000000000001439999999999999988480000000000
        assertEq(SignedMathLib.divWadDown(2555555555555555556, 111111111111111112), 22999999999999999820);
    }

    function testDivWadDownEdgeCases() public {
        assertEq(SignedMathLib.divWadDown(0, 1e18), 0);
    }

    function testFailDivWadDownZeroDenominator() public pure {
        SignedMathLib.divWadDown(1e18, 0);
    }

    function testDivWadUp() public {
        assertEq(SignedMathLib.divWadUp(1.25e18, 0.5e18), 2.5e18);
        assertEq(SignedMathLib.divWadUp(3e18, 1e18), 3e18);
        assertEq(SignedMathLib.divWadUp(2, 100000000000000e18), 1);

        // https://www.wolframalpha.com/input?i=2.555555555555555556%2F.111111111111111112
        // 22.999999999999999820000000000000001439999999999999988480000000000
        assertEq(SignedMathLib.divWadUp(2555555555555555556, 111111111111111112), 22999999999999999821);
    }

    function testDivWadUpEdgeCases() public {
        assertEq(SignedMathLib.divWadUp(0, 1e18), 0);
        assertEq(
            SignedMathLib.divWadUp(
                -1461501637330902918203684832716283019655932542977, -1461501637330902918203684832716283019655932542977
            ),
            1e18
        );
    }

    function testFailDivWadUpZeroDenominator() public pure {
        SignedMathLib.divWadUp(1e18, 0);
    }

    function testMulWadDown(int256 x, int256 y) public {
        // Ignore cases where x * y overflows.
        unchecked {
            if ((x != 0 && (x * y) / x != y) || y == type(int256).min) return;
        }

        assertEq(SignedMathLib.mulWadDown(x, y), (x * y) / 1e18);
    }

    function testFailMulWadDownOverflow(int256 x, int256 y) public pure {
        // Ignore cases where x * y does not overflow.
        unchecked {
            if ((x * y) / x == y) revert();
        }

        SignedMathLib.mulWadDown(x, y);
    }

    function testMulWadUp(int256 x, int256 y) public {
        // Ignore cases where x * y overflows.
        unchecked {
            if ((x != 0 && (x * y) / x != y) || y == type(int256).min) return;
        }

        assertEq(SignedMathLib.mulWadUp(x, y).abs(), x * y == 0 ? 0 : MathLib.mulWadUp(x.abs(), y.abs()));
    }

    function testFailMulWadUpOverflow(int256 x, int256 y) public pure {
        // Ignore cases where x * y does not overflow.
        unchecked {
            if ((x * y) / x == y) revert();
        }

        SignedMathLib.mulWadUp(x, y);
    }

    function testDivWadDown(int256 x, int256 y) public {
        // Ignore cases where x * WAD overflows or y is 0.
        unchecked {
            if (y == 0 || (x != 0 && (x * 1e18) / 1e18 != x)) return;
        }

        assertEq(SignedMathLib.divWadDown(x, y), (x * 1e18) / y);
    }

    function testFailDivWadDownOverflow(int256 x, int256 y) public pure {
        // Ignore cases where x * WAD does not overflow or y is 0.
        unchecked {
            if (y == 0 || (x * 1e18) / 1e18 == x) revert();
        }

        SignedMathLib.divWadDown(x, y);
    }

    function testFailDivWadDownZeroDenominator(int256 x) public pure {
        SignedMathLib.divWadDown(x, 0);
    }

    function testDivWadUp(int256 x, int256 y) public {
        // Ignore cases where x * WAD overflows or y is 0.
        unchecked {
            if (y == 0 || y == type(int256).min || x == y || (x != 0 && (x * 1e18) / 1e18 != x)) return;
        }

        assertEq(
            SignedMathLib.absi(SignedMathLib.divWadUp(x, y)),
            x == 0 ? int256(0) : (SignedMathLib.absi(x) * 1e18 - 1) / SignedMathLib.absi(y) + 1
        );
    }

    function testFailDivWadUpOverflow(int256 x, int256 y) public pure {
        // Ignore cases where x * WAD does not overflow or y is 0.
        unchecked {
            if (y == 0 || (x * 1e18) / 1e18 == x) revert();
        }

        SignedMathLib.divWadUp(x, y);
    }

    function testFailDivWadUpZeroDenominator(int256 x) public pure {
        SignedMathLib.divWadUp(x, 0);
    }
}
