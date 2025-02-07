// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/WrappedNFT.sol";
import {console} from "forge-std/console.sol";

contract WrappedNFTScript is Script {
    function run() external {
        uint256 sk = vm.envUint("CONFIG_DEPLOYER");
        address token = vm.envAddress("ADDRESS_ORIGIN");
        address lzEndpoint = vm.envAddress("ADDRESS_LZ_ENDPOINT");
        address creator = vm.envAddress("ADDRESS_CREATOR");

        vm.startBroadcast(sk);
        WrappedNFT wrappedNFT = new WrappedNFT(token, lzEndpoint, creator);
        vm.stopBroadcast();
        console.log("address.wrappedNft:", address(wrappedNFT));
    }
}

contract WrappedNFTEidSetupScript is Script {
    function run() external {
        address wrappedNFT = vm.envAddress("ADDRESS_WRAPPED_NFT");
        address peer = vm.envAddress("ADDRESS_PEER");
        uint256 sk = vm.envUint("CONFIG_DEPLOYER");
        uint32 eid = uint32(vm.envUint("EID"));

        vm.startBroadcast(sk);
        WrappedNFT(wrappedNFT).setPeer(eid, addressToBytes32(peer));
        vm.stopBroadcast();
    }

    function addressToBytes32(address _addr) public pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}
