// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {SendParam} from "@layerzerolabs/onft-evm/contracts/onft721/interfaces/IONFT721.sol";
import {MessagingFee, MessagingReceipt} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface ISender {
    function send(SendParam calldata _sendParam, MessagingFee calldata _fee, address _refundAddress)
        external
        payable
        returns (MessagingReceipt memory);
}

interface IMint {
    function mint(address, uint256, uint256) external;
}

contract Send is Script {
    ISender public sender = ISender(vm.envOr("SENDER", address(0)));
    address public receiver = vm.envOr("RECEIVER", address(0));
    IERC1155 public token = IERC1155(vm.envOr("TOKEN", address(0)));
    uint256 sk = vm.envOr("SK", uint256(0));

    function run() external {
        address ska = vm.addr(sk);
        vm.startBroadcast(sk);

        uint256 tokenid = 0x921560673f20465c118072ff3a70d0057096c123000000000000900000000001;

        IMint(address(token)).mint(ska, tokenid, 1);
        token.safeTransferFrom(ska, address(sender), tokenid, 1, "");

        SendParam memory sendParam = SendParam({
            dstEid: 40346,
            to: bytes32(uint256(uint160(receiver))),
            tokenId: (uint256(tokenid) << 160) >> 32,
            extraOptions: "",
            composeMsg: "",
            onftCmd: ""
        });

        MessagingFee memory fee = MessagingFee({nativeFee: 0.1 ether, lzTokenFee: 0});

        ISender(sender).send{value: 0.1 ether}(sendParam, fee, receiver);
        vm.stopBroadcast();
    }
}
