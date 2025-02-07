// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/WrappedNFT.sol";
import {console} from "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "../src/mock/TestERC721.sol";

contract MockERC1155 is ERC1155 {
    constructor() ERC1155("") {}

    function mint(address to, uint256 id, uint256 amount) public {
        _mint(to, id, amount, "");
    }
}

contract MockToken is Script {
    function run() external {
        uint256 sk = vm.envOr("CONFIG_DEPLOYER", uint256(0));
        address deployer = vm.addr(sk);

        vm.startBroadcast(sk);

        MockERC1155 mock1155 = new MockERC1155();
        TestERC721 mock721 = new TestERC721(address(deployer), "Ultraman M78 Token", "M78");

        vm.stopBroadcast();

        console.log("address.MockERC1155:", address(mock1155));
        console.log("address.TestERC721:", address(mock721));
    }
}
