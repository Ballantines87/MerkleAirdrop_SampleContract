// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";

import {BallToken} from "../src/BallToken.sol";
import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";

// we need this to get the most recently deployed contract
import {DevOpsTools} from "../lib/foundry-devops/src/DevOpsTools.sol";

contract ClaimAirdrop is Script {
    // function get_most_recent_deployment(
    //     string memory contractName,
    //     uint256 chainId,
    //     string memory relativeBroadcastPath
    // ) internal view returns (address)

    error __ClaimAirdrop__Invalid_Signature_Length();

    MerkleAirdrop airdropContract;
    BallToken tokenContract;

    // we took that from the 2nd address in input.json
    address CLAIMING_ADDRESS = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 CLAIMING_AMOUNT = 25 * 1e18; // n.d.r. aka 25 ball tokens, as we have 18 decimals

    // we took that from output.json address in input.json for the address above
    bytes32 PROOF_ONE =
        0x72995a443d90c829031cb42be582996fb8747dc02130f358dba0ad65c8db5119;
    bytes32 PROOF_TWO =
        0xe5ebd1e1b5a5478a944ecab36a9a954ac3b6b8216875f6524caa7a1d87096576;
    bytes32[] proof = [PROOF_ONE, PROOF_TWO];

    // the signature is saved using hex"" and inside the double quote you have the signature without the initial 0x

    /* N.B. full signature f47d9c200e94c67755b4aa911ee0634c4eea842222e5211079c51b3b15097b54257fd8baf350281727b5d16e4410efb0c9bfec51ec7a92a9d266cf91ee64f1231c

    then split up into v,r, and s
    f47d9c200e94c67755b4aa911ee0634c4eea842222e5211079c51b3b15097b54 -> r -> first 32 bytes
    257fd8baf350281727b5d16e4410efb0c9bfec51ec7a92a9d266cf91ee64f123 -> s -> second 32 bytes
    1c -> v -> last byte */

    bytes private SIGNATURE =
        hex"f47d9c200e94c67755b4aa911ee0634c4eea842222e5211079c51b3b15097b54257fd8baf350281727b5d16e4410efb0c9bfec51ec7a92a9d266cf91ee64f1231c";

    function run() external {
        address mostRecentlyDeployedAirdropContract = address(
            DevOpsTools.get_most_recent_deployment(
                "MerkleAirdrop",
                block.chainid
            )
        );
        vm.startBroadcast();
        // n.b. in this demo the account calling this script, will be different than the account receiving the tokens
        claimAirdrop(mostRecentlyDeployedAirdropContract);
        vm.stopBroadcast();
    }

    function claimAirdrop(address airdrpContract) private {
        (uint8 v, bytes32 r, bytes32 s) = splitSignature(SIGNATURE);

        MerkleAirdrop(airdrpContract).claim(
            CLAIMING_ADDRESS, // that is, the address that's gonna be *receiving the airdrop
            CLAIMING_AMOUNT,
            proof, // the proof array
            v, // v,r,s are all components of the signature of the person allowing for someone else to pay in their stead to claim
            r,
            s
        );
    }

    function splitSignature(
        bytes memory signature
    ) public pure returns (uint8 v, bytes32 r, bytes32 s) {
        // 1) we first need to require that the lengeth of the signature is 65 bytes -> because 32 + 32 + 1 = 65 -> which is the length of v, r and s all together
        if (signature.length != 65) {
            revert __ClaimAirdrop__Invalid_Signature_Length();
        }

        // 2) we're using this code in assembly to BREAK UP the signature into v, r and s
        /* N.B. without going to deep in the nitty-gritty of the code below -> we are, from memory, i) loading the 1st 32 bytes and then setting it to r ii) then we're getting the 2nd 32 bytes and then setting it to s iii) and then we're the final byte and setting it to v -> and then we're returning it  
    
        */
        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        return (v, r, s);
    }
}
