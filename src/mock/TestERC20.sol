// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestERC20 is ERC20 {
    constructor(address initialHolder, uint256 initialSupply, string memory name_, string memory _symbol)
        ERC20(name_, _symbol)
    {
        _mint(initialHolder, initialSupply);
    }
}
