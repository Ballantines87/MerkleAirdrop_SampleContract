// this script is gonna split the signature into v, r, and s, taking the signature from the signature.txt file

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";

contract SplitSignature is Script {
    error __SplitSignatureScript__InvalidSignatureLength();

    // same function that we created in the Interactions.s.sol script
    function splitSignature(
        bytes memory sig
    ) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        if (sig.length != 65) {
            revert __SplitSignatureScript__InvalidSignatureLength();
        }

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }

    function run() external {
        // reads the signature.txt file
        string memory sig = vm.readFile("signature.txt");

        // then parses the bytes to get it into bytes from string
        bytes memory sigBytes = vm.parseBytes(sig);

        // then we are splitting it into v, r, and s, using that splitSignature() function
        (uint8 v, bytes32 r, bytes32 s) = splitSignature(sigBytes);

        // then we are logging that to the terminal
        console.log("v value:");
        console.log(v);
        console.log("r value:");
        console.logBytes32(r);
        console.log("s value:");
        console.logBytes32(s);
    }
}
