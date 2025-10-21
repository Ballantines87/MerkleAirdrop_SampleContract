// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {BallToken} from "../src/BallToken.sol";
import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";

import {ZkSyncChainChecker} from "lib/foundry-devops/src/ZkSyncChainChecker.sol";

import {DeployMerkleAirdrop} from "../script/DeployMerkleAirdrop.s.sol";

contract MerkleAirdropTest is Test, ZkSyncChainChecker {
    BallToken public tokenContract;
    MerkleAirdrop public airdropContract;

    // N.B. copied / taken from output.json, where we previously generated the root
    bytes32 public ROOT_HASH_MERKLE_TREE =
        0x7cdb6c21ef22a6cb5726d348e677f3e10032127425d425c5028965a30a71556e;

    // N.B. proofs copied / taken from output.json, where we previously generated the root
    bytes32 PROOF_1 =
        0x0fd7c981d39bece61f7499702bf59b3114a90e66b51ba2c53abdf7b62986c00a;
    bytes32 PROOF_2 =
        0xe5ebd1e1b5a5478a944ecab36a9a954ac3b6b8216875f6524caa7a1d87096576;
    bytes32[] public PROOF = [PROOF_1, PROOF_2];

    uint256 public FULL_AMOUNT_TO_CLAIM = 25 * 1e18;
    uint256 public AMOUNT_TO_FUND_THE_AIRDROP_CONTRACT_WITH =
        FULL_AMOUNT_TO_CLAIM * 4;

    address USER;
    uint256 USER_PRIVATE_KEY; // USER will create a signature - using his/her private key - to claim the airdrop -> then gasPayer will use that signature to pay the fees for user

    address public gasPayer; // aka the other user that's gonna pay for the USER transaction, using their signature and paying for them so that USER can claim in a sponsored way (e.g. gasPayer pays the claim transaction fees and USER gets the tokens)

    function setUp() external {
        // creates an address and a private key using "USER" to create these
        // n.b. the first WHITELISTED claiming address (in whitelist[0] inside GenerateInput.s.sol, which is used to generate the input to create the Merkle Tree) is the SAME as the one generated using makeAddrAndKey("USER") -> that's because we will use this address to test claimability
        (USER, USER_PRIVATE_KEY) = makeAddrAndKey("USER");
        gasPayer = makeAddr("gasPayer");

        // if not on zkSync chain then deploy with the DeployMerkleAirdrop.s.sol script
        if (!isZkSyncChain()) {
            DeployMerkleAirdrop deployer = new DeployMerkleAirdrop();
            (tokenContract, airdropContract) = deployer.run();
        } else {
            tokenContract = new BallToken();
            airdropContract = new MerkleAirdrop(
                ROOT_HASH_MERKLE_TREE,
                tokenContract
            );

            // we need to fund the Airdrop Contract, so that it has the tokens to send to claimants

            // 1) we send the tokens to MerkleAirdropTest test contract
            tokenContract.mint(
                tokenContract.owner(), // this is the MerkleAirdropTest CONTRACT! which is the owner (since it's creating the contract in setUp()) and gets the tokens first
                AMOUNT_TO_FUND_THE_AIRDROP_CONTRACT_WITH
            );

            // 2) Then MerkleAirdropTest test contract transfers them to the AirdropContract
            tokenContract.transfer(
                address(airdropContract),
                AMOUNT_TO_FUND_THE_AIRDROP_CONTRACT_WITH
            );
        }
    }

    function testUsersCanClaim() public {
        console.log("User address: %s", USER);

        // we get the digest from USER
        bytes32 digest = airdropContract.getMessageHash(
            USER,
            FULL_AMOUNT_TO_CLAIM
        );

        // we check that initially (before claiming the airdrop) the user's balance is 0
        uint256 startingBalance = tokenContract.balanceOf(USER);

        // we prank the USER to SIGN the digest using vm.sign() (n.d.r. and notice we don't use vm.prank because vm.prank() is not a call -- we can just use vm.sign() to prank the user) and get the signature's v, r, and s -> using vm.sign() which i) takes a private key (the USER_PRIVATE_KEY) and ii) the digest
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(USER_PRIVATE_KEY, digest);

        vm.prank(gasPayer); // the gasPayer calls claim using the signed USER message to send to the transaction for the USER and pays the gas for the USER
        airdropContract.claim(USER, FULL_AMOUNT_TO_CLAIM, PROOF, v, r, s); // STILL TO ADD v,r,s HERE
        uint256 endingBalance = tokenContract.balanceOf(USER);

        console.log("Ending user balance: %s", endingBalance);

        assertEq(endingBalance - startingBalance, FULL_AMOUNT_TO_CLAIM);
    }
}
