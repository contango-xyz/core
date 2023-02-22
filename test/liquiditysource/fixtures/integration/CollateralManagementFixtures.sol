//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../PositionFixtures.sol";

abstract contract CollateralManagementFixtures is PositionFixtures {
    using SafeCast for uint256;

    function _testAddCollateralToPosition(uint256 quantity, uint256 collateralToAdd) internal {
        // Open position
        (PositionId positionId,) = _openPosition(quantity);

        // Add collateral
        _modifyCollateral({positionId: positionId, collateral: collateralToAdd.toInt256()});

        // Close position
        _closePosition(positionId);
    }

    function _testRemoveCollateralOnPosition(uint256 quantity, uint256 collateral, int256 collateralToRemove) public {
        // Open position
        (PositionId positionId,) = _openPosition(quantity, collateral);

        // Remove collateral
        _modifyCollateral({positionId: positionId, collateral: collateralToRemove});

        // Close position
        _closePosition(positionId);
    }
}

// ========= Mainnet ==========

abstract contract MainnetCollateralManagementETHDAIFixtures is CollateralManagementFixtures {
    function testAddCollateralToPosition() public {
        _testAddCollateralToPosition({quantity: 20 ether, collateralToAdd: 500e18});
    }

    function testRemoveCollateralOnPosition() public {
        _testRemoveCollateralOnPosition({quantity: 20 ether, collateral: 20_000e18, collateralToRemove: -500e18});
    }
}

abstract contract MainnetCollateralManagementUSDCETHFixtures is CollateralManagementFixtures {
    function testAddCollateralToPosition() public {
        _testAddCollateralToPosition({quantity: 30_000e6, collateralToAdd: 0.5 ether});
    }

    function testRemoveCollateralOnPosition() public {
        _testRemoveCollateralOnPosition({quantity: 30_000e6, collateral: 12 ether, collateralToRemove: -0.5 ether});
    }
}

abstract contract MainnetCollateralManagementETHUSDCFixtures is CollateralManagementFixtures {
    function testAddCollateralToPosition() public {
        _testAddCollateralToPosition({quantity: 20 ether, collateralToAdd: 500e6});
    }

    function testRemoveCollateralOnPosition() public {
        _testRemoveCollateralOnPosition({quantity: 20 ether, collateral: 20_000e6, collateralToRemove: -500e6});
    }
}

// ========= Arbitrum ==========

abstract contract ArbitrumCollateralManagementETHDAIFixtures is CollateralManagementFixtures {
    function testAddCollateralToPosition() public {
        _testAddCollateralToPosition({quantity: 2 ether, collateralToAdd: 500e18});
    }

    function testRemoveCollateralOnPosition() public {
        _testRemoveCollateralOnPosition({quantity: 2 ether, collateral: 2_000e18, collateralToRemove: -500e18});
    }
}

abstract contract ArbitrumCollateralManagementUSDCETHFixtures is CollateralManagementFixtures {
    function testAddCollateralToPosition() public {
        _testAddCollateralToPosition({quantity: 10_000e6, collateralToAdd: 0.5 ether});
    }

    function testRemoveCollateralOnPosition() public {
        _testRemoveCollateralOnPosition({quantity: 10_000e6, collateral: 4 ether, collateralToRemove: -0.5 ether});
    }
}

abstract contract ArbitrumCollateralManagementETHUSDCFixtures is CollateralManagementFixtures {
    function testAddCollateralToPosition() public {
        _testAddCollateralToPosition({quantity: 2 ether, collateralToAdd: 500e6});
    }

    function testRemoveCollateralOnPosition() public {
        _testRemoveCollateralOnPosition({quantity: 2 ether, collateral: 2_000e6, collateralToRemove: -500e6});
    }
}
