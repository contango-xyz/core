//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "forge-std/Test.sol";

import "src/interfaces/IFeeModel.sol";
import "src/libraries/CodecLib.sol";

contract CodecLibTest is Test {
    function testEncodeDecodeU128(uint128 a, uint128 b) public {
        uint256 encoded = CodecLib.encodeU128(a, b);
        (uint256 _a, uint256 _b) = CodecLib.decodeU128(encoded);

        assertEq(_a, a);
        assertEq(_b, b);
    }

    function testEncodeU128Boundaries() public {
        uint256 encoded = CodecLib.encodeU128(type(uint128).max, 0);
        (uint256 _a, uint256 _b) = CodecLib.decodeU128(encoded);

        assertEq(_a, type(uint128).max);
        assertEq(_b, 0);
    }

    function testEncodeOverU128Boundaries() public {
        uint256 n = uint256(type(uint128).max) + 1;
        vm.expectRevert(abi.encodeWithSelector(CodecLib.InvalidUInt128.selector, n));
        CodecLib.encodeU128(n, 0);
    }

    function testEncodeOverU128Boundaries2() public {
        uint256 n = uint256(type(uint128).max) + 1;
        vm.expectRevert(abi.encodeWithSelector(CodecLib.InvalidUInt128.selector, n));
        CodecLib.encodeU128(0, n);
    }

    function testEncodeDecodeI128(int128 a, int128 b) public {
        uint256 encoded = CodecLib.encodeI128(a, b);
        (int256 _a, int256 _b) = CodecLib.decodeI128(encoded);

        assertEq(_a, a);
        assertEq(_b, b);
    }

    function testEncodeI128Boundaries() public {
        uint256 encoded = CodecLib.encodeI128(type(int128).max, type(int128).min);
        (int256 _a, int256 _b) = CodecLib.decodeI128(encoded);

        assertEq(_a, type(int128).max);
        assertEq(_b, type(int128).min);
    }

    function testEncodeOverI128Boundaries() public {
        int256 n = int256(type(int128).max) + 1;
        vm.expectRevert(abi.encodeWithSelector(CodecLib.InvalidInt128.selector, n));
        CodecLib.encodeI128(n, 0);
    }

    function testEncodeOverI128Boundaries2() public {
        int256 n = int256(type(int128).max) + 1;
        vm.expectRevert(abi.encodeWithSelector(CodecLib.InvalidInt128.selector, n));
        CodecLib.encodeI128(0, n);
    }

    function testEncodeUnderI128Boundaries() public {
        int256 n = int256(type(int128).min) - 1;
        vm.expectRevert(abi.encodeWithSelector(CodecLib.InvalidInt128.selector, n));
        CodecLib.encodeI128(n, 0);
    }

    function testEncodeUnderI128Boundaries2() public {
        int256 n = int256(type(int128).min) - 1;
        vm.expectRevert(abi.encodeWithSelector(CodecLib.InvalidInt128.selector, n));
        CodecLib.encodeI128(0, n);
    }
}
