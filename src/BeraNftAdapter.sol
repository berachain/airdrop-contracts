// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ONFT721Adapter} from "@layerzerolabs/onft-evm/contracts/onft721/ONFT721Adapter.sol";

contract BeraNftAdapter is ONFT721Adapter {
    constructor(address _token, address _lzEndpoint) ONFT721Adapter(_token, _lzEndpoint, msg.sender) {}
}
