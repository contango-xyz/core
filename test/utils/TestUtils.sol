// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/math/SignedMath.sol";

//common utilities for forge tests
library TestUtils {
    using SignedMath for int256;

    function first(Vm.Log[] memory logs, bytes memory _event) internal pure returns (Vm.Log memory) {
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256(_event)) {
                return logs[i];
            }
        }
        revert(string.concat(string(_event), " not found"));
    }

    function slippage(int256 cost) internal pure returns (uint256) {
        if (cost < 0) {
            return (cost.abs() * 1.001e18) / 1e18;
        }
        if (cost > 0) {
            return (uint256(cost) * 0.999e18) / 1e18;
        }

        return 0;
    }
}
