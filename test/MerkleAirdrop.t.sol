// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {BallToken} from "../src/BallToken.sol";
import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";

contract MerkleAirdropTest is Test {
    BallToken public tokenContract;
    MerkleAirdrop public airdropContract;

    // N.B. copied / taken from output.json, where we previously generated the root
    bytes32 public ROOT_HASH_MERKLE_TREE =
        0xaa5d581231e596618465a56aa0f5870ba6e20785fe436d5bfb82b08662ccc7c4;

    address USER;
    uint256 USER_PRIVATE_KEY;

    function setUp() external {
        // creates an address and a private key using "USER" to create these
        // n.b. the first WHITELISTED claiming address (in whitelist[0] inside GenerateInput.s.sol, which is used to generate the input to create the Merkle Tree) is the SAME as the one generated using makeAddrAndKey("USER") -> that's because we will use this address to test claimability
        (USER, USER_PRIVATE_KEY) = makeAddrAndKey("USER");

        vm.startPrank(msg.sender);
        tokenContract = new BallToken();
        airdropContract = new MerkleAirdrop(
            ROOT_HASH_MERKLE_TREE,
            tokenContract
        );
        vm.stopPrank();
    }

    function testUsersCanClaim() public {
        console.log("User address: %s", USER);
    }
}
