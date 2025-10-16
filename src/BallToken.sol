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

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract BallToken is ERC20, Ownable {
    constructor() ERC20("BallToken", "BT") Ownable(msg.sender) {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
