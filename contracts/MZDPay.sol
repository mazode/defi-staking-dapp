// SPDX-License-Identifier: GPL 3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./MZDRewards.sol";

contract MZDPay is Ownable, AccessControl{
    MZDRewards public mzdr;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    constructor(MZDRewards _mzdr) {
        mzdr = _mzdr;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MANAGER_ROLE, _msgSender());
      }

  function safeMzdTransfer(address _to, uint256 _amount) external {
    require(hasRole(MANAGER_ROLE, _msgSender()), "Not allowed");
    uint256 mzdBalance = mzdr.balanceOf(address(this));
    if (_amount > mzdBalance){
      mzdr.transfer(_to, mzdBalance);
    }
    else {
      mzdr.transfer(_to, _amount);
    }
  }

}