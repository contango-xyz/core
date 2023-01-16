//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@yield-protocol/utils-v2/contracts/utils/RevertMsgExtractor.sol";
import "src/libraries/DataTypes.sol";

import "../../fixtures/functional/SettersFixtures.sol";
import "./WithYieldFixtures.sol";

contract YieldSettersTest is
    SettersFixtures,
    WithYieldFixtures(constants.yETHUSDC2212, constants.FYETH2212, constants.FYUSDC2212)
{
    event YieldInstrumentCreated(Instrument instrument, YieldInstrument yieldInstrument);

    function setUp() public override(WithYieldFixtures, ContangoTestBase) {
        super.setUp();
    }

    function testCreateInstrument() public {
        // given
        address expectedBaseFyToken = address(cauldron.series(constants.FYETH2212).fyToken);
        address expectedQuoteFyToken = address(cauldron.series(constants.FYDAI2212).fyToken);
        address expectedBasePool = address(ladle.pools(constants.FYETH2212));
        address expectedQuotePool = address(ladle.pools(constants.FYDAI2212));

        // expect
        vm.expectEmit(true, true, true, true);
        emit YieldInstrumentCreated(
            Instrument({
                maturity: uint32(constants.MATURITY_2212),
                uniswapFeeTransient: 0,
                base: WETH9,
                quote: DAI,
                closingOnly: false
            }),
            YieldInstrument({
                baseFyToken: IFYToken(expectedBaseFyToken),
                baseId: constants.FYETH2212,
                basePool: IPool(expectedBasePool),
                quoteFyToken: IFYToken(expectedQuoteFyToken),
                quoteId: constants.FYDAI2212,
                quotePool: IPool(expectedQuotePool),
                minQuoteDebt: 40e18
            })
            );

        // when
        vm.prank(contangoTimelock);
        (Instrument memory newInstrument, YieldInstrument memory newYieldInstrument) = contangoYield
            .createYieldInstrument(Symbol.wrap("yETHDAI2212_2"), constants.FYETH2212, constants.FYDAI2212, feeModel);

        assertEq(address(newInstrument.base), address(WETH9), "base");
        assertEq(address(newYieldInstrument.baseFyToken), expectedBaseFyToken, "baseFyToken");
        assertEq(newYieldInstrument.baseId, constants.FYETH2212, "baseId");
        assertEq(address(newYieldInstrument.basePool), expectedBasePool, "basePool");

        assertEq(address(newInstrument.quote), address(DAI), "quote");
        assertEq(address(newYieldInstrument.quoteFyToken), expectedQuoteFyToken, "quoteFyToken");
        assertEq(newYieldInstrument.quoteId, constants.FYDAI2212, "quoteId");
        assertEq(address(newYieldInstrument.quotePool), expectedQuotePool, "quotePool");

        assertEq(newInstrument.maturity, uint32(constants.MATURITY_2212), "maturity");
        assertEq(newInstrument.uniswapFeeTransient, 0, "uniswapFee");
        assertEqDecimal(newYieldInstrument.minQuoteDebt, 40e18, 18, "minQuoteDebt");
    }
}
