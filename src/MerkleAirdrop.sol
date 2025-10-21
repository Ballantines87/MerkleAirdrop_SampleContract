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
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract MerkleAirdrop is EIP712 {
    using SafeERC20 for IERC20;

    error MerkleAirdrop__InvalidProof();
    error MerkleAirdrop__AlreadyClaimed(
        address claimerAddressWhichAlreadyClaimed
    );
    error MerkleAirdrop__InvalidSignature();

    // I want to:
    // i) have some list of addresses
    // ii) allow someone in the list to claim tokens
    address[] s_claimers;
    mapping(address claimer => bool alreadyClaimed)
        private s_claimerAddressToCheckIfClaimed;

    bytes32 private immutable i_merkleRoot;
    IERC20 private immutable i_airdropToken;

    // needed to create the digest
    bytes32 private MESSAGE_TYPEHASH =
        keccak256("AirdropClaimMessage(address account, uint256 amount)");

    // needed to create the digest
    struct AirdropClaimMessage {
        address account;
        uint256 amount;
    }

    event Claim(address indexed account, uint256 indexed amount);

    // we want to be able to pass any ERC20 token, so that our MerkleAirdrop contract is adaptable to any ERC20 of our choosing - e.g. USDC, BallToken, etc...
    constructor(
        bytes32 merkleRoot,
        IERC20 airdropToken
    ) EIP712("Merkle Airdrop", "1") {
        i_merkleRoot = merkleRoot;
        i_airdropToken = airdropToken;
    }

    // following CEI
    function claim(
        address account,
        uint256 amountToClaim,
        bytes32[] calldata merkleProof, // this is an array of the proofs - that's the intermediate hashes that are required in order to be able to calculate the root and then we compare that expected root to actual root i_merkleRoot (provided in the constructor of the smart contract)
        uint8 v, // these are v, r and s components of our signature
        bytes32 r,
        bytes32 s
    ) external {
        // we check if they claimed already -> if they did, then revert
        if (s_claimerAddressToCheckIfClaimed[account]) {
            revert MerkleAirdrop__AlreadyClaimed(account);
        }

        // check the signature -> if the signature is NOT valid, then we are going to revert with a custom error MerkleAirdrop__InvalidSignature()
        if (
            !_isValidSignature(
                account,
                getMessageHash(account, amountToClaim),
                v,
                r,
                s
            )
        ) {
            revert MerkleAirdrop__InvalidSignature();
        }

        // so actually we need to calculate - using the i) account and ii) the amount - the leaf hash -> which is going to be the leaf node (where we have i) an address that wants to claim and ii) an amount to claim)

        // n.d.r. abi.encodePacked yields a bytes format -> then keccack256 "converts it" to a bytes32 format

        // 1) so here we've encoded i) account and ii) amount together and we have hashed them -> so we've made them into one value and then we've hashed them together
        // 2) BUT actually, when we're using Merkle Proofs we need to HASH THEM TWICE
        // 3) BUT...! BEFORE we do that, we need to do bytes.concat() FIRST
        // -> that's because: by HASHING it twice, we AVOID COLLISIONS -> it's standard to do it twice -> that's the GENERAL WAY we i) ENCODE and ii) HASH leaf nodes

        bytes32 leaf = keccak256(
            bytes.concat(keccak256(abi.encode(account, amountToClaim)))
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
        s_claimerAddressToCheckIfClaimed[account] = true;

        emit Claim(account, amountToClaim);

        // 5) if they've passed the execution, then we wanna mint them the ERC20 tokens
        // N.B. we're using safeTransfer() (n.d.r. from OpenZeppelin's SafeERC20) in case the account doesn't accept ERC20 - cause if it doesn't accept ERC20 and we used transfer(), then it would NOT revert!
        // -> by using safeTransfer() then if, for some reason, we can't send the tokens to the address -> it will handle that for us
        i_airdropToken.safeTransfer(account, amountToClaim);
    }

    function _isValidSignature(
        address accountAddress,
        bytes32 digest,
        uint8 v, // these are v, r and s components of our signature
        bytes32 r,
        bytes32 s
    ) internal pure returns (bool) {
        (address actualSigner, , ) = ECDSA.tryRecover(digest, v, r, s);
        return accountAddress == actualSigner;
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

    // this creates and returns the message digest
    function getMessageHash(
        address accountAddress,
        uint256 amount
    ) public view returns (bytes32 digest) {
        AirdropClaimMessage memory messageStruct = AirdropClaimMessage({
            account: accountAddress,
            amount: amount
        });

        // this _hashTypedDataV4(...) is from the EIP712.sol OpenZeppelin contract and returns the digest for us, making it fully EIP712 compatible (improvement proposal for current signature format)
        return
            _hashTypedDataV4(
                keccak256(abi.encode(MESSAGE_TYPEHASH, messageStruct))
            );
    }
}
