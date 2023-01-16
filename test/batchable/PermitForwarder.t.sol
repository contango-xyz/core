// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../utils/Utilities.sol";
import "forge-std/Test.sol";

import "src/batchable/PermitForwarder.sol";

contract PermitForwarderTest is Test {
    event TokenTrusted(address indexed token, bool trusted);

    Utilities private utils;
    address private trader;

    Foo private sut;

    function setUp() public {
        utils = new Utilities();
        trader = utils.getNextUserAddress();

        sut = new Foo();
    }

    function testAddTrustedToken() public {
        address token = utils.getNextUserAddress("token");

        vm.expectEmit(true, true, true, true);
        emit TokenTrusted(token, true);
        sut.setTrustedToken(token, true);

        vm.expectEmit(true, true, true, true);
        emit TokenTrusted(token, false);
        sut.setTrustedToken(token, false);
    }

    function testForwardPermitToUntrustedToken() public {
        address token = utils.getNextUserAddress("token");
        vm.expectRevert(abi.encodeWithSelector(PermitForwarder.UnknownToken.selector, token));
        sut.forwardPermit(IERC20Permit(token), address(2), 0, 0, 0, "", "");
    }

    function testForwardDaiPermitToUntrustedToken() public {
        address token = utils.getNextUserAddress("token");
        vm.expectRevert(abi.encodeWithSelector(PermitForwarder.UnknownToken.selector, token));
        sut.forwardDaiPermit(DaiAbstract(token), address(2), 0, 0, true, 0, "", "");
    }

    function testForwardPermit(address spender, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        public
    {
        IERC20Permit token = new TokenWithPermit();

        sut.setTrustedToken(address(token), true);

        vm.expectCall(
            address(token),
            abi.encodeWithSelector(IERC20Permit.permit.selector, trader, spender, amount, deadline, v, r, s)
        );

        vm.prank(trader);
        sut.forwardPermit(token, spender, amount, deadline, v, r, s);
    }

    function testForwardDaiPermit(
        address spender,
        uint256 nonce,
        uint256 deadline,
        bool allowed,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        DaiAbstract token = DaiAbstract(utils.lenientMock("DaiAbstract"));

        sut.setTrustedToken(address(token), true);

        vm.expectCall(
            address(token),
            abi.encodeWithSelector(DaiAbstract.permit.selector, trader, spender, nonce, deadline, allowed, v, r, s)
        );

        vm.prank(trader);
        sut.forwardDaiPermit(token, spender, nonce, deadline, allowed, v, r, s);
    }
}

contract Foo is PermitForwarder {
    function setTrustedToken(address token, bool trusted) external {
        ConfigStorageLib.setTrustedToken(token, trusted);
    }
}

contract TokenWithPermit is IERC20Permit {
    mapping(address => uint256) public nonces;

    function permit(address owner, address, uint256, uint256, uint8, bytes32, bytes32) external {
        nonces[owner]++;
    }

    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external pure returns (bytes32) {
        return "DOMAIN_SEPARATOR";
    }
}
