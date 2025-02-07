// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@layerzerolabs/onft-evm/contracts/onft721/ONFT721Enumerable.sol";

contract BeraNft is ONFT721Enumerable {
    constructor(address _lzEndpoint, string memory _name, string memory _symbol)
        ONFT721Enumerable(_name, _symbol, _lzEndpoint, msg.sender)
    {}
}
