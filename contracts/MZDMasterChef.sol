// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./MZDRewards.sol";

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

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

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

    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for(uint256 pid; pid < length; pid++) {
            updatePool(pid);
        }
    }

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

    function pendingReward(uint256 _pid, address _user) external view returns(uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 rewardTokenPerShare = pool.rewardTokenPerShare;
        uint256 liqPoolSupply = pool.liqPoolToken.balanceOf(address(this));
        if(block.number > pool.lastRewardBlock && liqPoolSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 tokenReward = multiplier.mul(mzdPerBlock).mul(pool.allocPoint).div(totalAllocation);
            rewardTokenPerShare = rewardTokenPerShare.add(tokenReward.mul(1e12).div(liqPoolSupply));
        }
        return user.amount.mul(rewardTokenPerShare).div(1e12).sub(user.pendingReward);
    }

    function stake(uint256 _pid, uint256 _amount) public validatePool(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if(user.amount > 0) {
            uint256 pending = user.amount.mul(pool.rewardTokenPerShare).div(1e12).sub(user.pendingReward);
            if(pending > 0) {
                safeMzdTransfer(msg.sender, pending);
            }
        }
        if(_amount > 0) {
            pool.liqPoolToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.pendingReward = user.amount.mul(pool.rewardTokenPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    function unstake(uint256 _pid, uint256 _amount) public validatePool(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.rewardTokenPerShare).div(1e12).sub(user.pendingReward);
        if(pending > 0) {
            safeMzdTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.liqPoolToken.safeTransfer(address(msg.sender), _amount);
        }
        user.pendingReward = user.amount.mul(pool.rewardTokenPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    function autoCompound() public {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        updatePool(0);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.rewardTokenPerShare).div(1e12).sub(user.pendingReward);
            if(pending > 0) {
                user.amount = user.amount.add(pending);
            }
        }
        user.pendingReward = user.amount.mul(pool.rewardTokenPerShare).div(1e12);
    }
    
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.liqPoolToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.pendingReward = 0;
    }

    function safeMzdTransfer(address _to, uint256 _amount) internal {
        mzdr.safeMzdTransfer(_to, amount);
    }

    function changeDev(address _dev) public {
        require(msg.sender == dev, "Not Authorized");
        dev = _dev;
    }
}