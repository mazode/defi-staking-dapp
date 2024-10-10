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

    modifier validatePool(uint256 _pid) {
        require(_pid < poolInfo.length, "Invalid Pool Id ");
        _;
    }

    function  poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function getPoolInfo(uint256 pid) public view returns(
        address liqPoolToken,
        uint256 allocPoint,
        uint256 lastRewardBlock,
        uint256 rewardTokenPerShare
    ) {
        return (
            (address(poolInfo[pid].liqPoolToken)),
            poolInfo[pid].allocPoint,
            poolInfo[pid].lastRewardBlock,
            poolInfo[pid].rewardTokenPerShare
        );
    }

    function getMultiplier(address _from, uint256 _to) public view returns(uint256) {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    function updateMultiplier(uint256 multiplierNumber) public onlyOwner {
        BONUS_MULTIPLIER = multiplierNumber;
    }

    function checkPoolDuplicate(IERC20 token) public view {
        uint256 length = poolInfo.length;
        for(uint256 _pid = 0; _pid < length; _pid++) {
            require(poolInfo[_pid].liqPoolToken != token, "Pool already exists");
        }
    }

    function updateStakingPool() internal {
        uint256 length = poolInfo.length;
        uint256 points = 0;
        for(uint256 pid = 1; pid < length; pid++) {
            points = points.add(poolInfo[pid].allocPoint);
        }
        if(points != 0) {
            points = points.div(3);
            totalAllocation = totalAllocation.sub(poolInfo[0].allocPoint).add(points);
            poolInfo[0].allocPoint = points;
        }
    }

    function add(uint256 _allocPoint, IERC20 _liqPoolToken) public onlyOwner {
        checkPoolDuplicate(_liqPoolToken);
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocation = totalAllocation.add(_allocPoint);
        poolInfo.push(PoolInfo({
            liqPoolToken: _liqPoolToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            rewardTokenPerShare: 0
        }));
        updateStakingPool();
    }

    function updatePool(uint256 _pid) public validatePool(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        if(block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 liqPoolSupply = pool.liqPoolToken.balanceOf(address(this));
        if(liqPoolSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 tokenReward = multiplier.mul(mzdPerBlock).mul(pool.allocPoint).div(totalAllocation);
        mzdr.mint(dev, tokenReward.div(10));
        mzdr.mint(address(mzdr), tokenReward);
        pool.rewardTokenPerShare = pool.rewardTokenPerShare.add(tokenReward).mul(1e12).div(liqPoolSupply);
        pool.lastRewardBlock = block.number;
    }

    function safeMzdrTransfer(address _to, uint256 _amount) internal {
        mzdr.safeMzdrTransfer(_to, amount);
    }

    function stake(uint256 _pid, uint256 _amount) public validatePool(_pid) {}

    function set(uint256 _pid, uint256 _allocPoint, bool _wihtUpdate) public onlyOwner {
        if(_wihtUpdate) {
            massUpdatePools();
        }
        uint256 prevAllocPoint = poolInfo[_pid].allocPoint;
        poolInfo[_pid].allocPoint = allocPoint;
        if(prevAllocPoint != _allocPoint) {
            totalAllocation = totalAllocation.sub(prevAllocPoint).add(_allocPoint);
            updateStakingPool();
        }
    }

}