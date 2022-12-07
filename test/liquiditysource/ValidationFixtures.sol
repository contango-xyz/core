//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/Strings.sol";

import "@yield-protocol/utils-v2/contracts/utils/RevertMsgExtractor.sol";

import "src/libraries/DataTypes.sol";
import "src/libraries/ErrorLib.sol";
import "src/liquiditysource/SlippageLib.sol";

import {WethHandler} from "src/batchable/WethHandler.sol";

import "./PositionFixtures.sol";

// solhint-disable func-name-mixedcase
abstract contract ValidationFixtures is PositionFixtures {
    using SignedMath for int256;

    event ClosingOnlySet(bool closingOnly);
    event UniswapFeeUpdated(Symbol indexed symbol, uint24 uniswapFee);

    uint256 internal maturity;

    constructor(Symbol _symbol, uint256 _maturity) {
        symbol = _symbol;
        maturity = _maturity;
    }

    function _expectUndercollateralisedRevert() internal virtual;

    function testCanNotCreatePositionInvalidInstrument() public {
        Symbol invalidInstrument = Symbol.wrap("invalid");
        vm.expectRevert(abi.encodeWithSelector(InvalidInstrument.selector, invalidInstrument));
        vm.prank(trader);
        contango.createPosition(invalidInstrument, trader, 1, 1, 1, trader, 0);
    }

    function testCanNotCreatePositionInvalidQuantity() public {
        uint128 invalidQuantity = 0;
        vm.expectRevert(abi.encodeWithSelector(InvalidQuantity.selector, invalidQuantity));
        contango.createPosition(symbol, trader, invalidQuantity, 1, 1, trader, 0);
    }

    function testCanNotCreatePositionInstrumentExpired() public {
        // given
        uint256 warpTimestamp = maturity + 1;

        // expect
        vm.expectRevert(abi.encodeWithSelector(InstrumentExpired.selector, symbol, maturity, warpTimestamp));

        // when
        vm.warp(warpTimestamp);
        vm.prank(trader);
        contango.createPosition(symbol, trader, 1, 1, 1, trader, 0);
    }

    function testCanNotIncreaseInvalidPosition() public {
        // given
        PositionId invalidPositionId = PositionId.wrap(1);

        // expect
        vm.expectRevert("ERC721: invalid token ID");

        // when
        vm.prank(trader);
        contango.modifyPosition({
            positionId: invalidPositionId,
            quantity: 1,
            limitCost: 1,
            collateral: 1,
            payerOrReceiver: trader,
            lendingLiquidity: 0
        });
    }

    function testCanNotIncreasePositionInvalidQuantity() public {
        (PositionId positionId,) = _openPosition(1 ether);

        int128 invalidQuantity = 0;
        vm.expectRevert(abi.encodeWithSelector(InvalidQuantity.selector, invalidQuantity));
        vm.prank(trader);
        contango.modifyPosition(positionId, invalidQuantity, 1, 1, trader, 0);
    }

    function testCanNotIncreaseExpiredPosition() public {
        // given
        uint256 warpTimestamp = maturity + 1;
        (PositionId positionId,) = _openPosition(1 ether);

        // expect
        vm.expectRevert(abi.encodeWithSelector(PositionExpired.selector, positionId, maturity, warpTimestamp));

        // when
        vm.warp(warpTimestamp);
        vm.prank(trader);
        contango.modifyPosition({
            positionId: positionId,
            quantity: 1,
            limitCost: 1,
            collateral: 1,
            payerOrReceiver: trader,
            lendingLiquidity: 0
        });
    }

    function testCanNotDecreaseInvalidPosition() public {
        // given
        PositionId invalidPositionId = PositionId.wrap(1);

        // expect
        vm.expectRevert("ERC721: invalid token ID");

        // when
        vm.prank(trader);
        contango.modifyPosition({
            positionId: invalidPositionId,
            quantity: -1,
            limitCost: 1,
            collateral: 1,
            payerOrReceiver: trader,
            lendingLiquidity: 0
        });
    }

    function testCanNotDecreaseExpiredPosition() public {
        // given
        uint256 warpTimestamp = maturity + 1;
        (PositionId positionId,) = _openPosition(1 ether);

        // expect
        vm.expectRevert(abi.encodeWithSelector(PositionExpired.selector, positionId, maturity, warpTimestamp));

        // when
        vm.warp(warpTimestamp);
        vm.prank(trader);
        contango.modifyPosition(positionId, 1, 1, 0, trader, 0);
    }

    function testCanNotDecreaseExcessQuantity() public {
        // given
        (PositionId positionId,) = _openPosition(1 ether);

        // expect
        vm.expectRevert(abi.encodeWithSelector(InvalidPositionDecrease.selector, positionId, -2 ether, 1 ether));

        // when
        vm.prank(trader);
        contango.modifyPosition({
            positionId: positionId,
            quantity: -2 ether,
            limitCost: 1,
            collateral: 1,
            payerOrReceiver: trader,
            lendingLiquidity: 0
        });
    }

    function testCanNotAddCollateralToInvalidPosition() public {
        // given
        PositionId invalidPositionId = PositionId.wrap(1);

        // expect
        vm.expectRevert("ERC721: invalid token ID");

        // when
        vm.prank(trader);
        contango.modifyCollateral(invalidPositionId, 1, 1, trader, 0);
    }

    function testCanNotAddCollateralToExpiredPosition() public {
        // given
        uint256 warpTimestamp = maturity + 1;
        (PositionId positionId,) = _openPosition(1 ether);

        // expect
        vm.expectRevert(abi.encodeWithSelector(PositionExpired.selector, positionId, maturity, warpTimestamp));

        // when
        vm.warp(warpTimestamp);
        vm.prank(trader);
        contango.modifyCollateral(positionId, 1, 1, trader, 0);
    }

    function testCanNotRemoveCollateralFromInvalidPosition() public {
        // given
        PositionId invalidPositionId = PositionId.wrap(1);

        // expect
        vm.expectRevert("ERC721: invalid token ID");

        // when
        vm.prank(trader);
        contango.modifyCollateral(invalidPositionId, 1, 1, trader, 0);
    }

    function testCanNotRemoveCollateralFromExpiredPosition() public {
        // given
        uint256 warpTimestamp = maturity + 1;
        (PositionId positionId,) = _openPosition(1 ether);

        // expect
        vm.expectRevert(abi.encodeWithSelector(PositionExpired.selector, positionId, maturity, warpTimestamp));

        // when
        vm.warp(warpTimestamp);
        vm.prank(trader);
        contango.modifyCollateral(positionId, 1, 1, trader, 0);
    }

    function testCanNotIncreasePositionThatBelongsToSomeoneElse() public {
        // given
        (PositionId positionId,) = _openPosition(1 ether);

        // expect
        address notTrader = utils.getNextUserAddress();
        vm.expectRevert(abi.encodeWithSelector(NotPositionOwner.selector, positionId, notTrader, trader));

        // when
        vm.prank(notTrader);
        contango.modifyPosition(positionId, 1, 1, 1, trader, 0);
    }

    function testCanNotDecreasePositionThatBelongsToSomeoneElse() public {
        // given
        (PositionId positionId,) = _openPosition(1 ether);

        // expect
        address notTrader = utils.getNextUserAddress();
        vm.expectRevert(abi.encodeWithSelector(NotPositionOwner.selector, positionId, notTrader, trader));

        // when
        vm.prank(notTrader);
        contango.modifyPosition(positionId, -1, 1, 0, trader, 0);
    }

    function testCanNotAddCollateralToPositionThatBelongsToSomeoneElse() public {
        // given
        (PositionId positionId,) = _openPosition(1 ether);

        // expect
        address notTrader = utils.getNextUserAddress();
        vm.expectRevert(abi.encodeWithSelector(NotPositionOwner.selector, positionId, notTrader, trader));

        // when
        vm.prank(notTrader);
        contango.modifyCollateral(positionId, 1, 1, notTrader, 0);
    }

    function testCanNotRemoveCollateralFromPositionThatBelongsToSomeoneElse() public {
        // given
        (PositionId positionId,) = _openPosition(1 ether);

        // expect
        address notTrader = utils.getNextUserAddress();
        vm.expectRevert(abi.encodeWithSelector(NotPositionOwner.selector, positionId, notTrader, trader));

        // when
        vm.prank(notTrader);
        contango.modifyCollateral(positionId, -1, 1, trader, 0);
    }

    function testCanNotCreatePositionAndMakeSomeoneElsePay() public {
        // expect
        address payer = utils.getNextUserAddress();
        vm.expectRevert(abi.encodeWithSelector(InvalidPayer.selector, positionNFT.nextPositionId(), payer));

        // when
        vm.prank(trader);
        contango.createPosition(symbol, trader, 1 ether, type(uint256).max, 3_000e6, payer, 0);
    }

    function testCanNotAddCollateralAndMakeSomeoneElsePay() public {
        // give
        (PositionId positionId,) = _openPosition(1 ether);

        // expect
        address payer = utils.getNextUserAddress();
        vm.expectRevert(abi.encodeWithSelector(InvalidPayer.selector, positionId, payer));

        // when
        vm.prank(trader);
        contango.modifyCollateral(positionId, 1_000e6, type(uint256).max, payer, 0);
    }

    function testCanNotIncreasePositionAndMakeSomeoneElsePay() public {
        // give
        (PositionId positionId,) = _openPosition(1 ether);

        // expect
        address payer = utils.getNextUserAddress();
        vm.expectRevert(abi.encodeWithSelector(InvalidPayer.selector, positionId, payer));

        // when
        vm.prank(trader);
        contango.modifyPosition(positionId, 1 ether, type(uint256).max, 2_000e6, payer, 0);
    }

    function testCanNotGetModifyCostForExpiredPosition() public {
        // given
        uint256 warpTimestamp = maturity + 1;
        (PositionId positionId,) = _openPosition(1 ether);

        // when
        vm.warp(warpTimestamp);
        (bool success, bytes memory data) = address(contangoQuoter).call(
            abi.encodeWithSelector(
                contangoQuoter.modifyCostForPosition.selector, ModifyCostParams(positionId, -1, 0, collateralSlippage)
            )
        );
        assertFalse(success);
        assertEq(data, abi.encodeWithSelector(PositionExpired.selector, positionId, maturity, warpTimestamp));
    }

    function testCanNotGetDeliveryCostForActivePosition() public {
        // given
        uint256 warpTimestamp = maturity - 1;
        (PositionId positionId,) = _openPosition(1 ether);

        // expect
        vm.expectRevert(abi.encodeWithSelector(PositionActive.selector, positionId, maturity, warpTimestamp));

        // when
        vm.warp(warpTimestamp);
        contangoQuoter.deliveryCostForPosition(positionId);
    }

    function testCanNotCreateUndercollateralisedPosition() public {
        // given
        (PositionId positionId,) = _openPosition(1 ether);

        // expect
        _expectUndercollateralisedRevert();

        // when
        vm.prank(trader);
        contango.modifyPosition(positionId, 1 ether, type(uint256).max, 0, trader, 0);
    }

    function testCanNotIncreaseUndercollateralisedPosition() public {
        // given
        (PositionId positionId,) = _openPosition(1 ether);

        // expect
        _expectUndercollateralisedRevert();

        // when
        vm.prank(trader);
        contango.modifyPosition(positionId, 1 ether, type(uint256).max, 0, trader, type(uint256).max);
    }

    function testCanNotRemoveCollateralUndercollateralisedPosition() public {
        // given
        (PositionId positionId,) = _openPosition(1 ether);

        // expect
        _expectUndercollateralisedRevert();

        // when
        vm.prank(trader);
        contango.modifyCollateral(positionId, -500e6, type(uint256).max, trader, 0);
    }

    function testPauseUnpausePermissions() public {
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(uint160(address(trader)), 20),
                " is missing role ",
                Strings.toHexString(uint256(contango.DEFAULT_ADMIN_ROLE()), 32)
            )
        );
        vm.prank(trader);
        contango.pause();

        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(uint160(address(trader)), 20),
                " is missing role ",
                Strings.toHexString(uint256(contango.DEFAULT_ADMIN_ROLE()), 32)
            )
        );
        vm.prank(trader);
        contango.unpause();
    }

    function testCanNotTradeWhenContractIsPaused() public {
        vm.prank(contangoTimelock);
        contango.pause();

        vm.expectRevert("Pausable: paused");
        contango.createPosition(Symbol.wrap(""), address(0), 0, 0, 0, address(0), 0);

        vm.expectRevert("Pausable: paused");
        contango.modifyPosition(PositionId.wrap(0), 0, 0, 0, address(0), 0);

        vm.expectRevert("Pausable: paused");
        contango.modifyPosition(PositionId.wrap(0), 0, 0, 0, address(0), 0);

        vm.expectRevert("Pausable: paused");
        contango.modifyCollateral(PositionId.wrap(0), 0, 0, address(0), 0);

        vm.expectRevert("Pausable: paused");
        contango.modifyCollateral(PositionId.wrap(0), 0, 0, address(0), 0);

        vm.expectRevert("Pausable: paused");
        contango.deliver(PositionId.wrap(0), address(0), address(0));
    }

    function testAddTrustedTokenPermissions(address token) public {
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(uint160(address(trader)), 20),
                " is missing role ",
                Strings.toHexString(uint256(contango.DEFAULT_ADMIN_ROLE()), 32)
            )
        );

        vm.prank(trader);
        contango.setTrustedToken(token, true);
    }

    function testBalancelessPermission(address token, address payable to, uint256 amount) public {
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(uint160(address(trader)), 20),
                " is missing role ",
                Strings.toHexString(uint256(contango.DEFAULT_ADMIN_ROLE()), 32)
            )
        );

        vm.prank(trader);
        contango.collectBalance(token, to, amount);
    }

    function testSetFeeModelPermissions() public {
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(uint160(address(trader)), 20),
                " is missing role ",
                Strings.toHexString(uint256(contango.DEFAULT_ADMIN_ROLE()), 32)
            )
        );

        vm.prank(trader);
        contango.setFeeModel(symbol, IFeeModel(address(0)));
    }

    function testSetInstrumentUniswapFeePermissions() public {
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(uint160(address(trader)), 20),
                " is missing role ",
                Strings.toHexString(uint256(contango.DEFAULT_ADMIN_ROLE()), 32)
            )
        );

        vm.prank(trader);
        contango.setInstrumentUniswapFee(symbol, 0);
    }

    function testSetInstrumentUniswapFeeInvalid() public {
        vm.expectRevert(abi.encodeWithSelector(InvalidInstrument.selector, bytes32("meh")));

        vm.prank(contangoTimelock);
        contango.setInstrumentUniswapFee(Symbol.wrap("meh"), 0);
    }

    function testCanNotSetClosingOnlyUnauthorised() public {
        address bob = address(0xb0b);
        vm.prank(bob);
        try contango.setClosingOnly(true) {
            revert("Should have failed");
        } catch (bytes memory reason) {
            assertEq(
                RevertMsgExtractor.getRevertMsg(reason),
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        Strings.toHexString(uint160(bob), 20),
                        " is missing role ",
                        Strings.toHexString(uint256(contango.DEFAULT_ADMIN_ROLE()), 32)
                    )
                )
            );
        }
    }

    function testCanNotCreatePositionWhenInClosingOnlyState() public {
        // expect
        vm.expectEmit(true, true, true, true);
        emit ClosingOnlySet(true);
        vm.prank(contangoTimelock);
        contango.setClosingOnly(true);

        vm.expectRevert(abi.encodeWithSelector(ClosingOnly.selector));
        vm.prank(trader);
        contango.createPosition(symbol, trader, 1 ether, type(uint256).max, 2_000e6, trader, 0);
    }

    function testCanNotIncreasePositionWhenInClosingOnlyState() public {
        // given
        (PositionId positionId,) = _openPosition(1 ether);

        // expect
        vm.expectEmit(true, true, true, true);
        emit ClosingOnlySet(true);
        vm.prank(contangoTimelock);
        contango.setClosingOnly(true);

        vm.expectRevert(abi.encodeWithSelector(ClosingOnly.selector));
        vm.prank(trader);
        contango.modifyPosition(positionId, 1 ether, type(uint256).max, 2_000e6, trader, 0);
    }

    function testCanCreatePositionAfterClosingOnlyIsReverted() public {
        // closingOnly = true
        vm.expectEmit(true, true, true, true);
        emit ClosingOnlySet(true);
        vm.prank(contangoTimelock);
        contango.setClosingOnly(true);

        vm.expectRevert(abi.encodeWithSelector(ClosingOnly.selector));
        vm.prank(trader);
        contango.createPosition(symbol, trader, 1 ether, type(uint256).max, 2_000e6, trader, 0);

        // closingOnly = false
        vm.expectEmit(true, true, true, true);
        emit ClosingOnlySet(false);
        vm.prank(contangoTimelock);
        contango.setClosingOnly(false);

        (PositionId positionId,) = _openPosition(1 ether);
        assertEq(contango.position(positionId).openQuantity, 1 ether);
    }

    function testCanIncreasePositionAfterClosingOnlyIsReverted() public {
        // given
        (PositionId positionId,) = _openPosition(1 ether);

        int256 increaseQuantity = 1 ether;
        int256 increaseCollateral = 2_000e6;
        dealAndApprove(address(quote), trader, uint256(increaseCollateral), address(contango));

        // closingOnly = true
        vm.expectEmit(true, true, true, true);
        emit ClosingOnlySet(true);
        vm.prank(contangoTimelock);
        contango.setClosingOnly(true);

        vm.expectRevert(abi.encodeWithSelector(ClosingOnly.selector));
        vm.prank(trader);
        contango.modifyPosition(positionId, increaseQuantity, type(uint256).max, increaseCollateral, trader, 0);

        // closingOnly = false
        vm.expectEmit(true, true, true, true);
        emit ClosingOnlySet(false);
        vm.prank(contangoTimelock);
        contango.setClosingOnly(false);

        vm.prank(trader);
        contango.modifyPosition(positionId, increaseQuantity, type(uint256).max, increaseCollateral, trader, 0);

        assertEq(contango.position(positionId).openQuantity, 2 ether);
    }

    function testFunctionNotFoundError() public {
        bool callResult;
        bytes4 sig = bytes4(keccak256("invalid()"));

        // low-level call results are flipped by foundry
        // https://book.getfoundry.sh/cheatcodes/expect-revert.html?highlight=expectRevert#expectrevert

        vm.expectRevert(abi.encodeWithSelector(FunctionNotFound.selector, sig));
        (callResult,) = address(contango).call(abi.encode(sig));
        assertTrue(callResult, "expectRevert: call did not revert");

        vm.expectRevert(abi.encodeWithSelector(FunctionNotFound.selector, sig));
        (callResult,) = address(contangoQuoter).call(abi.encode(sig));
        assertTrue(callResult, "expectRevert: call did not revert");
    }

    function testCanNotDecreasePositionSlippageExceeded() public {
        // given
        (PositionId positionId,) = _openPosition(2 ether);

        int256 decreaseQuantity = -1 ether;
        ModifyCostResult memory result =
            contangoQuoter.modifyCostForPosition(ModifyCostParams(positionId, decreaseQuantity, 0, collateralSlippage));

        uint256 insufficientLimitCost = result.cost.abs() + 1e6;

        // expect
        vm.expectRevert(
            abi.encodeWithSelector(SlippageLib.CostBelowTolerance.selector, insufficientLimitCost, result.cost)
        );

        // when
        vm.prank(trader);
        contango.modifyPosition(
            positionId,
            decreaseQuantity,
            insufficientLimitCost,
            result.collateralUsed,
            trader,
            result.quoteLendingLiquidity
        );
    }

    function testCanNotAddCollateralToPositionSlippageExceeded() public {
        // given
        (PositionId positionId,) = _openPosition(2 ether);

        ModifyCostResult memory result = contangoQuoter.modifyCostForPosition(
            ModifyCostParams({
                positionId: positionId,
                quantity: 0,
                collateral: 1_000e6,
                collateralSlippage: collateralSlippage
            })
        );
        dealAndApprove(address(quote), trader, uint256(result.collateralUsed), address(contango));

        uint256 insufficientSlippageTolerance = result.debtDelta.abs() + 1e6;

        // expect
        vm.expectRevert(
            abi.encodeWithSelector(
                SlippageLib.CostBelowTolerance.selector, insufficientSlippageTolerance, result.debtDelta.abs()
            )
        );

        // when
        vm.prank(trader);
        contango.modifyCollateral(
            positionId, result.collateralUsed, insufficientSlippageTolerance, trader, type(uint128).max
        );
    }

    function testCanNotRemoveCollateralFromPositionSlippageExceeded() public {
        // given
        (PositionId positionId,) = _openPosition(4 ether);
        uint256 collateralToRemove = 100e6;
        ModifyCostResult memory result = contangoQuoter.modifyCostForPosition(
            ModifyCostParams({
                positionId: positionId,
                quantity: 0,
                collateral: -int256(collateralToRemove),
                collateralSlippage: collateralSlippage
            })
        );

        uint256 insufficientSlippageTolerance = result.debtDelta.abs() - 1e6;

        // expect
        vm.expectRevert(
            abi.encodeWithSelector(
                SlippageLib.CostAboveTolerance.selector, insufficientSlippageTolerance, result.debtDelta.abs()
            )
        );

        // when
        vm.prank(trader);
        contango.modifyCollateral(positionId, -int256(collateralToRemove), insufficientSlippageTolerance, trader, 0);
    }

    function testFlashSwapCallback_InvalidAmountDeltas_BothNegative() public {
        // expect
        vm.expectRevert(abi.encodeWithSelector(UniswapV3Handler.InvalidAmountDeltas.selector, -1, -1));

        // when
        contango.uniswapV3SwapCallback({amount0Delta: -1, amount1Delta: -1, data: abi.encode("")});
    }

    function testFlashSwapCallback_InvalidAmountDeltas_BothPositive() public {
        // expect
        vm.expectRevert(abi.encodeWithSelector(UniswapV3Handler.InvalidAmountDeltas.selector, 1, 1));

        // when
        contango.uniswapV3SwapCallback({amount0Delta: 1, amount1Delta: 1, data: abi.encode("")});
    }

    function testFlashSwapCallback_InvalidPool() public {
        // given
        UniswapV3Handler.Callback memory callback;

        // expect
        vm.expectRevert("Invalid PoolKey");

        // when
        vm.prank(trader);
        contango.uniswapV3SwapCallback({amount0Delta: 0, amount1Delta: 0, data: abi.encode(callback)});
    }

    function testFlashSwapCallback_InvalidCaller() public {
        // given
        UniswapV3Handler.Callback memory callback;
        callback.instrument.base = base;
        callback.instrument.quote = quote;
        callback.instrument.uniswapFee = instrument.uniswapFee;

        // expect
        vm.expectRevert(abi.encodeWithSelector(UniswapV3Handler.InvalidCallbackCaller.selector, trader));

        // when
        vm.prank(trader);
        contango.uniswapV3SwapCallback({amount0Delta: 0, amount1Delta: 0, data: abi.encode(callback)});
    }

    function testFlashSwapCallback_InvalidHedgeAmount() public {
        // given
        UniswapV3Handler.Callback memory callback;
        callback.instrument.base = base;
        callback.instrument.quote = quote;
        callback.instrument.uniswapFee = instrument.uniswapFee;

        callback.fill.hedgeSize = 1 ether;

        address pool = PoolAddress.computeAddress(
            uniswapAddresses.UNISWAP_FACTORY,
            PoolAddress.getPoolKey(address(base), address(quote), instrument.uniswapFee)
        );

        // expect
        vm.expectRevert(
            abi.encodeWithSelector(
                UniswapV3Handler.InsufficientHedgeAmount.selector, callback.fill.hedgeSize, 0.5 ether
            )
        );

        // when
        vm.prank(pool);
        if (address(base) < address(quote)) {
            contango.uniswapV3SwapCallback({amount0Delta: 0.5 ether, amount1Delta: -1000e6, data: abi.encode(callback)});
        } else {
            contango.uniswapV3SwapCallback({amount0Delta: -1000e6, amount1Delta: 0.5 ether, data: abi.encode(callback)});
        }
    }

    function testChangeUniswapFee() public {
        uint256 quantity = 10 ether;

        ModifyCostResult memory oldQuote =
            contangoQuoter.openingCostForPosition(OpeningCostParams(symbol, quantity, 0, collateralSlippage));

        // switch between 0.3% and 0.05%
        uint24 newFee = instrument.uniswapFee == 0.3e4 ? 0.05e4 : 0.3e4;

        vm.expectEmit(true, true, false, false);
        emit UniswapFeeUpdated(symbol, newFee);
        vm.prank(contangoTimelock);
        contango.setInstrumentUniswapFee(symbol, newFee);

        ModifyCostResult memory newQuote =
            contangoQuoter.openingCostForPosition(OpeningCostParams(symbol, quantity, 0, collateralSlippage));

        assertTrue(newQuote.spotCost.abs() != oldQuote.spotCost.abs());
        assertTrue(newQuote.cost.abs() != oldQuote.cost.abs());

        // validates trading works

        // Open position
        (PositionId positionId,) = _openPosition(quantity);

        // Close position
        _closePosition(positionId);
    }
}
