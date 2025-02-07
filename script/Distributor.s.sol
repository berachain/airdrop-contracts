// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/Distributor1.sol";
import {console} from "forge-std/console.sol";
import "../src/StreamingNFT.sol";
import "../src/ClaimBatchProcessor.sol";

contract DistributorScript is Script {
    function run() external {
        uint256 sk = vm.envUint("CONFIG_DEPLOYER");
        address signer = vm.envAddress("ADDRESS_SIGNER");

        vm.startBroadcast(sk);
        Distributor1 distributor = new Distributor1(signer, address(0));
        vm.stopBroadcast();
        console.log("address.distributor:", address(distributor));
    }
}

contract StreamingNFTScript is Script {
    function run() external {
        uint256 sk = vm.envUint("CONFIG_DEPLOYER");
        address credentialNFT = vm.envAddress("ADDRESS_CREDENTIAL_NFT");
        uint256[] memory defaultBlacklistedTokenIds = new uint256[](0);
        uint256 defaultAllocationPerNFT = 0;
        uint256[] memory blacklistedTokenIds = vm.envOr("BLACKLISTED_TOKEN_IDS", ",", defaultBlacklistedTokenIds);
        uint256 allocationPerNFT = vm.envOr("ALLOCATION_PER_NFT", defaultAllocationPerNFT);
        uint256 initUnlock = 0.724638e18; // 72,5%
        uint256 cliffUnlock = 0.166667e18; // 16,7%
        uint256 vestingDuration = 63_072_000; // seconds

        require(allocationPerNFT > 0, "Allocation per NFT must be greater than 0");

        vm.startBroadcast(sk);
        StreamingNFT streamingNFT =
            new StreamingNFT(address(0), vestingDuration, initUnlock, cliffUnlock, credentialNFT, allocationPerNFT, blacklistedTokenIds);
        vm.stopBroadcast();
        console.log("address.streamingNFT:", address(streamingNFT));
    }
}

contract ClaimBatchProcessorScript is Script {
    function run() external {
        uint256 sk = vm.envUint("CONFIG_DEPLOYER");
        address distributor = vm.envAddress("ADDRESS_DISTRIBUTOR");

        vm.startBroadcast(sk);
        address[] memory nfts = new address[](0);
        address[] memory streamingNFTs = new address[](0);

        ClaimBatchProcessor claimBatchProcessor = new ClaimBatchProcessor(nfts, streamingNFTs, distributor);
        vm.stopBroadcast();
        console.log("address.claimBatchProcessor:", address(claimBatchProcessor));
    }
}
