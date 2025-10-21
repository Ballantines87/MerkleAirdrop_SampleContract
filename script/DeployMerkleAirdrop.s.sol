// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";
import {BallToken} from "../src/BallToken.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Script} from "forge-std/Script.sol";

contract DeployMerkleAirdrop is Script {
    BallToken tokenContract;
    MerkleAirdrop airdropContract;

    // from the output.json file
    bytes32 private s_merkleRoot =
        0x7cdb6c21ef22a6cb5726d348e677f3e10032127425d425c5028965a30a71556e;
    uint256 private s_amountToTransfer = 4 * 25 * 1e18; // it's 4 times the amount, because in our demo we have 4 people claiming

    function run() external returns (BallToken, MerkleAirdrop) {
        vm.startBroadcast();
        tokenContract = new BallToken();
        airdropContract = new MerkleAirdrop(s_merkleRoot, tokenContract);

        // we need to mint the amount to airdrop first to the contract owner
        tokenContract.mint(tokenContract.owner(), s_amountToTransfer);

        // ... and then we need to transfer them to the airdropContract -> so that the amount's in the contract and able to be claimed by the claimers
        IERC20(tokenContract).transfer(
            address(airdropContract),
            s_amountToTransfer
        );
        vm.stopBroadcast();

        return (tokenContract, airdropContract);
    }
}
