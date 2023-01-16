// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../utils/Utilities.sol";
import "forge-std/Test.sol";

import "src/batchable/Batchable.sol";

contract BatchableTest is Test {
    Utilities private utils;

    Foo private sut;

    function setUp() public {
        utils = new Utilities();
        sut = new Foo();
    }

    function testBatch() public {
        bytes[] memory calls = new bytes[](4);
        calls[0] = abi.encodeWithSelector(Foo.foo.selector);
        calls[1] = abi.encodeWithSelector(Foo.bar.selector, 42);
        calls[2] = abi.encodeWithSelector(Foo.baz.selector);
        calls[3] = abi.encodeWithSelector(Foo.barBaz.selector, 42);

        vm.expectCall(address(sut), calls[0]);
        vm.expectCall(address(sut), calls[1]);
        vm.expectCall(address(sut), calls[2]);
        vm.expectCall(address(sut), calls[3]);

        bytes[] memory results = sut.batch(calls);

        assertEq(results.length, 4);
        assertEq0(results[0], bytes(""));
        assertEq0(results[1], bytes(""));
        assertEq0(results[2], abi.encodePacked(uint256(42)));
        assertEq0(results[3], abi.encodePacked(uint256(42)));
    }

    function testBatchRevert() public {
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(Foo.foo.selector);
        calls[1] = abi.encodeWithSelector(Foo.boom.selector);

        vm.expectCall(address(sut), calls[0]);
        vm.expectCall(address(sut), calls[1]);

        vm.expectRevert("boom!");

        sut.batch(calls);
    }

    function testBatchRevertError() public {
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(Foo.foo.selector);
        calls[1] = abi.encodeWithSelector(Foo.boomError.selector);

        vm.expectCall(address(sut), calls[0]);
        vm.expectCall(address(sut), calls[1]);

        vm.expectRevert(abi.encodeWithSelector(Foo.Boom.selector, address(this), "Boom!"));

        sut.batch(calls);
    }

    function testNonExistantFunction() public {
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSelector(bytes4(keccak256("invalid()")));

        vm.expectRevert(abi.encodeWithSelector(Batchable.TransactionRevertedSilently.selector));

        sut.batch(calls);
    }
}

// solhint-disable no-empty-blocks
contract Foo is Batchable {
    error Boom(address sender, string errorMessage);

    function foo() external {}

    function bar(uint256) external {}

    function baz() external pure returns (uint256) {
        return 42;
    }

    function barBaz(uint256 param) external pure returns (uint256) {
        return param;
    }

    function boom() external pure {
        revert("boom!");
    }

    function boomError() external view {
        revert Boom(msg.sender, "Boom!");
    }
}
