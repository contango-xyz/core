//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "solmate/src/utils/SafeTransferLib.sol";

library TransferLib {
    using SafeTransferLib for ERC20;

    error ZeroPayer();
    error ZeroDestination();

    function transferOut(ERC20 token, address payer, address to, uint256 amount) internal returns (uint256) {
        if (payer == address(0)) revert ZeroPayer();
        if (to == address(0)) revert ZeroDestination();

        // If we are the payer, it's because the funds where transferred first or it was WETH wrapping
        payer == address(this) ? token.safeTransfer(to, amount) : token.safeTransferFrom(payer, to, amount);

        return amount;
    }
}
