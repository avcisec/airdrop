// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";
import {DonutToken} from "../src/DonutToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployMerkleAirdrop is Script {
    MerkleAirdrop airdrop;
    DonutToken token;
    bytes32 public ROOT = 0xca31c071cd40873a7c9d25d6a52f12de6d807a2cda648fe659fbef1ba2a56097;
    uint256 public s_amountToTransfer = 10_000 * 1e18;

    function deployMerkleAirdrop() public returns (MerkleAirdrop, DonutToken) {
        vm.startBroadcast();
        token = new DonutToken();
        airdrop = new MerkleAirdrop(ROOT, token);
        token.mint(token.owner(), s_amountToTransfer);
        token.transfer(address(airdrop), s_amountToTransfer);
        vm.stopBroadcast();
        return (airdrop, token);
    }

    function run() external returns (MerkleAirdrop, DonutToken) {
        return deployMerkleAirdrop();
    }
}
