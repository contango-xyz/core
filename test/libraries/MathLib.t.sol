//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import "src/libraries/MathLib.sol";

contract MathLibTest is Test {
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
