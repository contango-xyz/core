//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/Strings.sol";

import "@yield-protocol/utils-v2/src/utils/RevertMsgExtractor.sol";

import "src/libraries/DataTypes.sol";
import "src/libraries/Errors.sol";
import "src/liquiditysource/SlippageLib.sol";
import "src/liquiditysource/UniswapV3Handler.sol";

import "../PositionFixtures.sol";

// solhint-disable func-name-mixedcase
abstract contract ValidationFixtures is PositionFixtures {
    using SafeCast for int256;
    using SignedMath for int256;

    function _expectUndercollateralisedRevert() internal virtual;

    function _costBuffer() internal virtual returns (uint256) {
        return 0;
    }

    function testCanNotCreatePositionInvalidInstrument() public {
        Symbol invalidInstrument = Symbol.wrap("invalid");
        vm.expectRevert(abi.encodeWithSelector(InvalidInstrument.selector, invalidInstrument));
        vm.prank(trader);
        contango.createPosition(invalidInstrument, trader, 1, 1, 1, trader, 0, uniswapFee);
    }

    function testCanNotCreatePositionInvalidQuantity() public {
        uint128 invalidQuantity = 0;
        vm.expectRevert(abi.encodeWithSelector(InvalidQuantity.selector, invalidQuantity));
        contango.createPosition(symbol, trader, invalidQuantity, 1, 1, trader, 0, uniswapFee);
    }

    function testCanNotCreatePositionInstrumentExpired() public {
        // given
        uint256 warpTimestamp = maturity + 1;

        // expect
        vm.expectRevert(abi.encodeWithSelector(InstrumentExpired.selector, symbol, maturity, warpTimestamp));

        // when
        vm.warp(warpTimestamp);
        vm.prank(trader);
        contango.createPosition(symbol, trader, 1, 1, 1, trader, 0, uniswapFee);
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
            lendingLiquidity: 0,
            uniswapFee: 0
        });
    }

    function testCanNotIncreasePositionInvalidQuantity() public {
        (PositionId positionId,) = _openPosition(1 ether);

        int128 invalidQuantity = 0;
        vm.expectRevert(abi.encodeWithSelector(InvalidQuantity.selector, invalidQuantity));
        vm.prank(trader);
        contango.modifyPosition(positionId, invalidQuantity, 1, 1, trader, 0, uniswapFee);
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
            lendingLiquidity: 0,
            uniswapFee: 0
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
            lendingLiquidity: 0,
            uniswapFee: 0
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
        contango.modifyPosition(positionId, 1, 1, 0, trader, 0, uniswapFee);
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
            lendingLiquidity: 0,
            uniswapFee: 0
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
        contango.modifyPosition(positionId, 1, 1, 1, trader, 0, uniswapFee);
    }

    function testCanNotDecreasePositionThatBelongsToSomeoneElse() public {
        // given
        (PositionId positionId,) = _openPosition(1 ether);

        // expect
        address notTrader = utils.getNextUserAddress();
        vm.expectRevert(abi.encodeWithSelector(NotPositionOwner.selector, positionId, notTrader, trader));

        // when
        vm.prank(notTrader);
        contango.modifyPosition(positionId, -1, 1, 0, trader, 0, uniswapFee);
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
        contango.createPosition(symbol, trader, 1 ether, type(uint256).max, 3_000e6, payer, 0, uniswapFee);
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
        contango.modifyPosition(positionId, 1 ether, type(uint256).max, 2_000e6, payer, 0, uniswapFee);
    }

    function testCanNotGetModifyCostForExpiredPosition() public {
        // given
        uint256 warpTimestamp = maturity + 1;
        (PositionId positionId,) = _openPosition(1 ether);

        // when
        vm.warp(warpTimestamp);
        (bool success, bytes memory data) = address(contangoQuoter).call(
            abi.encodeWithSelector(
                contangoQuoter.modifyCostForPositionWithCollateral.selector,
                ModifyCostParams(positionId, -1, collateralSlippage, uniswapFee),
                0
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
        contango.modifyPosition(positionId, 1 ether, type(uint256).max, 0, trader, 0, uniswapFee);
    }

    function testCanNotIncreaseUndercollateralisedPosition() public {
        // given
        (PositionId positionId,) = _openPosition(1 ether);

        // expect
        _expectUndercollateralisedRevert();

        // when
        vm.prank(trader);
        contango.modifyPosition(positionId, 1 ether, type(uint256).max, 0, trader, type(uint256).max, uniswapFee);
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
                Strings.toHexString(uint256(contango.EMERGENCY_BREAK()), 32)
            )
        );
        vm.prank(trader);
        contango.pause();

        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(uint160(address(trader)), 20),
                " is missing role ",
                Strings.toHexString(uint256(contango.EMERGENCY_BREAK()), 32)
            )
        );
        vm.prank(trader);
        contango.unpause();
    }

    function testCanNotTradeWhenContractIsPaused() public {
        vm.prank(contangoMultisig);
        contango.pause();

        vm.expectRevert("Pausable: paused");
        contango.createPosition(Symbol.wrap(""), address(0), 0, 0, 0, address(0), 0, uniswapFee);

        vm.expectRevert("Pausable: paused");
        contango.modifyPosition(PositionId.wrap(0), 0, 0, 0, address(0), 0, uniswapFee);

        vm.expectRevert("Pausable: paused");
        contango.modifyPosition(PositionId.wrap(0), 0, 0, 0, address(0), 0, uniswapFee);

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

    function testBalancelessPermission(ERC20 token, address payable to, uint256 amount) public {
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
                        Strings.toHexString(uint256(contango.OPERATOR()), 32)
                    )
                )
            );
        }
    }

    function testCanCreatePositionAfterClosingOnlyIsReverted() public {
        // closingOnly = true
        vm.expectEmit(true, true, true, true);
        emit ClosingOnlySet(true);
        vm.prank(contangoMultisig);
        contango.setClosingOnly(true);

        vm.expectRevert(ClosingOnly.selector);
        contangoQuoter.openingCostForPositionWithCollateral(
            OpeningCostParams(symbol, 1 ether, collateralSlippage, uniswapFee), 2_000e6
        );

        vm.expectRevert(ClosingOnly.selector);
        vm.prank(trader);
        contango.createPosition(symbol, trader, 1 ether, type(uint256).max, 2_000e6, trader, 0, uniswapFee);

        // closingOnly = false
        vm.expectEmit(true, true, true, true);
        emit ClosingOnlySet(false);
        vm.prank(contangoMultisig);
        contango.setClosingOnly(false);

        contangoQuoter.openingCostForPositionWithCollateral(
            OpeningCostParams(symbol, 1 ether, collateralSlippage, uniswapFee), 2_000e6
        );

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
        vm.prank(contangoMultisig);
        contango.setClosingOnly(true);

        vm.expectRevert(ClosingOnly.selector);
        contangoQuoter.modifyCostForPositionWithCollateral(
            ModifyCostParams(positionId, increaseQuantity, collateralSlippage, uniswapFee), increaseCollateral
        );

        vm.expectRevert(ClosingOnly.selector);
        vm.prank(trader);
        contango.modifyPosition(
            positionId, increaseQuantity, type(uint256).max, increaseCollateral, trader, 0, uniswapFee
        );

        // closingOnly = false
        vm.expectEmit(true, true, true, true);
        emit ClosingOnlySet(false);
        vm.prank(contangoMultisig);
        contango.setClosingOnly(false);

        contangoQuoter.modifyCostForPositionWithCollateral(
            ModifyCostParams(positionId, increaseQuantity, collateralSlippage, uniswapFee), increaseCollateral
        );

        vm.prank(trader);
        contango.modifyPosition(
            positionId, increaseQuantity, type(uint256).max, increaseCollateral, trader, 0, uniswapFee
        );

        assertEq(contango.position(positionId).openQuantity, 2 ether);
    }

    function testCanCreatePositionAfterInstrumentClosingOnlyIsReverted() public {
        bool closingOnly = true;
        vm.expectEmit(true, false, false, true);
        emit ClosingOnlySet(symbol, closingOnly);
        vm.prank(contangoMultisig);
        contango.setClosingOnly(symbol, closingOnly);

        vm.expectRevert(abi.encodeWithSelector(InstrumentClosingOnly.selector, symbol));
        contangoQuoter.openingCostForPositionWithCollateral(
            OpeningCostParams(symbol, 1 ether, collateralSlippage, uniswapFee), 2_000e6
        );

        vm.expectRevert(abi.encodeWithSelector(InstrumentClosingOnly.selector, symbol));
        vm.prank(trader);
        contango.createPosition(symbol, trader, 1 ether, type(uint256).max, 2_000e6, trader, 0, uniswapFee);

        closingOnly = false;
        vm.expectEmit(true, true, true, true);
        emit ClosingOnlySet(symbol, closingOnly);
        vm.prank(contangoMultisig);
        contango.setClosingOnly(symbol, closingOnly);

        contangoQuoter.openingCostForPositionWithCollateral(
            OpeningCostParams(symbol, 1 ether, collateralSlippage, uniswapFee), 2_000e6
        );

        (PositionId positionId,) = _openPosition(1 ether);
        assertEq(contango.position(positionId).openQuantity, 1 ether);
    }

    function testCanIncreasePositionAfterInstrumentClosingOnlyIsReverted() public {
        // given
        (PositionId positionId,) = _openPosition(1 ether);

        int256 increaseQuantity = 1 ether;
        int256 increaseCollateral = 2_000e6;
        dealAndApprove(address(quote), trader, uint256(increaseCollateral), address(contango));

        // closingOnly = true
        vm.expectEmit(true, true, true, true);
        emit ClosingOnlySet(symbol, true);
        vm.prank(contangoMultisig);
        contango.setClosingOnly(symbol, true);

        vm.expectRevert(abi.encodeWithSelector(InstrumentClosingOnly.selector, symbol));
        contangoQuoter.modifyCostForPositionWithCollateral(
            ModifyCostParams(positionId, increaseQuantity, collateralSlippage, uniswapFee), increaseCollateral
        );

        vm.expectRevert(abi.encodeWithSelector(InstrumentClosingOnly.selector, symbol));
        vm.prank(trader);
        contango.modifyPosition(
            positionId, increaseQuantity, type(uint256).max, increaseCollateral, trader, 0, uniswapFee
        );

        // closingOnly = false
        vm.expectEmit(true, true, true, true);
        emit ClosingOnlySet(symbol, false);
        vm.prank(contangoMultisig);
        contango.setClosingOnly(symbol, false);

        contangoQuoter.modifyCostForPositionWithCollateral(
            ModifyCostParams(positionId, increaseQuantity, collateralSlippage, uniswapFee), increaseCollateral
        );

        vm.prank(trader);
        contango.modifyPosition(
            positionId, increaseQuantity, type(uint256).max, increaseCollateral, trader, 0, uniswapFee
        );

        assertEq(contango.position(positionId).openQuantity, 2 ether);
    }

    function testCanNotCreatePositionSlippageExceeded() public {
        // given
        uint256 quantity = 1 ether;
        ModifyCostResult memory result = contangoQuoter.openingCostForPositionWithCollateral(
            OpeningCostParams(symbol, quantity, collateralSlippage, uniswapFee), 0
        );
        dealAndApprove(address(quote), trader, result.minCollateral.toUint256(), address(contango));

        uint256 insufficientLimitCost = result.cost.abs() - 1e6;

        // expect
        vm.expectRevert(
            abi.encodeWithSelector(
                SlippageLib.CostAboveTolerance.selector, insufficientLimitCost, result.cost.abs() + _costBuffer()
            )
        );

        // when
        vm.prank(trader);
        contango.createPosition(
            symbol,
            trader,
            quantity,
            insufficientLimitCost,
            result.minCollateral.toUint256(),
            trader,
            type(uint128).max,
            uniswapFee
        );
    }

    function testCanNotIncreasePositionSlippageExceeded() public {
        // given
        (PositionId positionId,) = _openPosition(1 ether);

        int256 increaseQuantity = 1 ether;
        ModifyCostResult memory result = contangoQuoter.modifyCostForPositionWithCollateral(
            ModifyCostParams(positionId, increaseQuantity, collateralSlippage, uniswapFee), 0
        );
        dealAndApprove(address(quote), trader, result.minCollateral.toUint256(), address(contango));

        uint256 absCost = result.cost.abs();
        uint256 insufficientLimitCost = absCost - 1e6;

        // when
        vm.prank(trader);
        (bool success, bytes memory data) = address(contango).call(
            abi.encodeWithSelector(
                contango.modifyPosition.selector,
                positionId,
                increaseQuantity,
                insufficientLimitCost,
                result.minCollateral,
                trader,
                type(uint256).max,
                uniswapFee
            )
        );

        // then
        assertFalse(success);
        (uint256 limitCost, uint256 actualCost) = abi.decode(removeSelector(data), (uint256, uint256));
        assertEqDecimal(limitCost, insufficientLimitCost, quoteDecimals, "limitCost");
        assertApproxEqAbsDecimal(actualCost, absCost + _costBuffer(), 1, quoteDecimals, "actualCost");
    }

    function testCanNotDecreasePositionSlippageExceeded() public {
        // given
        (PositionId positionId,) = _openPosition(2 ether);

        int256 decreaseQuantity = -1 ether;
        ModifyCostResult memory result = contangoQuoter.modifyCostForPositionWithCollateral(
            ModifyCostParams(positionId, decreaseQuantity, collateralSlippage, uniswapFee), 0
        );

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
            result.quoteLendingLiquidity,
            uniswapFee
        );
    }

    function testCanNotAddCollateralToPositionSlippageExceeded() public {
        // given
        (PositionId positionId,) = _openPosition(2 ether);

        ModifyCostResult memory result = contangoQuoter.modifyCostForPositionWithCollateral(
            ModifyCostParams({
                positionId: positionId,
                quantity: 0,
                collateralSlippage: collateralSlippage,
                uniswapFee: uniswapFee
            }),
            1_000e6
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
        ModifyCostResult memory result = contangoQuoter.modifyCostForPositionWithCollateral(
            ModifyCostParams({
                positionId: positionId,
                quantity: 0,
                collateralSlippage: collateralSlippage,
                uniswapFee: uniswapFee
            }),
            -int256(collateralToRemove)
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
        callback.info.uniswapFee = 500;

        // expect
        vm.expectRevert(abi.encodeWithSelector(UniswapV3Handler.InvalidCallbackCaller.selector, address(this)));

        // when
        vm.prank(address(this));
        contango.uniswapV3SwapCallback({amount0Delta: 0, amount1Delta: 0, data: abi.encode(callback)});
    }

    function testFlashSwapCallback_InvalidHedgeAmount() public {
        // given
        UniswapV3Handler.Callback memory callback;
        callback.instrument.base = base;
        callback.instrument.quote = quote;
        callback.info.uniswapFee = 500;

        callback.fill.hedgeSize = 1 ether;

        address pool = PoolAddress.computeAddress(
            uniswapAddresses.UNISWAP_FACTORY, PoolAddress.getPoolKey(address(base), address(quote), 500)
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
}
