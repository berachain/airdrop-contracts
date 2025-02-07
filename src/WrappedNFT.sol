// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@layerzerolabs/onft-evm/contracts/onft721/ONFT721.sol";
import {SendParam} from "@layerzerolabs/onft-evm/contracts/onft721/interfaces/IONFT721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract WrappedNFT is Pausable, ONFT721, IERC1155Receiver, ReentrancyGuard {
    address public immutable oriToken;
    uint160 public immutable creator;

    constructor(address _token, address _lzEndpoint, address _creator)
        ONFT721("Wrapped BERA ONFT", "WBOT", _lzEndpoint, msg.sender)
    {
        creator = uint160(_creator);
        oriToken = _token;
    }

    event Wrap(address indexed collection, address indexed owner, uint256 indexed typeid, uint256 value);
    event Unwrap(address indexed collection, uint256 indexed id);
    event Mint(address indexed owner, uint256 indexed id);

    function onERC1155Received(address, address from, uint256 id, uint256 value, bytes calldata)
        external
        nonReentrant
        whenNotPaused
        returns (bytes4)
    {
        require(msg.sender == oriToken, "Invalid sender");

        _wrap(from, id, value);
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata
    ) external nonReentrant whenNotPaused returns (bytes4) {
        require(msg.sender == oriToken, "Invalid sender");

        for (uint256 i = 0; i < ids.length; i++) {
            _wrap(from, ids[i], values[i]);
        }
        return this.onERC1155BatchReceived.selector;
    }

    function _wrap(address from, uint256 id, uint256 value) internal {
        require(value == 1, "Value must equal 1");

        uint160 tokenCreator = uint160(id >> 96);
        require(tokenCreator == creator, "Invalid creator");

        require(uint40(id) == uint40(1), "Total supply must be 1");

        _mint(from, id);

        emit Mint(from, id);
        emit Wrap(msg.sender, from, id, value);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    // @notice Unwraps an ERC721 token back to ERC1155
    // @dev Assumes tokens have same typeId for all wrapped tokens
    // @param tokenId The token ID of the ERC721 token to unwrap
    // @param onBehalfOf The address to transfer the unwrapped tokens to
    function unwrap(uint256[] calldata tokenId, address onBehalfOf) external whenNotPaused {
        require(tokenId.length >= 1, "At least one token must be unwrapped");

        for (uint256 i = 0; i < tokenId.length; i++) {
            require(msg.sender == ownerOf(tokenId[i]), "Must be owner");
            _burn(tokenId[i]);
            IERC1155(oriToken).safeTransferFrom(address(this), onBehalfOf, tokenId[i], 1, bytes(""));
            emit Unwrap(oriToken, tokenId[i]);
        }
    }

    function _buildMsgAndOptions(SendParam calldata _sendParam)
        internal
        view
        override
        whenNotPaused
        returns (bytes memory message, bytes memory options)
    {
        return super._buildMsgAndOptions(_sendParam);
    }
}
