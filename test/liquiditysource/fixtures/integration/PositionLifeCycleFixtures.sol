//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../PositionFixtures.sol";

abstract contract PositionLifeCycleFixtures is PositionFixtures {
    using SafeCast for uint256;

    function _testOpenAndClose(uint256 quantity) internal {
        // Open position
        (PositionId positionId,) = _openPosition(quantity);

        // Close position
        _closePosition(positionId);
    }

    function _testOpenReduceAndClose(uint256 quantity, int256 reduceQuantity) internal {
        // Open position
        (PositionId positionId,) = _openPosition(quantity);

        // Reduce position
        _modifyPosition({positionId: positionId, quantity: reduceQuantity, collateral: 0});

        // Close position
        _closePosition(positionId);
    }

    function _testOpenIncreaseAndClose(uint256 quantity, uint256 increaseQuantity, uint256 collateralToAdd) internal {
        // Open position
        (PositionId positionId,) = _openPosition(quantity);

        // Increase position
        _modifyPosition({
            positionId: positionId,
            quantity: increaseQuantity.toInt256(),
            collateral: collateralToAdd.toInt256()
        });

        // Close position
        _closePosition(positionId);
    }

    function _testOpenReduceDepositMaxAndClosePosition(uint256 quantity, int256 reduceQuantity) internal {
        // Open position
        (PositionId positionId,) = _openPosition(quantity);

        // Reduce position
        _modifyPosition({positionId: positionId, quantity: reduceQuantity, collateral: type(int256).max});

        // Close position
        _closePosition(positionId);
    }
}

// ========= Mainnet ==========

abstract contract MainnetPositionLifeCycleDAIETHFixtures is PositionLifeCycleFixtures {
    function testOpenAndClose() public {
        _testOpenAndClose({quantity: 100_000e18});
    }

    function testOpenReduceAndClose() public {
        _testOpenReduceAndClose({quantity: 100_000e18, reduceQuantity: -1_000e18});
    }

    function testOpenIncreaseAndClose() public {
        _testOpenIncreaseAndClose({quantity: 100_000e18, increaseQuantity: 5_000e18, collateralToAdd: 2.5 ether});
    }

    function testOpenReduceDepositMaxAndClosePosition() public {
        _testOpenReduceDepositMaxAndClosePosition({quantity: 100_000e18, reduceQuantity: -1_000e18});
    }
}

abstract contract MainnetPositionLifeCycleETHUSDCFixtures is PositionLifeCycleFixtures {
    function testOpenAndClose() public {
        _testOpenAndClose({quantity: 20 ether});
    }

    function testOpenReduceAndClose() public {
        _testOpenReduceAndClose({quantity: 20 ether, reduceQuantity: -0.5 ether});
    }

    function testOpenIncreaseAndClose() public {
        _testOpenIncreaseAndClose({quantity: 20 ether, increaseQuantity: 0.5 ether, collateralToAdd: 300e6});
    }

    function testOpenReduceDepositMaxAndClosePosition() public {
        _testOpenReduceDepositMaxAndClosePosition({quantity: 20 ether, reduceQuantity: -0.25 ether});
    }
}

abstract contract MainnetPositionLifeCycleETHDAIFixtures is PositionLifeCycleFixtures {
    function testOpenAndClose() public {
        _testOpenAndClose({quantity: 20 ether});
    }

    function testOpenReduceAndClose() public {
        _testOpenReduceAndClose({quantity: 20 ether, reduceQuantity: -0.5 ether});
    }

    function testOpenIncreaseAndClose() public {
        _testOpenIncreaseAndClose({quantity: 20 ether, increaseQuantity: 0.5 ether, collateralToAdd: 300e18});
    }

    function testOpenReduceDepositMaxAndClosePosition() public {
        _testOpenReduceDepositMaxAndClosePosition({quantity: 20 ether, reduceQuantity: -0.25 ether});
    }
}

// ========= Arbitrum ==========

abstract contract ArbitrumPositionLifeCycleDAIETHFixtures is PositionLifeCycleFixtures {
    function testOpenAndClose() public {
        _testOpenAndClose({quantity: 10_000e18});
    }

    function testOpenReduceAndClose() public {
        _testOpenReduceAndClose({quantity: 10_000e18, reduceQuantity: -2_500e18});
    }

    function testOpenIncreaseAndClose() public {
        _testOpenIncreaseAndClose({quantity: 10_000e18, increaseQuantity: 2_500e18, collateralToAdd: 1.5 ether});
    }

    function testOpenReduceDepositMaxAndClosePosition() public {
        _testOpenReduceDepositMaxAndClosePosition({quantity: 10_000e18, reduceQuantity: -2_500e18});
    }
}

abstract contract ArbitrumPositionLifeCycleETHUSDCFixtures is PositionLifeCycleFixtures {
    function testOpenAndClose() public {
        _testOpenAndClose({quantity: 2 ether});
    }

    function testOpenReduceAndClose() public {
        _testOpenReduceAndClose({quantity: 2 ether, reduceQuantity: -0.25 ether});
    }

    function testOpenIncreaseAndClose() public {
        _testOpenIncreaseAndClose({quantity: 2 ether, increaseQuantity: 0.25 ether, collateralToAdd: 300e6});
    }

    function testOpenReduceDepositMaxAndClosePosition() public {
        _testOpenReduceDepositMaxAndClosePosition({quantity: 2 ether, reduceQuantity: -0.25 ether});
    }
}

abstract contract ArbitrumPositionLifeCycleETHDAIFixtures is PositionLifeCycleFixtures {
    function testOpenAndClose() public {
        _testOpenAndClose({quantity: 2 ether});
    }

    function testOpenReduceAndClose() public {
        _testOpenReduceAndClose({quantity: 2 ether, reduceQuantity: -0.25 ether});
    }

    function testOpenIncreaseAndClose() public {
        _testOpenIncreaseAndClose({quantity: 2 ether, increaseQuantity: 0.25 ether, collateralToAdd: 300e18});
    }

    function testOpenReduceDepositMaxAndClosePosition() public {
        _testOpenReduceDepositMaxAndClosePosition({quantity: 2 ether, reduceQuantity: -0.25 ether});
    }
}
