// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/* Layout of the contract file: */
// version
// imports
// interfaces, libraries, contract

// Inside Contract:
// Errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

import {BallToken} from "./BallToken.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract MerkleAirdrop {
    using SafeERC20 for IERC20;

    error MerkleAirdrop__InvalidProof();
    error MerkleAirdrop__AlreadyClaimed(
        address claimerAddressWhichAlreadyClaimed
    );

    // I want to:
    // i) have some list of addresses
    // ii) allow someone in the list to claim tokens
    address[] s_claimers;
    mapping(address claimer => bool alreadyClaimed)
        private s_claimerAddressToCheckIfClaimed;

    bytes32 private immutable i_merkleRoot;
    IERC20 private immutable i_airdropToken;

    event Claim(address indexed account, uint256 indexed amount);

    // we want to be able to pass any ERC20 token, so that our MerkleAirdrop contract is adaptable to any ERC20 of our choosing - e.g. USDC, BallToken, etc...
    constructor(bytes32 merkleRoot, IERC20 airdropToken) {
        i_merkleRoot = merkleRoot;
        i_airdropToken = airdropToken;
    }

    // following CEI
    function claim(
        address accountThatWantsToClaim,
        uint256 amountToClaim,
        bytes32[] calldata merkleProof // this is an array of the proofs - that's the intermediate hashes that are required in order to be able to calculate the root and then we compare that expected root to actual root i_merkleRoot (provided in the constructor of the smart contract)
    ) external {
        if (!s_claimerAddressToCheckIfClaimed[accountThatWantsToClaim]) {
            revert MerkleAirdrop__AlreadyClaimed(accountThatWantsToClaim);
        }

        // so actually we need to calculate - using the i) account and ii) the amount - the leaf hash -> which is going to be the leaf node (where we have i) an address that wants to claim and ii) an amount to claim)

        // n.d.r. abi.encodePacked yields a bytes format -> then keccack256 "converts it" to a bytes32 format

        // 1) so here we've encoded i) account and ii) amount together and we have hashed them -> so we've made them into one value and then we've hashed them together
        // 2) BUT actually, when we're using Merkle Proofs we need to HASH THEM TWICE
        // 3) BUT...! BEFORE we do that, we need to do bytes.concat() FIRST
        // -> that's because: by HASHING it twice, we AVOID COLLISIONS -> it's standard to do it twice -> that's the GENERAL WAY we i) ENCODE and ii) HASH leaf nodes

        bytes32 leaf = keccak256(
            bytes.concat(
                keccak256(abi.encode(accountThatWantsToClaim, amountToClaim))
            )
        );

        // 4) Now that we have the leaf, we need to VERIFY the PROOF -> and we use OpenZeppelin's MerkleProof contract (n.d.r. library) -> we use the function verify()
        /* TO VERIFY 
            -> we need to first verify that the leaf PROVIDES a root that MATCHES the expected root 
            -> and, if it doesn't, we wanna revert
        */

        if (!MerkleProof.verify(merkleProof, i_merkleRoot, leaf)) {
            revert MerkleAirdrop__InvalidProof();
        }

        // we wanna do this BEFORE we transfer the token and emit the event to avoid re-entrancy, according to CEI practices
        s_claimerAddressToCheckIfClaimed[accountThatWantsToClaim] = true;

        emit Claim(accountThatWantsToClaim, amountToClaim);

        // 5) if they've passed the execution, then we wanna mint them the ERC20 tokens
        // N.B. we're using safeTransfer() (n.d.r. from OpenZeppelin's SafeERC20) in case the account doesn't accept ERC20 - cause if it doesn't accept ERC20 and we used transfer(), then it would NOT revert!
        // -> by using safeTransfer() then if, for some reason, we can't send the tokens to the address -> it will handle that for us
        i_airdropToken.safeTransfer(accountThatWantsToClaim, amountToClaim);
    }

    /*//////////////////////////////////////////////////////////////
                            GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getMerkleRoot() external returns (bytes32) {
        return i_merkleRoot;
    }

    function getAirdropToken() external returns (IERC20) {
        return i_airdropToken;
    }
}
