//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../ValidationFixtures.sol";
import "./WithYieldFixtures.sol";

import {IOraclePoolStub} from "../../../stub/IOraclePoolStub.sol";

// solhint-disable func-name-mixedcase
contract YieldValidationsTest is
    ValidationFixtures(constants.yETHUSDC2212, constants.MATURITY_2212),
    WithYieldFixtures(constants.yETHUSDC2212, constants.FYETH2212, constants.FYUSDC2212)
{
    using SignedMath for int256;
    using SafeCast for int256;

    function setUp() public override (WithYieldFixtures, ContangoTestBase) {
        super.setUp();

        stubPriceWETHUSDC(1400e6, 1e6);

        vm.etch(address(yieldInstrument.basePool), getCode(address(new IPoolStub(yieldInstrument.basePool))));
        vm.etch(address(yieldInstrument.quotePool), getCode(address(new IPoolStub(yieldInstrument.quotePool))));

        IPoolStub(address(yieldInstrument.basePool)).setBidAsk(0.945e18, 0.955e18);
        IPoolStub(address(yieldInstrument.quotePool)).setBidAsk(0.895e6, 0.905e6);

        symbol = Symbol.wrap("yETHUSDC2212-2");
        vm.prank(contangoTimelock);
        (instrument, yieldInstrument) = contangoYield.createYieldInstrument(
            symbol, constants.FYETH2212, constants.FYUSDC2212, constants.FEE_0_05, feeModel
        );

        vm.startPrank(yieldTimelock);
        ICompositeMultiOracle compositeOracle = ICompositeMultiOracle(0x750B3a18115fe090Bc621F9E4B90bd442bcd02F2);
        compositeOracle.setSource(
            constants.FYETH2212,
            constants.ETH_ID,
            new IOraclePoolStub(IPoolStub(address(yieldInstrument.basePool)), constants.FYETH2212)
        );
        vm.stopPrank();

        _setPoolStubLiquidity(yieldInstrument.basePool, 1_000 ether);
        _setPoolStubLiquidity(yieldInstrument.quotePool, 1_000_000e6);
    }

    function _expectUndercollateralisedRevert() internal override {
        vm.expectRevert("Undercollateralized");
    }

    function testCanNotCreateInstrumentAlreadyExists() public {
        vm.expectRevert(abi.encodeWithSelector(InstrumentAlreadyExists.selector, constants.yETHUSDC2212));
        vm.prank(contangoTimelock);
        contangoYield.createYieldInstrument(
            constants.yETHUSDC2212, constants.FYETH2212, constants.FYUSDC2212, constants.FEE_0_05, feeModel
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
        contangoYield.createYieldInstrument(
            Symbol.wrap("yETHUSDC2212_2"), bytes6(0), constants.FYUSDC2212, constants.FEE_0_05, feeModel
        );
    }

    function testCanNotCreateInstrumentInvalidBaseId() public {
        vm.expectRevert(
            abi.encodeWithSelector(YieldStorageLib.InvalidBaseId.selector, Symbol.wrap("yETHUSDC2212_2"), bytes6(0))
        );

        vm.prank(contangoTimelock);
        contangoYield.createYieldInstrument(
            Symbol.wrap("yETHUSDC2212_2"), bytes6(0), constants.FYUSDC2212, constants.FEE_0_05, feeModel
        );
    }

    function testCanNotCreateInstrumentInvalidQuoteId() public {
        vm.expectRevert(
            abi.encodeWithSelector(YieldStorageLib.InvalidQuoteId.selector, Symbol.wrap("yETHUSDC2212_2"), bytes6(0))
        );

        vm.prank(contangoTimelock);
        contangoYield.createYieldInstrument(
            Symbol.wrap("yETHUSDC2212_2"), constants.FYETH2212, bytes6(0), constants.FEE_0_05, feeModel
        );
    }

    //TODO re-instate when we have more that 1 maturity
    // function testCanNotCreateInstrumentMismatchedMaturity() public {
    //     vm.expectRevert(
    //         abi.encodeWithSelector(
    //             YieldStorageLib.MismatchedMaturity.selector,
    //             Symbol.wrap("yETHUSDC2212_2"),
    //             constants.FYETH2212,
    //             constants.MATURITY_2212,
    //             constants.FYUSDC2206,
    //             constants.MATURITY_2206
    //         )
    //     );

    //     vm.prank(contangoTimelock);
    //     contangoYield.createYieldInstrument(
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

    // TODO alfredo - figure out how to go around buffer

    function testCanNotCreatePositionSlippageExceeded() public {
        // given
        uint256 quantity = 1 ether;
        ModifyCostResult memory result =
            contangoQuoter.openingCostForPosition(OpeningCostParams(symbol, quantity, 0, collateralSlippage));
        dealAndApprove(address(quote), trader, result.minCollateral.toUint256(), address(contango));

        uint256 insufficientLimitCost = result.cost.abs() - 1e6;

        // expect
        vm.expectRevert(
            abi.encodeWithSelector(
                SlippageLib.CostAboveTolerance.selector,
                insufficientLimitCost,
                result.cost.abs() + Yield.BORROWING_BUFFER
            )
        );

        // when
        vm.prank(trader);
        contango.createPosition(
            symbol, trader, quantity, insufficientLimitCost, result.minCollateral.toUint256(), trader, type(uint128).max
        );
    }

    function testCanNotIncreasePositionSlippageExceeded() public {
        // given
        (PositionId positionId,) = _openPosition(1 ether);

        int256 increaseQuantity = 1 ether;
        ModifyCostResult memory result =
            contangoQuoter.modifyCostForPosition(ModifyCostParams(positionId, increaseQuantity, 0, collateralSlippage));
        dealAndApprove(address(quote), trader, result.minCollateral.toUint256(), address(contango));

        uint256 absCost = result.cost.abs() + Yield.BORROWING_BUFFER;
        uint256 insufficientLimitCost = absCost - 1e6;

        // expect
        vm.expectRevert(abi.encodeWithSelector(SlippageLib.CostAboveTolerance.selector, insufficientLimitCost, absCost));

        // when
        vm.prank(trader);
        contango.modifyPosition(
            positionId, increaseQuantity, insufficientLimitCost, result.minCollateral, trader, type(uint256).max
        );
    }
}
