//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import {DataTypes} from "@yield-protocol/vault-v2/contracts/interfaces/DataTypes.sol";
import {IPool} from "@yield-protocol/yieldspace-tv/src/interfaces/IPool.sol";
import {IPoolOracle} from "@yield-protocol/yieldspace-tv/src/interfaces/IPoolOracle.sol";
import {IJoin} from "@yield-protocol/vault-v2/contracts/interfaces/IJoin.sol";
import {IFYToken} from "@yield-protocol/vault-v2/contracts/interfaces/IFYToken.sol";
import {ILadle} from "@yield-protocol/vault-v2/contracts/interfaces/ILadle.sol";
import {ICauldron} from "@yield-protocol/vault-v2/contracts/interfaces/ICauldron.sol";
import {IOracle} from "@yield-protocol/vault-v2/contracts/interfaces/IOracle.sol";
import {IWitch} from "@yield-protocol/vault-v2/contracts/interfaces/IWitch.sol";
import {IContangoLadle} from "@yield-protocol/vault-v2/contracts/other/contango/interfaces/IContangoLadle.sol";

import "src/liquiditysource/yield-protocol/ContangoYield.sol";
import "src/liquiditysource/yield-protocol/ContangoYieldQuoter.sol";
import "./constants.sol";
import "../../ContangoTest.sol";

// solhint-disable-next-line max-states-count
abstract contract WithYieldProtocol is ContangoTest {
    using stdStorage for StdStorage;

    ContangoYield internal contangoYield;

    IWitch internal witch;
    IContangoLadle internal ladle;
    ICauldron internal cauldron;
    IPoolOracle internal poolOracle;

    address internal yieldTimelock;

    bytes6 internal baseSeriesId;
    bytes6 internal quoteSeriesId;
    Symbol private symbol;

    constructor(Symbol _symbol, bytes6 _baseSeriesId, bytes6 _quoteSeriesId) {
        symbol = _symbol;
        baseSeriesId = _baseSeriesId;
        quoteSeriesId = _quoteSeriesId;
    }

    function setUp() public virtual override {
        super.setUp();

        vm.deal(yieldTimelock, 50 ether);

        vm.label(address(ladle), "Ladle");
        vm.label(address(cauldron), "Cauldron");
        vm.label(address(witch), "Witch");
        vm.label(yieldTimelock, "YieldTimelock");
        vm.label(address(ladle.pools(baseSeriesId)), "BasePool");
        vm.label(address(ladle.pools(quoteSeriesId)), "QuotePool");
        vm.label(address(cauldron.series(baseSeriesId).fyToken), "BaseFYToken");
        vm.label(address(cauldron.series(quoteSeriesId).fyToken), "QuoteFYToken");

        contangoYield = ContangoYield(payable(address(contango)));
        contangoQuoter = new ContangoYieldQuoter(positionNFT, contangoYield, cauldron, quoter);

        ContangoYield impl = new ContangoYield(WETH9);
        vm.prank(contangoTimelock);
        contango.upgradeTo(address(impl));

        vm.label(contangoTimelock, "ContangoTimelock");
        vm.label(address(contangoQuoter), "ContangoYieldQuoter");
        vm.label(address(contango), "ContangoYield");
        vm.label(address(contangoYield), "ContangoYieldImpl");
    }
}

interface ICauldronExt {
    function setDebtLimits(bytes6 baseId, bytes6 ilkId, uint96 max, uint24 min, uint8 dec) external;
}

interface ICompositeMultiOracle {
    function setSource(bytes6 baseId, bytes6 quoteId, IOracle source) external;
}
