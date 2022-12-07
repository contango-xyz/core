// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IQuoter} from "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";

import "forge-std/Test.sol";

import {IWETH9} from "src/dependencies/IWETH9.sol";

import "src/libraries/DataTypes.sol";
import {IContangoView} from "src/interfaces/IContangoView.sol";
import {IContangoQuoter} from "src/interfaces/IContangoQuoter.sol";
import {ContangoBase} from "src/liquiditysource/ContangoBase.sol";
import {ContangoPositionNFT} from "src/ContangoPositionNFT.sol";

import {ChainlinkAggregatorV2V3Mock} from "./stub/ChainlinkAggregatorV2V3Mock.sol";
import "./stub/UniswapPoolStub.sol";
import {Utilities} from "./utils/Utilities.sol";
import {TestUtils} from "./utils/TestUtils.sol";

// solhint-disable-next-line contract-name-camelcase
library uniswapAddresses {
    address internal constant UNISWAP_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address internal constant UNISWAP_QUOTER = 0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6;
}

// solhint-disable max-states-count, var-name-mixedcase
abstract contract ContangoTestBase is Test {
    event ContractTraded(PositionId indexed positionId, Fill fill);

    uint256 public constant HIGH_LIQUIDITY = type(uint128).max;

    address payable internal trader = payable(address(0xb0b));
    mapping(address => bool) internal stubbedAddresses;

    IERC20Metadata internal DAI;
    IERC20Metadata internal USDC;
    IERC20Metadata internal WBTC;
    IWETH9 internal WETH;

    ContangoPositionNFT internal positionNFT;
    ContangoBase internal contango;
    IContangoView internal contangoView;
    IContangoQuoter internal contangoQuoter;
    IFeeModel internal feeModel;

    IERC20Metadata internal base;
    IERC20Metadata internal quote;

    uint256 internal blockNo;
    string internal chain;
    uint256 internal chainId;

    IQuoter internal quoter = IQuoter(uniswapAddresses.UNISWAP_QUOTER);

    Utilities internal utils;
    address payable internal sink;
    address internal treasury;
    address internal contangoTimelock;

    uint256 internal collateralSlippage = 0.001e18;

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
        IERC20(token).approve(approveTo, amount);
    }

    function clearBalance(address who, IERC20Metadata token) internal {
        uint256 balance = token.balanceOf(who);
        vm.prank(who);
        token.transfer(sink, balance);
    }

    function clearBalanceETH(address who) internal {
        vm.prank(who);
        (bool success,) = sink.call{value: who.balance}("");
        assertEq(success, true);
    }

    // TODO remove if/when this gets merged https://github.com/foundry-rs/forge-std/pull/191

    function assertApproxEqAbsDecimal(uint256 a, uint256 b, uint256 maxDelta, uint256 decimals) internal virtual {
        uint256 delta = stdMath.delta(a, b);

        if (delta > maxDelta) {
            emit log("Error: a ~= b not satisfied [uint]");
            emit log_named_decimal_uint("  Expected", b, decimals);
            emit log_named_decimal_uint("    Actual", a, decimals);
            emit log_named_decimal_uint(" Max Delta", maxDelta, decimals);
            emit log_named_decimal_uint("     Delta", delta, decimals);
            fail();
        }
    }

    function assertApproxEqAbsDecimal(uint256 a, uint256 b, uint256 maxDelta, uint256 decimals, string memory err)
        internal
        virtual
    {
        uint256 delta = stdMath.delta(a, b);

        if (delta > maxDelta) {
            emit log_named_string("Error", err);
            assertApproxEqAbsDecimal(a, b, maxDelta, decimals);
        }
    }

    function assertApproxEqAbsDecimal(int256 a, int256 b, uint256 maxDelta, uint256 decimals) internal virtual {
        uint256 delta = stdMath.delta(a, b);

        if (delta > maxDelta) {
            emit log("Error: a ~= b not satisfied [int]");
            emit log_named_decimal_int("  Expected", b, decimals);
            emit log_named_decimal_int("    Actual", a, decimals);
            emit log_named_decimal_uint(" Max Delta", maxDelta, decimals);
            emit log_named_decimal_uint("     Delta", delta, decimals);
            fail();
        }
    }

    function assertApproxEqAbsDecimal(int256 a, int256 b, uint256 maxDelta, uint256 decimals, string memory err)
        internal
        virtual
    {
        uint256 delta = stdMath.delta(a, b);

        if (delta > maxDelta) {
            emit log_named_string("Error", err);
            assertApproxEqAbsDecimal(a, b, maxDelta, decimals);
        }
    }
}
