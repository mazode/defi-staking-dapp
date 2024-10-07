// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./MZDRewards.sol";
// import "./N2D-DeFI-Staking-N2DRPay-SmartContract.sol";

contract MZDMasterChefV1 is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct UserInfo {
        uint256 amount;
        uint256 pendingReward;
    }

    struct PoolInfo {
        uint256 liqPoolToken;
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 rewardTokenPerShare;
    }

    MZDRewards public mzdr;
    address public dev;
    uint256 public mzdPerBlock; // Amount of token issued everytime a block is processed

    /*
       Mapping to get wallet address from pool Id,
       and then map that wallet address to the struct
       to obtain the amount of the user.
     */
    mapping(uint256 => mapping(address => UserInfo)) public userInfo; 

    PoolInfo[] public poolInfo;
    uint256 public totalAllocation = 0; // Total pool allocation combined
    uint256 public startBlock;
    uint256 public BONUS_MULTIPLIER;

    constructor(
        MZDRewards _mzdr,
        address _dev,
        uint256 _mzdPerBlock,
        uint256 _startBlock,
        uint256 _multiplier
    ) public {
        mzdr = _mzdr;
        dev = _dev;
        mzdPerBlock = _mzdPerBlock;
        startBlock = _startBlock;
        BONUS_MULTIPLIER = _multiplier;

        poolInfo.push(PoolInfo({
            liqPoolToken: _mzdr,
            allocPoint: 10000,
            lastRewardBlock: _startBlock,
            rewardTokenPerShare: 0
        }));

        totalAllocation = 10000;
    }

}