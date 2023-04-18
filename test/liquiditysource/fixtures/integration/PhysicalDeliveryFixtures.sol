//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../PositionFixtures.sol";

abstract contract PhysicalDeliveryFixtures is PositionFixtures {
    // solhint-disable-next-line no-empty-blocks
    function _onWarpToMaturity() internal virtual {}

    // solhint-disable-next-line no-empty-blocks
    function _afterAllDeliveries() internal virtual {}

    function _testDeliverPosition(uint256 quantity) internal {
        // Given
        (PositionId positionId,) = _openPosition(quantity);

        // When
        vm.warp(maturity);
        _onWarpToMaturity();

        // Then
        _deliverPosition(positionId);

        _afterAllDeliveries();
    }

    function _testDeliverMultiplePositions(uint256 quantity) internal {
        // Given
        address payable traderAlice = utils.getNextUserAddress("Trader Alice");
        address payable traderJoe = utils.getNextUserAddress("Trader Joe");

        (PositionId alicePositionId,) = _openPosition(traderAlice, quantity, 2e18);
        (PositionId joePositionId,) = _openPosition(traderJoe, quantity, 2e18);

        // When
        vm.warp(maturity);
        _onWarpToMaturity();

        // Then
        _deliverPosition(alicePositionId);
        _deliverPosition(joePositionId);

        _afterAllDeliveries();
    }
}

// ========= Mainnet ==========

abstract contract MainnetPhysicalDeliveryETHDAIFixtures is PhysicalDeliveryFixtures {
    function testDeliverPosition() public {
        _testDeliverPosition(20 ether);
    }

    function testDeliverMultiplePositions() public {
        _testDeliverMultiplePositions(20 ether);
    }
}

abstract contract MainnetPhysicalDeliveryUSDCETHFixtures is PhysicalDeliveryFixtures {
    function testDeliverPosition() public {
        _testDeliverPosition(100_000e6);
    }

    function testDeliverMultiplePositions() public {
        _testDeliverMultiplePositions(100_000e6);
    }
}

abstract contract MainnetPhysicalDeliveryETHUSDCFixtures is PhysicalDeliveryFixtures {
    function testDeliverPosition() public {
        _testDeliverPosition(20 ether);
    }

    function testDeliverMultiplePositions() public {
        _testDeliverMultiplePositions(20 ether);
    }
}

abstract contract MainnetPhysicalDeliveryDAIUSDCFixtures is PhysicalDeliveryFixtures {
    function testDeliverPosition() public {
        _testDeliverPosition(100_000e18);
    }

    function testDeliverMultiplePositions() public {
        _testDeliverMultiplePositions(100_000e18);
    }
}

// ========= Arbitrum ==========

abstract contract ArbitrumPhysicalDeliveryETHDAIFixtures is PhysicalDeliveryFixtures {
    function testDeliverPosition() public {
        _testDeliverPosition(2 ether);
    }

    function testDeliverMultiplePositions() public {
        _testDeliverMultiplePositions(2 ether);
    }
}

abstract contract ArbitrumPhysicalDeliveryUSDCETHFixtures is PhysicalDeliveryFixtures {
    function testDeliverPosition() public {
        _testDeliverPosition(10_000e6);
    }

    function testDeliverMultiplePositions() public {
        _testDeliverMultiplePositions(10_000e6);
    }
}

abstract contract ArbitrumPhysicalDeliveryETHUSDCFixtures is PhysicalDeliveryFixtures {
    function testDeliverPosition() public {
        _testDeliverPosition(2 ether);
    }

    function testDeliverMultiplePositions() public {
        _testDeliverMultiplePositions(2 ether);
    }
}

abstract contract ArbitrumPhysicalDeliveryETHUSDTFixtures is PhysicalDeliveryFixtures {
    function testDeliverPosition() public {
        _testDeliverPosition(0.5 ether);
    }

    function testDeliverMultiplePositions() public {
        _testDeliverMultiplePositions(0.5 ether);
    }
}

abstract contract ArbitrumPhysicalDeliveryDAIUSDCFixtures is PhysicalDeliveryFixtures {
    function testDeliverPosition() public {
        _testDeliverPosition(10_000e18);
    }

    function testDeliverMultiplePositions() public {
        _testDeliverMultiplePositions(10_000e18);
    }
}
