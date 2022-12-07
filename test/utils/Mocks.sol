// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import {Vm} from "forge-std/Vm.sol";

//common utilities for forge tests
library Mocks {
    Vm public constant vm = Vm(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));

    function mock(string memory label) external returns (address mock_) {
        StrictMock m = new StrictMock();
        m.setName(label);
        mock_ = address(m);
        vm.label(mock_, label);
    }

    function lenientMock(string memory label) external returns (address mock_) {
        mock_ = address(new LenientMock());
        vm.label(mock_, label);
    }

    function mockAt(address where, string memory label) external returns (address) {
        vm.etch(where, vm.getCode("Mocks.sol:StrictMock"));
        vm.label(where, label);
        StrictMock(payable(where)).setName(label);
        return where;
    }

    function mock(
        function(bytes32,bytes32,uint256) external returns (uint256,uint256) f,
        bytes32 p1,
        bytes32 p2,
        uint256 p3,
        uint256 r1,
        uint256 r2
    ) internal {
        vm.mockCall(f.address, abi.encodeWithSelector(f.selector, p1, p2, p3), abi.encode(r1, r2));
    }

    function mock(
        function(bytes6,bytes6,uint256) external returns (uint256,uint256) f,
        bytes6 p1,
        bytes6 p2,
        uint256 p3,
        uint256 r1,
        uint256 r2
    ) internal {
        vm.mockCall(f.address, abi.encodeWithSelector(f.selector, p1, p2, p3), abi.encode(r1, r2));
    }

    function mock(function(uint128) external returns (uint128) f, uint128 p1, uint128 r1) internal {
        vm.mockCall(f.address, abi.encodeWithSelector(f.selector, p1), abi.encode(r1));
    }

    function mock(function() external view returns (uint128) f, uint128 r1) internal {
        vm.mockCall(f.address, abi.encodeWithSelector(f.selector), abi.encode(r1));
    }
}

contract StrictMock {
    string public name;

    function setName(string memory _name) external {
        name = _name;
    }

    error NotMocked(string name, address mock, bytes4 sig, bytes data);

    fallback() external payable {
        revert NotMocked(name, address(this), msg.sig, msg.data);
    }

    receive() external payable {
        revert NotMocked(name, address(this), msg.sig, "");
    }
}

contract LenientMock {
    fallback() external payable {}
}
