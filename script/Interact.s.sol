// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";

contract ClaimAirdrop is Script {
    error claimAirdropScript__InvalidSignatureLength();
    address public constant CLAIMING_ADDRESS = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 public constant CLAIMING_AMOUNT = 25 * 1e18;
    bytes32 public PROOF1 = 0xd1445c931158119b00449ffcac3c947d028c0c359c34a6646d95962b3b55c6ad;
    bytes32 public PROOF2 = 0xf453e13b4dee79db360280e56f90b095fe63443a088a2ed68c8387b4da3abdd8;
    bytes32[] public PROOF = [PROOF1, PROOF2];
    bytes private SIGNATURE = hex"fbd2270e6f23fb5fe9248480c0f4be8a4e9bd77c3ad0b1333cc60b5debc511602a2a06c24085d8d7c038bad84edc53664c8ce0346caeaa3570afec0e61144dc11c";

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("MerkleAirdrop", block.chainid);
        ClaimAirdrop(mostRecentlyDeployed);
    }

    function claimAirdrop(address airdrop) public {
        vm.startBroadcast();
        (uint8 v, bytes32 r, bytes32 s) = splitSignature(SIGNATURE);
        MerkleAirdrop(airdrop).claim(CLAIMING_ADDRESS, CLAIMING_AMOUNT, PROOF, v, r, s);
        vm.stopBroadcast();
    }

    function splitSignature(bytes memory signature) public returns(uint8 v, bytes32 r , bytes32 s) {
        if(signature.length == 65) {
            revert claimAirdropScript__InvalidSignatureLength();
        } // 8 bit = 1 byte yapar 32 + 32 + 1 = 65
        assembly {
            r := mload(add(signature,32))
            s := mload(add(signature,64))
            v := byte(0, mload(add(signature, 96)))
        }
    }
}
