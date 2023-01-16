//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "solmate/src/utils/SafeTransferLib.sol";
import "solmate/src/tokens/WETH.sol";
import "../dependencies/Balancer.sol";
import "../libraries/DataTypes.sol";
import "../ContangoPositionNFT.sol";
import "../interfaces/IContango.sol";
import "../interfaces/IContangoQuoter.sol";

contract CashSettler is IFlashLoanRecipient, IERC721Receiver {
    using SafeTransferLib for ERC20;
    using SafeTransferLib for address;
    using Address for address;

    event PositionSettled(
        Symbol indexed symbol,
        address indexed trader,
        PositionId indexed positionId,
        address to,
        uint256 equity,
        address spender,
        address dex
    );

    error NotBalancer(address sender);
    error NotPositionNFT(address sender);
    error NotWETH(address sender);

    struct NFTCallback {
        Symbol symbol;
        ERC20 base;
        ERC20 quote;
        uint256 openQuantity;
        address spender;
        address dex;
        bytes swapBytes;
        address to;
    }

    struct FlashLoanCallback {
        PositionId positionId;
        address owner;
        NFTCallback nftCb;
    }

    IFlashLoaner public constant BALANCER = IFlashLoaner(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    ContangoPositionNFT public immutable positionNFT;
    IContango public immutable contango;
    IContangoQuoter public immutable contangoQuoter;
    WETH public immutable weth;

    constructor(ContangoPositionNFT _positionNFT, IContango _contango, IContangoQuoter _contangoQuoter, WETH _weth) {
        positionNFT = _positionNFT;
        contango = _contango;
        contangoQuoter = _contangoQuoter;
        weth = _weth;
    }

    function onERC721Received(address, address from, uint256 tokenId, bytes calldata data)
        external
        override
        returns (bytes4)
    {
        if (msg.sender != address(positionNFT)) {
            revert NotPositionNFT(msg.sender);
        }

        NFTCallback memory nftCallback = abi.decode(data, (NFTCallback));
        PositionId positionId = PositionId.wrap(tokenId);

        address[] memory tokens = new address[](1);
        tokens[0] = address(nftCallback.quote);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = contangoQuoter.deliveryCostForPosition(positionId);

        BALANCER.flashLoan(
            this,
            tokens,
            amounts,
            abi.encode(FlashLoanCallback({positionId: positionId, owner: from, nftCb: nftCallback}))
        );

        return IERC721Receiver.onERC721Received.selector;
    }

    function receiveFlashLoan(
        address[] memory,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external override {
        if (msg.sender != address(BALANCER)) {
            revert NotBalancer(msg.sender);
        }

        FlashLoanCallback memory cb = abi.decode(userData, (FlashLoanCallback));

        cb.nftCb.quote.safeTransfer(address(contango), amounts[0]);
        contango.deliver(cb.positionId, address(contango), address(this));

        cb.nftCb.base.safeApprove(cb.nftCb.spender, cb.nftCb.openQuantity);
        cb.nftCb.dex.functionCall(cb.nftCb.swapBytes);

        cb.nftCb.quote.safeTransfer(msg.sender, amounts[0] + feeAmounts[0]);

        uint256 equity = _transferEquity(cb.nftCb.quote, cb.nftCb.to);

        emit PositionSettled({
            symbol: cb.nftCb.symbol,
            trader: cb.owner,
            positionId: cb.positionId,
            to: cb.nftCb.to,
            equity: equity,
            spender: cb.nftCb.spender,
            dex: cb.nftCb.dex
        });
    }

    function _transferEquity(ERC20 token, address to) internal returns (uint256 balance) {
        balance = token.balanceOf(address(this));

        if (balance > 0) {
            if (address(token) == address(weth)) {
                weth.withdraw(balance);
                to.safeTransferETH(balance);
            } else {
                token.safeTransfer(to, balance);
            }
        }
    }

    receive() external payable {
        if (msg.sender != address(weth)) {
            revert NotWETH(msg.sender);
        }
    }
}
