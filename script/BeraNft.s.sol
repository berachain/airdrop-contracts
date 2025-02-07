// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {BeraNft} from "../src/BeraNft.sol";
import {console} from "forge-std/console.sol";

contract BeraNftScript is Script {
    function run() external {
        uint256 sk = vm.envUint("CONFIG_DEPLOYER");
        string memory name = vm.envString("TOKEN_NAME");
        string memory symbol = vm.envString("TOKEN_SYMBOL");
        address lzEndpoint = vm.envAddress("LZ_ENDPOINT");

        vm.startBroadcast(sk);
        BeraNft beraNft = new BeraNft(lzEndpoint, name, symbol);
        vm.stopBroadcast();
        console.log("address.beraNft:", address(beraNft));
    }
}

contract BeraNftEidSetupScript is Script {
    function run() external {
        address beraNft = vm.envAddress("ADDRESS_BERA_NFT");
        address peer = vm.envAddress("ADDRESS_PEER");
        uint256 sk = vm.envUint("CONFIG_DEPLOYER");
        uint32 eid = uint32(vm.envUint("EID"));

        vm.startBroadcast(sk);
        BeraNft(beraNft).setPeer(eid, addressToBytes32(peer));
        vm.stopBroadcast();
    }

    function addressToBytes32(address _addr) public pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}
