// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {BeraNftAdapter} from "../src/BeraNftAdapter.sol";
import {console} from "forge-std/console.sol";

contract OnftAdapterScript is Script {
    function run() external {
        uint256 sk = vm.envUint("CONFIG_DEPLOYER");
        address token = vm.envAddress("ADDRESS_ORIGIN");
        address lzEndpoint = vm.envAddress("ADDRESS_LZ_ENDPOINT");

        vm.startBroadcast(sk);
        BeraNftAdapter beraNftAdapter = new BeraNftAdapter(token, lzEndpoint);
        vm.stopBroadcast();
        console.log("address.beraNftAdapter:", address(beraNftAdapter));
    }
}

contract OnftAdapterEidSetupScript is Script {
    function run() external {
        address beraNft = vm.envAddress("ADDRESS_BERA_NFT");
        address peer = vm.envAddress("ADDRESS_PEER");
        uint256 sk = vm.envUint("CONFIG_DEPLOYER");
        uint32 eid = uint32(vm.envUint("EID"));

        vm.startBroadcast(sk);
        BeraNftAdapter(beraNft).setPeer(eid, addressToBytes32(peer));
        vm.stopBroadcast();
    }

    function addressToBytes32(address _addr) public pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}
