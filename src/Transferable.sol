// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Transferable
/// @notice Abstract contract that handles both native and ERC20 token transfers
abstract contract Transferable {
    /// @notice The address of the ERC20 token. If address(0), represents native token
    address public token;

    /// @notice Sets the token address for this contract
    /// @param _token The address of the ERC20 token. Use address(0) for native token
    constructor(address _token) {
        token = _token;
    }

    /// @notice Abstract function to withdraw tokens/native currency
    /// @param amount The amount to withdraw
    function withdraw(uint256 amount) external virtual;

    /// @notice Internal function to transfer tokens or native currency to a recipient
    /// @param recipient The address to receive the transfer
    /// @param amount The amount to transfer
    /// @dev If token is address(0), transfers native currency, otherwise transfers ERC20 tokens
    function transfer(address recipient, uint256 amount) internal {
        if (token == address(0)) {
            (bool success,) = recipient.call{value: amount}("");
            require(success, "Native token transfer failed");
        } else {
            require(IERC20(token).transfer(recipient, amount), "ERC20 transfer failed");
        }
    }

    /// @notice Returns the current balance of tokens or native currency held by this contract
    /// @return uint256 The balance amount
    /// @dev If token is address(0), returns native currency balance, otherwise returns ERC20 balance
    function balance() public view returns (uint256) {
        if (token == address(0)) {
            return address(this).balance;
        } else {
            return IERC20(token).balanceOf(address(this));
        }
    }

    /// @notice Allows the contract to receive native currency
    receive() external payable {}
    fallback() external payable {}
}
