// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/WrappedNFT.sol";
import "../src/mock/MockERC1155.sol";

contract WrappedNFTTest is Test {
    MockERC1155 mockERC1155;
    WrappedNFT wrappedNFT;
    address endpoint = address(0x1a44076050125825900e736c501f859c50fE728c);

    // Test Users
    address user1 = address(0x1);

    // Additional test users
    address user2 = address(0x2);
    address nonOwner = address(0x3);

    // Collections
    uint256 collectionId1;

    // Additional collections
    uint256 collectionId2;

    function setUp() public {
        vm.createSelectFork("https://eth-mainnet.g.alchemy.com/v2/mrB3N723jifPBUEJeW8oeaXhiUIy8bCi");
        mockERC1155 = new MockERC1155();
        wrappedNFT = new WrappedNFT(address(mockERC1155), endpoint, address(this));

        collectionId1 = uint256(uint160(address(this))) << 96 | uint256(1) << 56 | uint256(1);
        collectionId2 = uint256(uint160(address(this))) << 96 | uint256(2) << 56 | uint256(1);

        //creator (160 bits) || index (56 bits) || supply cap (40 bits)
        mockERC1155.mint(user1, collectionId1, 1);

        // Setup additional collection
        mockERC1155.mint(user1, collectionId2, 5);
    }

    function testWrap() external {
        assertEq(wrappedNFT.balanceOf(user1), 0);
        vm.prank(user1);
        mockERC1155.safeTransferFrom(user1, address(wrappedNFT), collectionId1, 1, "");
        assertEq(wrappedNFT.balanceOf(user1), 1);

        assertEq(wrappedNFT.ownerOf(collectionId1), user1);

        uint256[] memory ids = new uint256[](1);
        ids[0] = collectionId1;
        wrappedNFT.unwrap(ids, user1);
        assertEq(mockERC1155.balanceOf(user1, collectionId1), 1);
    }

    function testUnwrapFailWhenPaused() external {
        assertEq(wrappedNFT.balanceOf(user1), 0);
        vm.prank(user1);
        mockERC1155.safeTransferFrom(user1, address(wrappedNFT), collectionId1, 1, "");
        assertEq(wrappedNFT.balanceOf(user1), 1);

        assertEq(wrappedNFT.ownerOf(collectionId1), user1);

        wrappedNFT.pause();

        uint256[] memory ids = new uint256[](1);
        ids[0] = collectionId1;
        vm.expectRevert();
        wrappedNFT.unwrap(ids, user1);
    }

    function testBatchWrap() external {
        // Mint additional tokens to user1
        mockERC1155.mint(user1, collectionId1, 1);
        mockERC1155.mint(user1, collectionId2, 1);

        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = collectionId1;
        ids[1] = collectionId2;
        amounts[0] = 1;
        amounts[1] = 1;

        vm.prank(user1);
        mockERC1155.safeBatchTransferFrom(user1, address(wrappedNFT), ids, amounts, "");

        assertEq(wrappedNFT.balanceOf(user1), 2);
        assertEq(wrappedNFT.ownerOf(collectionId1), user1);
        assertEq(wrappedNFT.ownerOf(collectionId2), user1);
    }

    function testFailWrapInvalidValue() external {
        // Try to wrap with value > 1
        mockERC1155.mint(user1, collectionId1, 2);
        vm.prank(user1);
        mockERC1155.safeTransferFrom(user1, address(wrappedNFT), collectionId1, 2, "");
    }

    function testFailWrapInvalidCreator() external {
        // Create token with different creator
        uint256 invalidCollectionId = uint256(uint160(user2)) << 96 | uint256(1) << 56 | uint256(1);
        mockERC1155.mint(user1, invalidCollectionId, 1);

        vm.prank(user1);
        mockERC1155.safeTransferFrom(user1, address(wrappedNFT), invalidCollectionId, 1, "");
    }

    function testFailUnwrapNonOwner() external {
        // Setup: Wrap a token
        vm.prank(user1);
        mockERC1155.safeTransferFrom(user1, address(wrappedNFT), collectionId1, 1, "");

        // Try to unwrap from non-owner
        vm.prank(nonOwner);
        uint256[] memory ids = new uint256[](1);
        ids[0] = collectionId1;
        wrappedNFT.unwrap(ids, nonOwner);
    }

    function testAllBongBear() external {
        string memory data = vm.readFile("./test/Bongbear.json");
        IERC1155 opensea = IERC1155(address(0x495f947276749Ce646f68AC8c248420045cb7b5e));
        WrappedNFT mock =
            new WrappedNFT(address(opensea), endpoint, address(0x921560673F20465c118072FF3A70D0057096c123));

        for (uint256 i = 0; i <= 106; i++) {
            address owner = vm.parseJsonAddress(data, string.concat(".[", vm.toString(i), "].owner"));
            uint256 tokenId = vm.parseJsonUint(data, string.concat(".[", vm.toString(i), "].tokenId"));

            require(opensea.balanceOf(owner, tokenId) == 1, "Token not found");

            vm.prank(owner);
            opensea.safeTransferFrom(owner, address(mock), tokenId, 1, "");

            assertEq(mock.ownerOf(tokenId), owner);
        }
    }
}
