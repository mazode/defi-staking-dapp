// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

pragma solidity ^0.8.20;

contract MZDRewards is ERC20, ERC20Burnable, Ownable, AccessControl {
    using SafeERC20 for ERC20;

    mapping(address => uint256) private _balance;

    uint256 private _totalSupply;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE"); 

    constructor(address initialOwner) ERC20("MZD Rewards", "MZDR") Ownable(initialOwner) {
        grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
        grantRole(MANAGER_ROLE, initialOwner);
    }

    function mint(address to, uint256 amount) external {
        require(hasRole(MANAGER_ROLE, msg.sender), "Not allowed"); 
        _totalSupply += amount;
        _balance[to] += amount;
        _mint(to, amount);
    }

    function safeMzdTransfer(address _to, uint256 _amount) external {
        require(hasRole(MANAGER_ROLE, msg.sender), "Not allowed");
        uint256 mzdBalance = balanceOf(address(this));
        
        if(_amount > mzdBalance) {
            transfer(_to, mzdBalance);
        } else {
            transfer(_to, _amount);
        }
    }
}

