// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import "solmate/src/tokens/ERC20.sol";

import "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";

import "forge-std/Test.sol";

import "solmate/src/tokens/WETH.sol";

import "src/libraries/DataTypes.sol";
import "src/interfaces/IContango.sol";
import "src/interfaces/IContangoAdmin.sol";
import "src/interfaces/IContangoView.sol";
import "src/interfaces/IContangoQuoter.sol";
import "src/liquiditysource/ContangoBase.sol";
import "src/ContangoPositionNFT.sol";

import "./stub/ChainlinkAggregatorV2V3Mock.sol";
import "./stub/UniswapPoolStub.sol";
import "./utils/Utilities.sol";
import "./utils/TestUtils.sol";

// solhint-disable-next-line contract-name-camelcase
library uniswapAddresses {
    address internal constant UNISWAP_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address internal constant UNISWAP_QUOTER = 0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6;
}

// solhint-disable max-states-count, var-name-mixedcase
abstract contract ContangoTestBase is Test, IContangoEvents, IContangoAdminEvents {
    uint256 public constant HIGH_LIQUIDITY = type(uint128).max;

    address payable internal trader = payable(address(0xb0b));
    mapping(address => bool) internal stubbedAddresses;

    ERC20 internal DAI;
    ERC20 internal USDC;
    ERC20 internal WBTC;
    WETH internal WETH9;
    ERC20 internal CUSDC;

    mapping(ERC20 => address) internal chainlinkUsdOracles;

    ContangoPositionNFT internal positionNFT;
    ContangoBase internal contango;
    IContangoView internal contangoView;
    IContangoQuoter internal contangoQuoter;
    IFeeModel internal feeModel;

    ERC20 internal base;
    ERC20 internal quote;
    uint256 maturity;

    uint256 internal blockNo;
    string internal chain;
    uint256 internal chainId;

    IQuoter internal quoter = IQuoter(uniswapAddresses.UNISWAP_QUOTER);

    Utilities internal utils;
    address payable internal sink;
    address internal treasury;
    address internal contangoTimelock;
    address internal contangoMultisig;

    uint256 internal collateralSlippage = 0.001e18;

    uint256 internal costBuffer;
    uint256 internal costBufferMultiplier = 1; // up to how many times buffer could be applied for tests where the positions were modified

    function setUp() public virtual {
        vm.label(trader, "Trader Bob");

        if (blockNo > 0) {
            vm.createSelectFork(chain, blockNo);
        } else {
            vm.createSelectFork(chain);
        }
        vm.chainId(chainId);

        vm.label(uniswapAddresses.UNISWAP_FACTORY, "UniswapFactory");
        vm.label(uniswapAddresses.UNISWAP_QUOTER, "UniswapQuoter");

        utils = new Utilities();
        sink = utils.getNextUserAddress("Sink");
    }

    function _deal(address token, address to, uint256 amount) internal virtual;

    function dealAndApprove(address token, address to, uint256 amount, address approveTo) internal {
        _deal(token, to, amount);
        vm.prank(to);
        ERC20(token).approve(approveTo, amount);
    }

    function clearBalance(address who, ERC20 token) internal {
        uint256 balance = token.balanceOf(who);
        vm.prank(who);
        token.transfer(sink, balance);
    }

    function clearBalanceETH(address who) internal {
        vm.prank(who);
        (bool success,) = sink.call{value: who.balance}("");
        assertEq(success, true);
    }

    modifier withinSnapshot() {
        uint256 snapshotId = vm.snapshot();
        _;
        vm.revertTo(snapshotId);
    }
}
