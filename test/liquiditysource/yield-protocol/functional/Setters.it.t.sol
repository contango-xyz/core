//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@yield-protocol/utils-v2/src/utils/RevertMsgExtractor.sol";
import "src/libraries/DataTypes.sol";

import "../../fixtures/functional/SettersFixtures.sol";
import "./WithYieldFixtures.sol";

contract YieldSettersTest is
    SettersFixtures,
    WithYieldFixtures(constants.yETHUSDC2306, constants.FYETH2306, constants.FYUSDC2306)
{
    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }

    function testCreateInstrument() public {
        // given
        address expectedBaseFyToken = address(cauldron.series(constants.FYETH2306).fyToken);
        address expectedQuoteFyToken = address(cauldron.series(constants.FYDAI2306).fyToken);
        address expectedBasePool = address(ladle.pools(constants.FYETH2306));
        address expectedQuotePool = address(ladle.pools(constants.FYDAI2306));

        // expect
        vm.expectEmit(true, true, true, true);
        emit YieldInstrumentCreatedV2({
            symbol: Symbol.wrap("yETHDAI2306_2"),
            maturity: uint32(constants.MATURITY_2306),
            base: WETH9,
            quote: DAI,
            baseFyToken: IFYToken(expectedBaseFyToken),
            baseId: constants.FYETH2306,
            basePool: IPool(expectedBasePool),
            quoteFyToken: IFYToken(expectedQuoteFyToken),
            quoteId: constants.FYDAI2306,
            quotePool: IPool(expectedQuotePool)
        });

        // when
        vm.prank(contangoTimelock);
        YieldInstrument memory newInstrument = contangoYield.createYieldInstrumentV2(
            Symbol.wrap("yETHDAI2306_2"), constants.FYETH2306, constants.FYDAI2306, feeModel
        );

        assertEq(address(newInstrument.base), address(WETH9), "base");
        assertEq(address(newInstrument.baseFyToken), expectedBaseFyToken, "baseFyToken");
        assertEq(newInstrument.baseId, constants.FYETH2306, "baseId");
        assertEq(address(newInstrument.basePool), expectedBasePool, "basePool");

        assertEq(address(newInstrument.quote), address(DAI), "quote");
        assertEq(address(newInstrument.quoteFyToken), expectedQuoteFyToken, "quoteFyToken");
        assertEq(newInstrument.quoteId, constants.FYDAI2306, "quoteId");
        assertEq(address(newInstrument.quotePool), expectedQuotePool, "quotePool");

        assertEq(newInstrument.maturity, uint32(constants.MATURITY_2306), "maturity");
        assertFalse(newInstrument.closingOnly, "closingOnly");
        assertEqDecimal(newInstrument.minQuoteDebt, 40e18, 18, "minQuoteDebt");
    }
}
