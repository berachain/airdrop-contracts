// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/StreamingNFT.sol";
import "../../src/mock/TestERC20.sol";
import "../../src/mock/TestERC721.sol";
import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";
import {ClaimBatchProcessor} from "../../src/ClaimBatchProcessor.sol";

contract BatchProcessorTest is Test {
    using FixedPointMathLib for uint256;

    ClaimBatchProcessor public claimBatchProcessor;
    TestERC20 public testERC20;
    TestERC721 public testERC721;

    function setUp() public {
        vm.createSelectFork("https://teddilion-eth-cartio.berachain.com");
        claimBatchProcessor = ClaimBatchProcessor(0x87184F66ceE28dE0914A2AfeF88312768C186e96);
    }

    // {"amount":"11111140000000000000",
    //  "proof":[
    //     "0x83441720c2e5b8e29930cbb260ed688d50d09857afb2a88dd0e5ab3aa3570b32",
    //     "0x8d9cd6df97bc00af932d5d25f4abfaf6c2516f51ad0b9195b0553c731c9c18b7",
    //     "0x0847231a6e8e954c1a8b481bcdf22fba542b821d912a8111d2b4f8037ff70f2a",
    //     "0x9dfb81b717e5f5a1e068aedf923b8178d71f80bdc5a8b949bc3a1f5367e56459",
    //     "0x44be77ae5a8a003332e372511a36a90896b874a9fde1722d024acdb9fd52e769",
    //     "0x48c68756754293ea10eb5fa06130d3262dc798d6249cf4f2690be668a1c65cdf"
    //  ],
    //  "signature":"0x6b8b04c7597f2cac9e6df6bd100960c5a418463f25d8c5eb614b6dac431d5cb246ade86c45de560dc457a8d46d81c23962126eee8a0edbe0bfea98fe3a9633df1b",
    //  "tokenIds":{
    //    "0x9Dd6eAc6431f5855E0987D6952976B10A75c04eb":["10","11"]},
    //  "userAddress":"0x0e822a07116f539b66BB619963d0185239E62c8d"}
    function testBatchClaim() public {
        uint256 amount = 11111140000000000000;
        bytes32[] memory proof = new bytes32[](6);
        proof[0] = 0x83441720c2e5b8e29930cbb260ed688d50d09857afb2a88dd0e5ab3aa3570b32;
        proof[1] = 0x8d9cd6df97bc00af932d5d25f4abfaf6c2516f51ad0b9195b0553c731c9c18b7;
        proof[2] = 0x0847231a6e8e954c1a8b481bcdf22fba542b821d912a8111d2b4f8037ff70f2a;
        proof[3] = 0x9dfb81b717e5f5a1e068aedf923b8178d71f80bdc5a8b949bc3a1f5367e56459;
        proof[4] = 0x44be77ae5a8a003332e372511a36a90896b874a9fde1722d024acdb9fd52e769;
        proof[5] = 0x48c68756754293ea10eb5fa06130d3262dc798d6249cf4f2690be668a1c65cdf;

        bytes memory signature =
            hex"6b8b04c7597f2cac9e6df6bd100960c5a418463f25d8c5eb614b6dac431d5cb246ade86c45de560dc457a8d46d81c23962126eee8a0edbe0bfea98fe3a9633df1b";

        address owner = 0x3a12EDcCdBc12C050afDA69e320374f112fE620d;
        address onBehalfOf = 0x0e822a07116f539b66BB619963d0185239E62c8d;

        address[] memory nfts = new address[](1);
        nfts[0] = 0x9Dd6eAc6431f5855E0987D6952976B10A75c04eb;

        uint256[] memory tokenIds0 = new uint256[](2);
        tokenIds0[0] = 10;
        tokenIds0[1] = 11;

        uint256[][] memory tokenIds = new uint256[][](1);
        tokenIds[0] = tokenIds0;

        vm.prank(owner, owner);
        claimBatchProcessor.claim(tokenIds, amount, proof, signature, onBehalfOf, nfts);
    }
}
