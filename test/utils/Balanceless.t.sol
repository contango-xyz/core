//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Utilities} from "./Utilities.sol";
import {ERC20Stub} from "../stub/ERC20Stub.sol";

import {Balanceless} from "src/utils/Balanceless.sol";

contract BalancelessTest is Test {
    address payable private trader = payable(address(0xb0b));
    IERC20 private testToken;
    Utilities private utils;
    BalancelessStub private sut;

    event BalanceCollected(address indexed token, address indexed to, uint256 amount);

    function setUp() public {
        utils = new Utilities();

        testToken = new ERC20Stub("Test", "TST");

        sut = new BalancelessStub();
    }

    function testCollectBalanceEth() public {
        // given
        vm.deal(address(sut), 1e18);

        // when
        vm.expectEmit(true, true, true, true);
        emit BalanceCollected(address(0), trader, 1e18);
        sut.collectBalance(address(0), trader, 1e18);

        // then
        assertEq(address(sut).balance, 0);
        assertEq(address(trader).balance, 1e18);
    }

    function testCollectBalanceEthTransferFailed() public {
        // given
        vm.deal(address(sut), 1e18);

        // expect
        vm.expectRevert("Address: insufficient balance");

        // when
        sut.collectBalance(address(0), trader, 10e18);
    }

    function testCollectBalanceToken() public {
        // given
        deal(address(testToken), address(sut), 1e18);

        // when
        vm.expectEmit(true, true, true, true);
        emit BalanceCollected(address(testToken), trader, 1e18);
        sut.collectBalance(address(testToken), trader, 1e18);

        // then
        assertEq(testToken.balanceOf(address(sut)), 0);
        assertEq(testToken.balanceOf(address(trader)), 1e18);
    }

    function testCollectBalanceTokenFailed() public {
        // given
        deal(address(testToken), address(sut), 1e18);

        // expect
        vm.expectRevert("ERC20: transfer amount exceeds balance");

        // when
        sut.collectBalance(address(testToken), trader, 10e18);
    }
}

contract BalancelessStub is Balanceless {
    function collectBalance(address token, address payable to, uint256 amount) external {
        _collectBalance(token, to, amount);
    }
}
