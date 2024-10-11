// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./MZDRewards.sol";

contract MZDPay is AccessControl, Ownable {
    MZDRewards public mzdr; // Instance of MZDRewards contract

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE"); // Define manager role

    // Constructor to initialize the MZDRewards contract and assign roles
    constructor(MZDRewards _mzdr, address initialOwner) Ownable(initialOwner) {
        mzdr = _mzdr; // Set the MZDRewards token contract
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner); // Grant default admin role to initial owner
        _grantRole(MANAGER_ROLE, initialOwner); // Grant manager role to initial owner
    }

    // Safe transfer of MZD tokens, restricted to managers
    function safeMzdTransfer(address _to, uint256 _amount) external {
        require(hasRole(MANAGER_ROLE, msg.sender), "Not allowed"); // Check manager role
        uint256 mzdBalance = mzdr.balanceOf(address(this)); // Check contract's token balance
        if (_amount > mzdBalance) {
            mzdr.transfer(_to, mzdBalance); // Transfer entire balance if amount exceeds available tokens
        } else {
            mzdr.transfer(_to, _amount); // Transfer requested amount
        }
    }
}
