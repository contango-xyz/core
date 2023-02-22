//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@yield-protocol/yieldspace-tv/src/interfaces/IPool.sol";
import "@yield-protocol/yieldspace-tv/src/interfaces/IMaturingToken.sol";
import "@yield-protocol/utils-v2/contracts/token/ERC20Permit.sol";
import "@yield-protocol/utils-v2/contracts/token/IERC20Metadata.sol";

contract IPoolStub is IPool, ERC20Permit {
    error NotImplemented(string f);

    IERC20 public immutable override base;
    IMaturingToken public immutable override fyToken;
    uint32 public immutable override maturity;

    uint256 public bid;
    uint256 public ask;

    uint112 private baseCached;
    uint112 private fyTokenCached;

    constructor(IPool delegate)
        ERC20Permit(
            string(abi.encodePacked(IERC20Metadata(address(delegate.fyToken())).name(), " LP")),
            string(abi.encodePacked(IERC20Metadata(address(delegate.fyToken())).symbol(), "LP")),
            IERC20Metadata(address(delegate.fyToken())).decimals()
        )
    {
        base = delegate.base();
        fyToken = delegate.fyToken();
        maturity = uint32(fyToken.maturity());
    }

    function setBidAsk(uint128 _bid, uint128 _ask) external {
        bid = _bid;
        ask = _ask;
        sync();
    }

    function sync() public {
        _update(getBaseBalance(), getFYTokenBalance());
    }

    function _update(uint128 baseBalance, uint128 fyBalance) private {
        baseCached = uint112(baseBalance);
        fyTokenCached = uint112(fyBalance);
    }

    function ts() external pure override returns (int128) {
        revert NotImplemented("ts");
    }

    function g1() external pure override returns (int128) {
        revert NotImplemented("g1");
    }

    function g2() external pure override returns (int128) {
        revert NotImplemented("g2");
    }

    function scaleFactor() external view override returns (uint96) {
        return uint96(10 ** (18 - baseToken().decimals()));
    }

    function getCache() external pure returns (uint104, uint104, uint32, uint16) {
        revert NotImplemented("getCache");
    }

    function getBaseBalance() public view override returns (uint128) {
        return uint128(base.balanceOf(address(this)));
    }

    function getFYTokenBalance() public view override returns (uint128) {
        return uint128(fyToken.balanceOf(address(this)));
    }

    function retrieveBase(address /* to */ ) external pure override returns (uint128 /* retrieved */ ) {
        // TV pools don't properly implement this method
        // retrieved = getBaseBalance() - baseCached;
        // base.transfer(to, retrieved);
        revert NotImplemented("retrieveBase");
    }

    function retrieveFYToken(address to) external override returns (uint128 retrieved) {
        retrieved = getFYTokenBalance() - fyTokenCached;
        fyToken.transfer(to, retrieved);
    }

    error Balances(uint256 actual, uint256 cached);

    function sellBase(address to, uint128 /* min */ ) external override returns (uint128 fyTokenOut) {
        uint128 _baseBalance = getBaseBalance();
        uint128 _fyTokenBalance = getFYTokenBalance();
        uint128 baseIn = _baseBalance - baseCached;
        fyTokenOut = sellBasePreview(baseIn);
        fyToken.transfer(to, fyTokenOut);
        _update(_baseBalance, _fyTokenBalance - fyTokenOut);
    }

    function buyBase(address to, uint128 baseOut, uint128 max) external override returns (uint128 fyTokenIn) {
        fyTokenIn = buyBasePreview(baseOut);
        require(fyTokenIn <= max, "too much fyToken in");

        base.transfer(to, baseOut);
        _update(baseCached - baseOut, fyTokenCached + fyTokenIn);
    }

    function sellFYToken(address to, uint128 /* min */ ) external override returns (uint128 baseOut) {
        uint128 _fyTokenBalance = getFYTokenBalance();
        uint128 _baseBalance = getBaseBalance();
        uint128 fyTokenIn = _fyTokenBalance - fyTokenCached;
        baseOut = sellFYTokenPreview(fyTokenIn);
        base.transfer(to, baseOut);
        _update(_baseBalance - baseOut, _fyTokenBalance);
    }

    function buyFYToken(address to, uint128 fyTokenOut, uint128 max) external override returns (uint128 baseIn) {
        baseIn = buyFYTokenPreview(fyTokenOut);
        require(baseIn <= max, "too much base in");

        fyToken.transfer(to, fyTokenOut);
        _update(baseCached + baseIn, fyTokenCached - fyTokenOut);
    }

    function sellBasePreview(uint128 baseIn) public view override returns (uint128) {
        require(baseIn > 0, "sellBasePreview: Can't quote 0 baseIn");
        require(maxBaseIn() >= baseIn, "Not enough liquidity");
        return sellBasePreviewUnsafe(baseIn);
    }

    function buyBasePreview(uint128 baseOut) public view override returns (uint128) {
        require(baseOut > 0, "buyBasePreview: Can't quote 0 baseOut");
        require(maxBaseOut() >= baseOut, "Not enough liquidity");
        return uint128((baseOut * 10 ** decimals) / bid);
    }

    function sellFYTokenPreview(uint128 fyTokenIn) public view override returns (uint128) {
        require(fyTokenIn > 0, "sellFYTokenPreview: Can't quote 0 fyTokenIn");
        require(maxFYTokenIn() >= fyTokenIn, "Not enough liquidity");
        return sellFYTokenPreviewUnsafe(fyTokenIn);
    }

    function buyFYTokenPreview(uint128 fyTokenOut) public view override returns (uint128) {
        require(fyTokenOut > 0, "buyFYTokenPreview: Can't quote 0 fyTokenOut");
        require(maxFYTokenOut() >= fyTokenOut, "Not enough liquidity");
        return uint128((fyTokenOut * ask) / 10 ** decimals);
    }

    function sellBasePreviewUnsafe(uint128 baseIn) public view returns (uint128) {
        return uint128((baseIn * 10 ** decimals) / ask);
    }

    function sellFYTokenPreviewUnsafe(uint128 fyTokenIn) public view returns (uint128) {
        return uint128((fyTokenIn * bid) / 10 ** decimals);
    }

    function mint(
        address,
        /* to */
        address,
        /* remainder */
        uint256,
        /* minRatio */
        uint256 /* maxRatio */
    ) external pure override returns (uint256, uint256, uint256) {
        revert NotImplemented("mint");
    }

    function mintWithBase(
        address, /* to */
        address, /* remainder */
        uint256, /* fyTokenToBuy */
        uint256, /* minRatio */
        uint256 /* maxRatio */
    ) external pure override returns (uint256, uint256, uint256) {
        revert NotImplemented("mintWithBase");
    }

    function burn(
        address,
        /* baseTo */
        address,
        /* fyTokenTo */
        uint256,
        /* minRatio */
        uint256 /* maxRatio */
    ) external pure override returns (uint256, uint256, uint256) {
        revert NotImplemented("burn");
    }

    function burnForBase(
        address,
        /* to */
        uint256,
        /* minRatio */
        uint256 /* maxRatio */
    ) external pure override returns (uint256, uint256) {
        revert NotImplemented("burnForBase");
    }

    function baseToken() public view returns (IERC20Metadata) {
        return IERC20Metadata(address(base));
    }

    function cumulativeRatioLast() external pure returns (uint256) {
        revert NotImplemented("cumulativeRatioLast");
    }

    function currentCumulativeRatio() external pure returns (uint256, uint256) {
        revert NotImplemented("currentCumulativeRatio");
    }

    function getC() external pure returns (int128) {
        revert NotImplemented("getC");
    }

    function getCurrentSharePrice() external pure returns (uint256) {
        revert NotImplemented("getCurrentSharePrice");
    }

    function getSharesBalance() external pure returns (uint128) {
        revert NotImplemented("getSharesBalance");
    }

    function init(address) external pure returns (uint256, uint256, uint256) {
        revert NotImplemented("init");
    }

    function mu() external pure returns (int128) {
        revert NotImplemented("mu");
    }

    function retrieveShares(address) external pure returns (uint128) {
        revert NotImplemented("retrieveShares");
    }

    function setFees(uint16) external pure {
        revert NotImplemented("setFees");
    }

    function sharesToken() external pure returns (IERC20Metadata) {
        revert NotImplemented("sharesToken");
    }

    function unwrap(address) external pure returns (uint256) {
        revert NotImplemented("unwrap");
    }

    function unwrapPreview(uint256) external pure returns (uint256) {
        revert NotImplemented("unwrapPreview");
    }

    function wrap(address) external pure returns (uint256) {
        revert NotImplemented("wrap");
    }

    function wrapPreview(uint256) external pure returns (uint256) {
        revert NotImplemented("wrapPreview");
    }

    function maxFYTokenOut() public view override returns (uint128) {
        return getFYTokenBalance();
    }

    function maxFYTokenIn() public view override returns (uint128 _maxFYTokenIn) {
        uint128 _maxBaseOut = maxBaseOut();
        if (_maxBaseOut > 0) {
            _maxFYTokenIn = buyBasePreview(_maxBaseOut);
        }
    }

    function maxBaseIn() public view override returns (uint128 _maxBaseIn) {
        uint128 _maxFYTokenOut = maxFYTokenOut();
        if (_maxFYTokenOut > 0) {
            _maxBaseIn = buyFYTokenPreview(_maxFYTokenOut);
        }
    }

    function maxBaseOut() public view override returns (uint128) {
        return getBaseBalance();
    }

    function invariant() external pure override returns (uint128) {
        revert NotImplemented("invariant");
    }
}
