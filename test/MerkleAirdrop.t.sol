// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test,console} from "forge-std/Test.sol";
import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";
import {DonutToken} from "../src/DonutToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DeployMerkleAirdrop} from "../script/DeployMerkleAirdrop.s.sol";

contract MerkeAirdropTest is Test {
    MerkleAirdrop public airdrop;
    DonutToken public donutToken;
    bytes32 root = 0xca31c071cd40873a7c9d25d6a52f12de6d807a2cda648fe659fbef1ba2a56097;
    address user;
    address gasSponsor;
    address user2 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 userPrivKey;
    uint256 public AMOUNT_TO_CLAIM = 25 * 1e18;
    uint256 public MINT_AMOUNT = 1000 * 1e18;
    bytes32 public PROOF1 = 0x0fd7c981d39bece61f7499702bf59b3114a90e66b51ba2c53abdf7b62986c00a;
    bytes32 public PROOF2 = 0xf453e13b4dee79db360280e56f90b095fe63443a088a2ed68c8387b4da3abdd8;
    bytes32[] public PROOF = [PROOF1, PROOF2]; 
    function setUp() public {
        
        DeployMerkleAirdrop deployer = new DeployMerkleAirdrop();
        (airdrop, donutToken) = deployer.deployMerkleAirdrop();
        (user, userPrivKey) = makeAddrAndKey("user");
        gasSponsor = makeAddr("gasSponsor");

    }

    function testUserCanClaim() public {
        uint256 startingBalance = donutToken.balanceOf(user);
        bytes32 digest = airdrop.getMessageHash(user, AMOUNT_TO_CLAIM);
        vm.prank(user);
        // sign a message
        (uint8 v,bytes32 r,bytes32 s) = vm.sign(userPrivKey, digest);

        // gasSponsor calls claim using the signed message

        console.log("Claim status before claiming:", airdrop.getClaimStatus(user));
        vm.prank(gasSponsor);
        airdrop.claim(user, AMOUNT_TO_CLAIM, PROOF, v, r, s);
        uint256 endingBalance = donutToken.balanceOf(user);
        assertEq(endingBalance - startingBalance, AMOUNT_TO_CLAIM);
        console.log("Starting Balance:", startingBalance);
        console.log("Ending Balance:", endingBalance);
        console.log("Claim status after claiming:", airdrop.getClaimStatus(user));

    }

}