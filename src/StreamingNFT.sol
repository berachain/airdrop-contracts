// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";
import "./PayMaster.sol";
import "./Transferable.sol";

/**
 * @title StreamingNFTPool
 * @dev A contract for managing vesting streams and rewards for NFT holders.
 */
contract StreamingNFT is Ownable2Step, ReentrancyGuard, Pausable, Transferable, PayMaster {
    using FixedPointMathLib for uint256;

    IERC721 public immutable credentialNFT;
    uint256 public immutable vestingDuration;

    uint256 public immutable allocationPerNFT;
    uint256 public immutable instantUnlockPercentage;
    uint256 public immutable instantUnlockAmount;

    uint256 public immutable cliffUnlockPercentage;
    uint256 public immutable cliffUnlockAmount;

    uint256 public immutable vestedRewards;

    uint256 public cliffEndTimestamp;
    uint256 public vestingEndTimestamp;
    uint256 public fee;

    mapping(uint256 => uint256) public claimedTimestamp;
    mapping(uint256 => uint256) public claimedAmount;
    mapping(uint256 => bool) public isBlacklistedTokenId;

    event StreamCreated(uint256 indexed streamId, address indexed beneficiary, uint256 totalAllocation, uint256 fee);
    event RewardsClaimed(uint256 indexed streamId, address indexed beneficiary, uint256 amount);
    event CliffEndTimestampUpdated(uint256 indexed cliffEndTimestamp);

    error InvalidOrigin(address origin);

    constructor(
        address _token, // Use address(0) for native token
        uint256 _vestingDuration,
        uint256 _instantUnlockPercentage,
        uint256 _cliffUnlockPercentage,
        address _credentialNFT,
        uint256 _allocationPerNFT,
        uint256[] memory _blacklistedTokenIds
    ) Ownable(msg.sender) Transferable(_token) PayMaster(address(this)) {
        require(_vestingDuration > 0, 'Invalid vesting duration');
        vestingDuration = _vestingDuration;
        instantUnlockPercentage = _instantUnlockPercentage;
        cliffUnlockPercentage = _cliffUnlockPercentage;
        credentialNFT = IERC721(_credentialNFT);
        instantUnlockAmount = _allocationPerNFT.mulWad(_instantUnlockPercentage);

        uint256 totalVestedRewards = _allocationPerNFT - instantUnlockAmount;
        cliffUnlockAmount = totalVestedRewards.mulWad(_cliffUnlockPercentage);
        vestedRewards = totalVestedRewards - cliffUnlockAmount;

        allocationPerNFT = _allocationPerNFT;
        for (uint256 i = 0; i < _blacklistedTokenIds.length; i++) {
            isBlacklistedTokenId[_blacklistedTokenIds[i]] = true;
        }
        _pause();
    }

    /**
     * @dev Sets the vesting start block.
     * @param _cliffEndTimestamp The block timestamp when cliff ends.
     * @notice Only the contract owner can call this function.
     * @notice The vesting start block can only be set once and cannot be changed afterwards.
     */
    function setCliffEndTimestamp(uint256 _cliffEndTimestamp) external onlyOwner {
        require(cliffEndTimestamp == 0, "Vesting start block already set");
        require(_cliffEndTimestamp > block.timestamp, "Vesting start block must be in the future");
        cliffEndTimestamp = _cliffEndTimestamp;
        vestingEndTimestamp = _cliffEndTimestamp + vestingDuration;
        emit CliffEndTimestampUpdated(_cliffEndTimestamp);
        _unpause();
    }

    /// @notice Set the fee
    /// @param _fee fee to be paid to the paymaster
    function setFee(uint256 _fee) external onlyOwner {
        fee = _fee;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        require(cliffEndTimestamp != 0, "Vesting start block not set");
        _unpause();
    }

    function createStream(uint256 tokenId) external nonReentrant whenNotPaused {
        require(claimedTimestamp[tokenId] == 0, "Stream already created");
        require(!isBlacklistedTokenId[tokenId], "TokenId is blacklisted");

        claimedTimestamp[tokenId] = cliffEndTimestamp;

        address onbehalfOf = credentialNFT.ownerOf(tokenId);
        bool isPayMaster_ = isPayMaster[tx.origin];

        if (!isPayMaster_ && onbehalfOf != tx.origin) {
            revert InvalidOrigin(tx.origin);
        }

        uint256 instantAmount = instantUnlockAmount;

        uint256 gasFee = 0;
        if (isPayMaster_) {
            gasFee = fee;
            require(gasFee != 0, "Gas fee not set");
            instantAmount -= gasFee;
            transfer(tx.origin, gasFee);
        }

        transfer(onbehalfOf, instantAmount);
        emit StreamCreated(tokenId, onbehalfOf, allocationPerNFT, gasFee);
    }

    function createBatchStream(uint256[] calldata tokenIds, address onBehalfOfOwner)
        external
        nonReentrant
        whenNotPaused
    {
        uint256 gasFee;
        address onbehalfOf;
        uint256 instantAmount;
        uint256 instantAmountAccum;
        uint256 payMasterFeeAccum;

        bool isPayMaster_ = isPayMaster[tx.origin];

        if (isPayMaster_) {
            gasFee = fee;
            require(gasFee != 0, "Gas fee not set");
        }

        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(claimedTimestamp[tokenIds[i]] == 0, "Stream already created");
            require(!isBlacklistedTokenId[tokenIds[i]], "TokenId is blacklisted");

            claimedTimestamp[tokenIds[i]] = cliffEndTimestamp;

            onbehalfOf = credentialNFT.ownerOf(tokenIds[i]);
            require(onbehalfOf == onBehalfOfOwner, "Not the owner of the token");
            if (!isPayMaster_ && onbehalfOf != tx.origin) {
                revert InvalidOrigin(tx.origin);
            }
            instantAmount = instantUnlockAmount;

            if (isPayMaster_) {
                instantAmountAccum += (instantAmount - gasFee);
                payMasterFeeAccum += gasFee;
            } else {
                instantAmountAccum += instantAmount;
            }

            emit StreamCreated(tokenIds[i], onbehalfOf, allocationPerNFT, gasFee);
        }

        transfer(onbehalfOf, instantAmountAccum);
        if (payMasterFeeAccum > 0) {
            transfer(tx.origin, payMasterFeeAccum);
        }
    }

    /**
     * @dev Claims the vested rewards for a given stream.
     * @param streamId The ID of the vesting stream.
     */
    function claimRewards(uint256 streamId) external nonReentrant whenNotPaused {
        _claimVestedRewards(streamId, vestingEndTimestamp);
    }

    /**
     * @dev Claims the vested rewards for a given stream.
     * @param streamIds The ID of the vesting stream.
     */
    function claimBatchRewards(uint256[] calldata streamIds) external nonReentrant whenNotPaused {
        uint256 vestingEndTimestamp_ = vestingEndTimestamp;
        for (uint256 i = 0; i < streamIds.length; i++) {
            _claimVestedRewards(streamIds[i], vestingEndTimestamp_);
        }
    }

    function _claimVestedRewards(uint256 streamId, uint256 _vestingEndTimestamp) internal {
        uint256 claimableAmount = _getClaimableRewards(streamId, _vestingEndTimestamp);
        address beneficiary = credentialNFT.ownerOf(streamId);

        if (tx.origin != beneficiary) {
            revert InvalidOrigin(tx.origin);
        }

        if (claimableAmount > 0) {
            // NOTE: This will revert if the token does not exist
            claimedTimestamp[streamId] = block.timestamp;
            claimedAmount[streamId] += claimableAmount;
            emit RewardsClaimed(streamId, beneficiary, claimableAmount);

            transfer(beneficiary, claimableAmount);
        }
    }

    /**
     * @dev Calculates and returns the claimable rewards for a given stream.
     * @param streamId The ID of the vesting stream.
     * @return The amount of claimable rewards.
     */
    function getClaimableRewards(uint256 streamId) public view returns (uint256) {
        return _getClaimableRewards(streamId, vestingEndTimestamp);
    }

    function _getClaimableRewards(uint256 streamId, uint256 vestingEndTimestamp_) internal view returns (uint256) {
        require(block.timestamp > cliffEndTimestamp, "Vesting has not started yet");

        uint256 lastClaimedTimestamp = claimedTimestamp[streamId];
        uint256 lastClaimedAmount = claimedAmount[streamId];

        require(lastClaimedTimestamp != 0, "Stream not created");

        if (lastClaimedTimestamp >= vestingEndTimestamp_) {
            return 0;
        }

        uint256 elapsedTimestamp =
            (block.timestamp > vestingEndTimestamp_ ? vestingEndTimestamp_ : block.timestamp) - cliffEndTimestamp;
        uint256 claimableAmount = (vestedRewards * elapsedTimestamp) / vestingDuration + cliffUnlockAmount;
        return claimableAmount - lastClaimedAmount;
    }

    function withdraw(uint256 amount) external override onlyOwner {
        transfer(msg.sender, amount);
    }
}
