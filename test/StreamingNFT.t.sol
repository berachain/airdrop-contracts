// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/StreamingNFT.sol";
import "../src/mock/TestERC20.sol";
import "../src/mock/TestERC721.sol";
import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";

contract StreamingNFTTest is Test {
    using FixedPointMathLib for uint256;

    StreamingNFT public streamingNFT;
    TestERC721 public mockNFT;

    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public user3 = address(0x3);

    uint256 public constant VESTING_DURATION = 100;
    uint256 public constant INSTANT_UNLOCK = 5e17; // 50%
    uint256 public constant CLIFF_UNLOCK = 5e17; // 50% of remaining. eg 25%
    uint256 public constant ALLOCATION = 10 ether;

    // Block number constants
    uint256 public constant INITIAL_BLOCK = 1;
    uint256 public constant VESTING_START_OFFSET = 10;
    uint256 public constant CLIFF_ENDS = INITIAL_BLOCK + VESTING_START_OFFSET;
    uint256 public constant TEST_BLOCK_OFFSET = 20; // Number of blocks to move forward for testing
    uint256 public constant GAS_FEE = 0.1 ether;

    function setUp() public {
        mockNFT = new TestERC721(address(this), "Test NFT", "TEST");

        uint256[] memory blacklistedTokenIds = new uint256[](1);
        blacklistedTokenIds[0] = 1000; // blocklist id 1000
        streamingNFT =
            new StreamingNFT(address(0), VESTING_DURATION, INSTANT_UNLOCK, CLIFF_UNLOCK, address(mockNFT), ALLOCATION, blacklistedTokenIds);

        vm.deal(address(streamingNFT), 10000 ether);
        vm.warp(INITIAL_BLOCK);

        mockNFT.mint(user1);
        mockNFT.mint(user1);

        streamingNFT.setCliffEndTimestamp(CLIFF_ENDS);
        streamingNFT.setFee(GAS_FEE);
        streamingNFT.setPayMaster(user3, true);
    }

    function testCreateStream() public {
        vm.startPrank(user1, user1);
        vm.warp(CLIFF_ENDS + 1); // One block after vesting starts

        uint256 balanceBefore = user1.balance;
        streamingNFT.createStream(0);

        assertEq(mockNFT.ownerOf(0), user1);
        assertEq(user1.balance - balanceBefore, ALLOCATION.mulWad(INSTANT_UNLOCK));

        vm.stopPrank();
    }

    function testCreateStreamWithBlacklistedTokenId() public {
        vm.startPrank(user1, user1);
        vm.warp(CLIFF_ENDS + 1);
        vm.expectRevert();
        streamingNFT.createStream(1000);
        vm.stopPrank();
    }

    function testCreateBatchStreamWithBlacklistedTokenId() public {
        vm.startPrank(user1, user1);
        vm.warp(CLIFF_ENDS + 1);
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 999;
        tokenIds[1] = 1000;

        vm.expectRevert();
        streamingNFT.createBatchStream(tokenIds, user1);
        vm.stopPrank();
    }

    function testCreateBatchStreamWithNonPayMaster() public {
        vm.warp(CLIFF_ENDS + 1); // One block after vesting starts

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        vm.expectRevert();
        vm.prank(user2, user2);
        streamingNFT.createBatchStream(tokenIds, user1);
    }

    function testCreateBatchStreamWithoutPayMaster() public {
        vm.startPrank(user1, user1);
        vm.warp(CLIFF_ENDS + 1); // One block after vesting starts

        uint256 balanceBefore = user1.balance;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        streamingNFT.createBatchStream(tokenIds, user1);

        assertEq(mockNFT.ownerOf(0), user1);
        assertEq(user1.balance - balanceBefore, ALLOCATION.mulWad(INSTANT_UNLOCK));

        vm.stopPrank();
    }

    function testCreateBatchStreamWithPayMaster() public {
        vm.startPrank(user3, user3);
        vm.warp(CLIFF_ENDS + 1); // One block after vesting starts

        uint256 user1BalanceBefore = user1.balance;
        uint256 user3BalanceBefore = user3.balance;

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        streamingNFT.createBatchStream(tokenIds, user1);

        assertEq(mockNFT.ownerOf(0), user1);
        assertEq(user1.balance - user1BalanceBefore, ALLOCATION.mulWad(INSTANT_UNLOCK) - GAS_FEE);
        assertEq(user3.balance - user3BalanceBefore, GAS_FEE);

        vm.stopPrank();
    }

    function testClaimRewards() public {
        vm.startPrank(user1, user1);
        vm.warp(CLIFF_ENDS + 1);
        streamingNFT.createStream(0);

        uint256 balanceAfterCreate = user1.balance;

        // Move forward in time
        vm.warp(CLIFF_ENDS + TEST_BLOCK_OFFSET);

        streamingNFT.claimRewards(0);

        uint256 remainingRewards = ALLOCATION - ALLOCATION.mulWad(INSTANT_UNLOCK);
        uint256 bias = remainingRewards.mulWad(CLIFF_UNLOCK);
        uint256 vestedRewards = remainingRewards - bias;
        uint256 expectedRewards = (vestedRewards * TEST_BLOCK_OFFSET) / VESTING_DURATION + bias;

        assertEq(user1.balance - balanceAfterCreate, expectedRewards);

        vm.stopPrank();
    }

    function testTransferStreamNFT() public {
        vm.startPrank(user1, user1);
        vm.warp(CLIFF_ENDS + 1);
        streamingNFT.createStream(0);

        uint256 user2BalanceBefore = user2.balance;

        vm.warp(CLIFF_ENDS + TEST_BLOCK_OFFSET);
        mockNFT.transferFrom(user1, user2, 0);

        assertEq(mockNFT.ownerOf(0), user2);
        assertEq(user2.balance - user2BalanceBefore, 0);

        vm.stopPrank();
    }

    function testFailCreateStreamTwice() public {
        vm.startPrank(user1, user1);
        vm.warp(CLIFF_ENDS + 1);
        streamingNFT.createStream(0);
        streamingNFT.createStream(0);
        vm.stopPrank();
    }

    function testGetClaimableRewards() public {
        vm.startPrank(user1, user1);
        vm.warp(CLIFF_ENDS + 1);
        streamingNFT.createStream(0);

        vm.warp(CLIFF_ENDS + TEST_BLOCK_OFFSET);

        uint256 remainingRewards = ALLOCATION - ALLOCATION.mulWad(INSTANT_UNLOCK);
        uint256 bias = remainingRewards.mulWad(CLIFF_UNLOCK);
        uint256 vestedRewards = remainingRewards - bias;
        uint256 expectedRewards = (vestedRewards * TEST_BLOCK_OFFSET) / VESTING_DURATION + bias;

        console.log("expectedRewards", expectedRewards);

        assertEq(streamingNFT.getClaimableRewards(0), expectedRewards);

        vm.stopPrank();
    }

    function testClaimBatchRewards() public {
        vm.startPrank(user1, user1);
        vm.warp(CLIFF_ENDS + 1);

        // Create multiple streams
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        streamingNFT.createBatchStream(tokenIds, user1);

        uint256 balanceAfterCreate = user1.balance;

        // Move forward in time
        vm.warp(CLIFF_ENDS + TEST_BLOCK_OFFSET);

        // Claim rewards for each stream
        streamingNFT.claimBatchRewards(tokenIds);

        uint256 remainingRewards = ALLOCATION - ALLOCATION.mulWad(INSTANT_UNLOCK);
        uint256 bias = remainingRewards.mulWad(CLIFF_UNLOCK);
        uint256 vestedRewards = remainingRewards - bias;
        uint256 expectedRewards = (vestedRewards * TEST_BLOCK_OFFSET) / VESTING_DURATION + bias;

        // Since we have two streams, we expect double the rewards
        assertEq(user1.balance - balanceAfterCreate, expectedRewards * 2);

        vm.stopPrank();
    }

    function testPauseAndUnpause() public {
        // Roll to a block after the cliff ends
        vm.warp(CLIFF_ENDS + 1);

        // Create a stream to ensure the contract is functioning normally
        vm.prank(user1, user1);
        streamingNFT.createStream(0);

        // Pause the contract
        streamingNFT.pause();

        // Attempt to create another stream while paused, should fail
        vm.expectRevert();
        vm.prank(user1, user1);
        streamingNFT.createStream(1);

        // Unpause the contract
        streamingNFT.unpause();

        // Attempt to create a stream again, should succeed
        vm.prank(user1, user1);
        streamingNFT.createStream(1);
    }

    // function assertApproximatelyEqual(uint256 a, uint256 b, uint256 margin) internal {
    //     uint256 diff = a > b ? a - b : b - a;
    //     assertTrue(diff <= margin, "Values not approximately equal");
    // }
}
