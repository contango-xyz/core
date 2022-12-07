//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Utilities} from "./utils/Utilities.sol";

import "@openzeppelin/contracts/utils/Strings.sol";

import {PositionId, ContangoPositionNFT} from "src/ContangoPositionNFT.sol";

contract ContangoPositionNFTTest is Test {
    Utilities private utils;

    address private trader1;
    address private trader2;
    address private minter;

    ContangoPositionNFT private sut;

    function setUp() public {
        utils = new Utilities();

        trader1 = utils.getNextUserAddress("Trader1");
        trader2 = utils.getNextUserAddress("Trader2");

        minter = utils.getNextUserAddress("Minter");

        sut = new ContangoPositionNFT();
        sut.grantRole(sut.MINTER(), minter);
    }

    function testMintIsProtected() public {
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(uint160(trader1), 20),
                " is missing role ",
                Strings.toHexString(uint256(sut.MINTER()), 32)
            )
        );

        vm.prank(trader1);
        sut.mint(trader1);
    }

    function testBurnIsProtected() public {
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(uint160(trader1), 20),
                " is missing role ",
                Strings.toHexString(uint256(sut.MINTER()), 32)
            )
        );

        vm.prank(trader1);
        sut.burn(PositionId.wrap(0));
    }

    function testMint() public {
        PositionId nextPositionId = sut.nextPositionId();

        vm.startPrank(minter);
        PositionId nft1 = sut.mint(trader1);
        PositionId nft2 = sut.mint(trader2);
        PositionId nft3 = sut.mint(trader1);

        assertEq(PositionId.unwrap(nextPositionId), 1);
        assertEq(PositionId.unwrap(nft1), 1);
        assertEq(PositionId.unwrap(nft2), 2);
        assertEq(PositionId.unwrap(nft3), 3);
        assertEq(PositionId.unwrap(sut.nextPositionId()), 4);

        assertEq(sut.balanceOf(trader1), 2);
        assertEq(sut.balanceOf(trader2), 1);
    }

    function testBurn() public {
        vm.startPrank(minter);
        PositionId nft1 = sut.mint(trader1);
        sut.mint(trader2);
        sut.mint(trader1);

        sut.burn(nft1);

        assertEq(PositionId.unwrap(sut.nextPositionId()), 4);

        assertEq(sut.balanceOf(trader1), 1);
        assertEq(sut.balanceOf(trader2), 1);
    }

    function testPositions() public {
        vm.startPrank(minter);
        sut.mint(trader1);
        sut.mint(trader1);
        sut.mint(trader2);
        sut.mint(trader1);
        sut.mint(trader2);

        PositionId[] memory tokens1 = sut.positions(trader1, PositionId.wrap(1), sut.nextPositionId());
        assertEq(tokens1.length, sut.balanceOf(trader1));
        assertEq(PositionId.unwrap(tokens1[0]), 1);
        assertEq(PositionId.unwrap(tokens1[1]), 2);
        assertEq(PositionId.unwrap(tokens1[2]), 4);

        PositionId[] memory tokens2 = sut.positions(trader2, PositionId.wrap(1), sut.nextPositionId());
        assertEq(tokens2.length, sut.balanceOf(trader2));
        assertEq(PositionId.unwrap(tokens2[0]), 3);
        assertEq(PositionId.unwrap(tokens2[1]), 5);
    }

    function testPositionsWithBurn() public {
        vm.startPrank(minter);
        sut.mint(trader1);
        sut.mint(trader1);
        sut.mint(trader2);
        sut.mint(trader1);
        sut.mint(trader2);

        sut.burn(PositionId.wrap(1));
        sut.burn(PositionId.wrap(5));

        PositionId[] memory tokens1 = sut.positions(trader1, PositionId.wrap(1), sut.nextPositionId());
        assertEq(tokens1.length, sut.balanceOf(trader1));
        assertEq(PositionId.unwrap(tokens1[0]), 2);
        assertEq(PositionId.unwrap(tokens1[1]), 4);

        PositionId[] memory tokens2 = sut.positions(trader2, PositionId.wrap(1), sut.nextPositionId());
        assertEq(tokens2.length, sut.balanceOf(trader2));
        assertEq(PositionId.unwrap(tokens2[0]), 3);
    }

    function testPositionsSlice() public {
        vm.startPrank(minter);
        sut.mint(trader1);
        sut.mint(trader1);
        sut.mint(trader2);
        sut.mint(trader1);
        sut.mint(trader2);
        sut.mint(trader1);

        PositionId[] memory tokens1 = sut.positions(trader1, PositionId.wrap(0), PositionId.wrap(1000));
        assertEq(tokens1.length, sut.balanceOf(trader1));
        assertEq(PositionId.unwrap(tokens1[0]), 1);
        assertEq(PositionId.unwrap(tokens1[1]), 2);
        assertEq(PositionId.unwrap(tokens1[2]), 4);
        assertEq(PositionId.unwrap(tokens1[3]), 6);

        tokens1 = sut.positions(trader1, PositionId.wrap(2), PositionId.wrap(5));
        assertEq(tokens1.length, sut.balanceOf(trader1));
        assertEq(PositionId.unwrap(tokens1[0]), 2);
        assertEq(PositionId.unwrap(tokens1[1]), 4);
        assertEq(PositionId.unwrap(tokens1[2]), 0);
        assertEq(PositionId.unwrap(tokens1[3]), 0);
    }

    function testSetPositionURIIsProtected() public {
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(uint160(trader1), 20),
                " is missing role ",
                Strings.toHexString(uint256(sut.ARTIST()), 32)
            )
        );

        vm.prank(trader1);
        sut.setPositionURI(PositionId.wrap(1), "url");
    }

    function testSetPositionURI() public {
        address bob = address(0xb0b);
        sut.grantRole(sut.ARTIST(), bob);

        vm.prank(minter);
        PositionId nft1 = sut.mint(trader1);

        vm.prank(bob);
        sut.setPositionURI(nft1, "https://example.com");

        assertEq(sut.positionURI(nft1), "https://example.com");
        assertEq(sut.tokenURI(PositionId.unwrap(nft1)), "https://example.com");
    }
}
