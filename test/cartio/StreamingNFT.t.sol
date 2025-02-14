// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/StreamingNFT.sol";
import "../../src/mock/TestERC20.sol";
import "../../src/mock/TestERC721.sol";
import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";

contract StreamingNFTTest is Test {
    using FixedPointMathLib for uint256;

    StreamingNFT public streamingNFT;
    TestERC721 public mockNFT;

    function setUp() public {
        vm.createSelectFork("https://teddilion-eth-cartio.berachain.com");
        streamingNFT = StreamingNFT(payable(0x82a310dBC2B5C6b50E6bc4413FDD1D007842C51e));
    }

    function test_getClaimableRewards() public {
        uint256 streamId = 51257785424469767429606555391488941439980297915465728;
        uint256 lastClaimedTimestamp = streamingNFT.claimedTimestamp(streamId);
        uint256 lastClaimedAmount = streamingNFT.claimedAmount(streamId);

        require(lastClaimedTimestamp != 0, "Stream not created");

        uint256 elapsedTimestamp = (
            block.timestamp > streamingNFT.vestingEndTimestamp() ? streamingNFT.vestingEndTimestamp() : block.timestamp
        ) - streamingNFT.cliffEndTimestamp();
        uint256 claimableAmount = (streamingNFT.vestedRewards() * elapsedTimestamp) / streamingNFT.vestingDuration()
            + streamingNFT.cliffUnlockAmount();
    }
}
