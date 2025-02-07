// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/WrappedNFT.sol";
import "../src/BeraNftAdapter.sol";
import {console} from "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {MessagingFee, SendParam} from "@layerzerolabs/onft-evm/contracts/onft721/interfaces/IONFT721.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract ERC1155SendScript is Script {
    function run() external {
        uint256 sk = vm.envUint("CONFIG_SENDER");
        address wrappedNFT = vm.envAddress("ADDRESS_WRAPPED_NFT");
        uint256 tokenId = vm.envUint("TOKEN_ID");
        uint32 eid = uint32(vm.envUint("EID"));
        address sender = vm.addr(sk);

        vm.startBroadcast(sk);
        SendParam memory sendParam = SendParam({
            dstEid: eid,
            to: addressToBytes32(sender),
            tokenId: tokenId,
            extraOptions: hex"000301001101000000000000000000000000000186a0",
            composeMsg: "",
            onftCmd: ""
        });
        MessagingFee memory fee = MessagingFee({nativeFee: 0.03 ether, lzTokenFee: 0});
        WrappedNFT(wrappedNFT).send{value: 0.03 ether}(sendParam, fee, sender);
        vm.stopBroadcast();
    }

    function addressToBytes32(address _addr) public pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}

contract ERC721SendScript is Script {
    function run() external {
        uint256 sk = vm.envUint("CONFIG_SENDER");
        address adapter = vm.envAddress("ADDRESS_ADAPTER");
        address origin = vm.envAddress("ADDRESS_ORIGIN");
        uint256 tokenId = vm.envUint("TOKEN_ID");
        uint32 eid = uint32(vm.envUint("EID"));
        address sender = vm.addr(sk);

        vm.startBroadcast(sk);
        IERC721(origin).approve(adapter, tokenId);

        SendParam memory sendParam = SendParam({
            dstEid: eid,
            to: addressToBytes32(sender),
            tokenId: tokenId,
            extraOptions: hex"000301001101000000000000000000000000000186a0",
            composeMsg: "",
            onftCmd: ""
        });
        MessagingFee memory fee = MessagingFee({nativeFee: 0.03 ether, lzTokenFee: 0});
        BeraNftAdapter(adapter).send{value: 0.03 ether}(sendParam, fee, sender);
        vm.stopBroadcast();
    }

    function addressToBytes32(address _addr) public pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}
