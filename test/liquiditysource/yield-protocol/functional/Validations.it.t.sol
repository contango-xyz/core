//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../fixtures/functional/ValidationFixtures.sol";
import "./WithYieldFixtures.sol";

import {IOraclePoolStub} from "../../../stub/IOraclePoolStub.sol";

// solhint-disable func-name-mixedcase
contract YieldValidationsTest is
    ValidationFixtures,
    WithYieldFixtures(constants.yETHUSDC2212, constants.FYETH2212, constants.FYUSDC2212)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();

        stubPrice({
            _base: WETH9,
            _quote: USDC,
            baseUsdPrice: 1400e6,
            quoteUsdPrice: 1e6,
            spread: 1e6,
            uniswapFee: uniswapFee
        });

        vm.etch(address(instrument.basePool), address(new IPoolStub(instrument.basePool)).code);
        vm.etch(address(instrument.quotePool), address(new IPoolStub(instrument.quotePool)).code);

        IPoolStub(address(instrument.basePool)).setBidAsk(0.945e18, 0.955e18);
        IPoolStub(address(instrument.quotePool)).setBidAsk(0.895e6, 0.905e6);

        symbol = Symbol.wrap("yETHUSDC2212-2");
        vm.prank(contangoTimelock);
        instrument = contangoYield.createYieldInstrumentV2(symbol, constants.FYETH2212, constants.FYUSDC2212, feeModel);

        vm.startPrank(yieldTimelock);
        compositeOracle.setSource(
            constants.FYETH2212,
            constants.ETH_ID,
            new IOraclePoolStub(IPoolStub(address(instrument.basePool)), constants.FYETH2212)
        );
        vm.stopPrank();

        _setPoolStubLiquidity(instrument.basePool, 1_000 ether);
        _setPoolStubLiquidity(instrument.quotePool, 1_000_000e6);
    }

    function _expectUndercollateralisedRevert() internal override {
        vm.expectRevert("Undercollateralized");
    }

    function _costBuffer() internal pure override returns (uint256) {
        return Yield.BORROWING_BUFFER;
    }

    function testCanNotCreateInstrumentAlreadyExists() public {
        vm.expectRevert(abi.encodeWithSelector(InstrumentAlreadyExists.selector, constants.yETHUSDC2212));
        vm.prank(contangoTimelock);
        contangoYield.createYieldInstrumentV2(
            constants.yETHUSDC2212, constants.FYETH2212, constants.FYUSDC2212, feeModel
        );
    }

    function testCanNotCreateInstrumentUnauthorised() public {
        address bob = address(0xb0b);

        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(uint160(bob), 20),
                " is missing role ",
                Strings.toHexString(uint256(contango.DEFAULT_ADMIN_ROLE()), 32)
            )
        );

        vm.prank(bob);
        contangoYield.createYieldInstrumentV2(Symbol.wrap("yETHUSDC2212_2"), bytes6(0), constants.FYUSDC2212, feeModel);
    }

    function testCanNotCreateInstrumentInvalidBaseId() public {
        vm.expectRevert(
            abi.encodeWithSelector(IContangoYieldAdmin.InvalidBaseId.selector, Symbol.wrap("yETHUSDC2212_2"), bytes6(0))
        );

        vm.prank(contangoTimelock);
        contangoYield.createYieldInstrumentV2(Symbol.wrap("yETHUSDC2212_2"), bytes6(0), constants.FYUSDC2212, feeModel);
    }

    function testCanNotCreateInstrumentInvalidQuoteId() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IContangoYieldAdmin.InvalidQuoteId.selector, Symbol.wrap("yETHUSDC2212_2"), bytes6(0)
            )
        );

        vm.prank(contangoTimelock);
        contangoYield.createYieldInstrumentV2(Symbol.wrap("yETHUSDC2212_2"), constants.FYETH2212, bytes6(0), feeModel);
    }

    //TODO re-instate when we have more that 1 maturity
    // function testCanNotCreateInstrumentMismatchedMaturity() public {
    //     vm.expectRevert(
    //         abi.encodeWithSelector(
    //             IContangoYieldAdmin.MismatchedMaturity.selector,
    //             Symbol.wrap("yETHUSDC2212_2"),
    //             constants.FYETH2212,
    //             constants.MATURITY_2212,
    //             constants.FYUSDC2206,
    //             constants.MATURITY_2206
    //         )
    //     );

    //     vm.prank(contangoTimelock);
    //     contangoYield.createYieldInstrumentV2(
    //         Symbol.wrap("yETHUSDC2212_2"),
    //         constants.FYETH2212,
    //         constants.FYUSDC2206,
    //         constants.FEE_0_05,
    //         feeModel
    //     );
    // }

    function shouldBeWitch(address caller) internal {
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(uint160(caller), 20),
                " is missing role ",
                Strings.toHexString(uint256(contangoYield.WITCH()), 32)
            )
        );
    }

    // TODO re-instate
    // function testCanNotFreellyCallWitchEndpoints() public {
    // address bob = address(0xb0b);

    // shouldBeWitch(bob);
    // vm.prank(bob);
    // contango.auctionStarted(bytes12(""));

    // shouldBeWitch(bob);
    // vm.prank(bob);
    // contango.auctionEnded(bytes12(""), address(0xf00));

    // shouldBeWitch(bob);
    // vm.prank(bob);
    // contango.collateralBought(bytes12(""), address(0), 0, 0);
    // }

    // TODO alfredo - move delivery validations to fixtures once it's implemented in Notional

    function testCanNotPhysicallyDeliverPositionThatBelongsToSomeoneElse() public {
        // given
        (PositionId positionId,) = _openPosition(1 ether);

        // expect
        address notTrader = utils.getNextUserAddress();
        vm.expectRevert(abi.encodeWithSelector(NotPositionOwner.selector, positionId, notTrader, trader));

        // when
        vm.prank(notTrader);
        contango.deliver(positionId, trader, trader);
    }

    function testCanNotPhysicallyDeliverInvalidPosition() public {
        // given
        PositionId invalidPositionId = PositionId.wrap(1);

        // expect
        vm.expectRevert("ERC721: invalid token ID");

        // when
        vm.prank(trader);
        contango.deliver(invalidPositionId, trader, trader);
    }

    function testCanNotPhysicallyDeliverActivePosition() public {
        // given
        uint256 warpTimestamp = constants.MATURITY_2212 - 1;
        (PositionId positionId,) = _openPosition(1 ether);

        // expect
        vm.expectRevert(
            abi.encodeWithSelector(PositionActive.selector, positionId, constants.MATURITY_2212, warpTimestamp)
        );

        // when
        vm.warp(warpTimestamp);
        vm.prank(trader);
        contango.deliver(positionId, trader, trader);
    }

    function testCanNotPhysicallyDeliverPositionAndMakeSomeoneElsePay() public {
        // give
        (PositionId positionId,) = _openPosition(1 ether);

        // expect
        address payer = utils.getNextUserAddress();
        vm.expectRevert(abi.encodeWithSelector(InvalidPayer.selector, positionId, payer));

        // when
        vm.prank(trader);
        contango.deliver(positionId, payer, trader);
    }
}
