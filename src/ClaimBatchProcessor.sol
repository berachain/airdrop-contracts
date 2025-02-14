// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @notice Interface for the Streaming NFT
/// @dev This is the contract that creates vesting reward streams for the NFT holders
interface IStreamingNFT {
    function createStream(uint256 tokenId) external;

    function createBatchStream(uint256[] calldata _tokenIds, address _onBehalfOf) external;

    function credentialNFT() external view returns (IERC721);

    function claimBatchRewards(uint256[] calldata streamIds) external;
}

/// @notice Interface for the Distributor
/// @dev This is the contract that distributes social verification rewards to the users
interface IDistributor {
    function claim(bytes32[] calldata _proof, bytes calldata _signature, uint256 _amount, address _onBehalfOf)
        external;
}

contract ClaimBatchProcessor is Ownable2Step {
    event SetStreamingNFT(address indexed nft, address indexed streamingNFT);

    IDistributor public immutable distributor;

    mapping(address => address) public streamingNFTs;

    constructor(address[] memory _nfts, address[] memory _streamingNFT, address _distributor) Ownable(msg.sender) {
        require(_nfts.length == _streamingNFT.length, "Array lengths must match");

        for (uint256 i = 0; i < _nfts.length; i++) {
            streamingNFTs[_nfts[i]] = _streamingNFT[i];
        }

        distributor = IDistributor(_distributor);
    }

    function claim(
        uint256[][] calldata _tokenIds,
        uint256 _amount,
        bytes32[] calldata _proof,
        bytes calldata _signature,
        address _onBehalfOf,
        address[] calldata _nfts
    ) external {
        if (_amount > 0) {
            distributor.claim(_proof, _signature, _amount, _onBehalfOf);
        }

        for (uint256 i = 0; i < _nfts.length; i++) {
            IStreamingNFT(streamingNFTs[_nfts[i]]).createBatchStream(_tokenIds[i], _onBehalfOf);
        }
    }

    function claimRewards(uint256[][] calldata _tokenIds, address[] calldata _nfts) external {
        for (uint256 i = 0; i < _nfts.length; i++) {
            IStreamingNFT(streamingNFTs[_nfts[i]]).claimBatchRewards(_tokenIds[i]);
        }
    }

    function setStreamingNFT(address _nft, address _streamingNFT) external onlyOwner {
        streamingNFTs[_nft] = _streamingNFT;
        emit SetStreamingNFT(_nft, _streamingNFT);
    }
}
