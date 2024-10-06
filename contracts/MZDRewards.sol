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
    using SafeMath for uint256;
    using SafeERC20 for ERC20;

    mapping(address => uint256) private _balance;

    uint256 private _totalSupply;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE"); 

    constructor() ERC20("MZD Rewards", "MZDR") {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MANAGER_ROLE, _msgSender());
    }
}

