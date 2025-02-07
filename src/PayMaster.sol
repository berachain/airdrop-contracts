// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract PayMaster {
    mapping(address => bool) public isPayMaster;
    address public immutable ownable;

    constructor(address _ownable) {
        ownable = _ownable;
    }

    event PayMasterUpdate(address indexed payMaster, bool enabled);

    function setPayMaster(address _payMaster, bool enabled) external {
        if (msg.sender != Ownable(ownable).owner()) revert Ownable.OwnableUnauthorizedAccount(msg.sender);
        isPayMaster[_payMaster] = enabled;
        emit PayMasterUpdate(_payMaster, enabled);
    }
}
