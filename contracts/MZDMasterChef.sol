// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./MZDRewards.sol";
import "./MZDPay.sol";

contract MZDMasterChef is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Struct to store user information
    struct UserInfo {
        uint256 amount; // How many LiqPool tokens the user has staked 
        uint256 pendingReward; // User's pending reward
    }

    // Struct to store pool information
    struct PoolInfo {
        IERC20 liqPoolToken; // Liquidity pool token address
        uint256 allocPoint; // How many allocation points assigned to this pool
        uint256 lastRewardBlock; // Last block number where rewards were calculated
        uint256 rewardTokenPerShare; // Accumulated reward tokens per share
    }

    MZDRewards public mzdr; // Reward token contract
    MZDPay public mzdpay; // Pay token contract
    address public dev; // Developer address
    uint256 public mzdPerBlock; // Reward tokens distributed per block

    // Mapping from pool ID to user address to user information
    mapping(uint256 => mapping(address => UserInfo)) public userInfo; 

    PoolInfo[] public poolInfo; // Array of pool information
    uint256 public totalAllocation = 0; // Total allocation points across all pools
    uint256 public startBlock; // Block number when reward distribution starts
    uint256 public BONUS_MULTIPLIER; // Bonus multiplier for early stakers

    // Events to track deposits, withdrawals, and emergency withdrawals
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        address initialOwner,
        MZDRewards _mzdr,
        MZDPay _mzdpay,
        address _dev,
        uint256 _mzdPerBlock,
        uint256 _startBlock,
        uint256 _multiplier
    ) Ownable() {
        transferOwnership(initialOwner);
        mzdr = _mzdr;
        mzdpay = _mzdpay;
        dev = _dev;
        mzdPerBlock = _mzdPerBlock;
        startBlock = _startBlock;
        BONUS_MULTIPLIER = _multiplier;

        // Adding a default pool
        poolInfo.push(PoolInfo({
            liqPoolToken: IERC20(address(_mzdr)),
            allocPoint: 10000,
            lastRewardBlock: _startBlock,
            rewardTokenPerShare: 0
        }));

        totalAllocation = 10000;
    }

    // Modifier to validate pool ID
    modifier validatePool(uint256 _pid) {
        require(_pid < poolInfo.length, "Invalid Pool Id ");
        _;
    }

    // Return number of pools
    function  poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Get information about a specific pool
    function getPoolInfo(uint256 pid) public view returns(
        address liqPoolToken,
        uint256 allocPoint,
        uint256 lastRewardBlock,
        uint256 rewardTokenPerShare
    ) {
        return (
            address(poolInfo[pid].liqPoolToken),
            poolInfo[pid].allocPoint,
            poolInfo[pid].lastRewardBlock,
            poolInfo[pid].rewardTokenPerShare
        );
    }

    // Calculate multiplier based on blocks
    function getMultiplier(address _from, uint256 _to) public view returns(uint256) {
        return (_to - (_from * BONUS_MULTIPLIER));
    }

    // Update the bonus multiplier
    function updateMultiplier(uint256 multiplierNumber) public onlyOwner {
        BONUS_MULTIPLIER = multiplierNumber;
    }

    // Ensure no duplicate pools exist
    function checkPoolDuplicate(IERC20 token) public view {
        uint256 length = poolInfo.length;
        for(uint256 _pid = 0; _pid < length; _pid++) {
            require(poolInfo[_pid].liqPoolToken != token, "Pool already exists");
        }
    }

    // Update staking pool with new allocation points
    function updateStakingPool() internal {
        uint256 length = poolInfo.length;
        uint256 points = 0;
        for(uint256 pid = 1; pid < length; pid++) {
            points += poolInfo[pid].allocPoint;
        }
        if(points != 0) {
            points /= 3;
            totalAllocation = ((totalAllocation - poolInfo[0].allocPoint) + points);
            poolInfo[0].allocPoint = points;
        }
    }

    // Add new liquidity pool
    function add(uint256 _allocPoint, IERC20 _liqPoolToken) public onlyOwner {
        checkPoolDuplicate(_liqPoolToken);
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocation += _allocPoint;
        poolInfo.push(PoolInfo({
            liqPoolToken: _liqPoolToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            rewardTokenPerShare: 0
        }));
        updateStakingPool();
    }

    // Update pool information
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
        uint256 tokenReward = ((multiplier * mzdPerBlock * pool.allocPoint) / totalAllocation);
        mzdr.mint(dev, tokenReward.div(10));
        mzdr.mint(address(mzdpay), tokenReward);
        pool.rewardTokenPerShare = pool.rewardTokenPerShare + ((tokenReward * 1e12) / liqPoolSupply);
        pool.lastRewardBlock = block.number;
    }

    // Mass update all pools
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for(uint256 pid; pid < length; pid++) {
            updatePool(pid);
        }
    }

    // Set allocation points for a pool
    function set(uint256 _pid, uint256 _allocPoint, bool _wihtUpdate) public onlyOwner {
        if(_wihtUpdate) {
            massUpdatePools();
        }
        uint256 prevAllocPoint = poolInfo[_pid].allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        if(prevAllocPoint != _allocPoint) {
            totalAllocation = ((totalAllocation - prevAllocPoint) + _allocPoint);
            updateStakingPool();
        }
    }

    // View function to check pending rewards
    function pendingReward(uint256 _pid, address _user) external view returns(uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 rewardTokenPerShare = pool.rewardTokenPerShare;
        uint256 liqPoolSupply = pool.liqPoolToken.balanceOf(address(this));
        if(block.number > pool.lastRewardBlock && liqPoolSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 tokenReward = ((multiplier * mzdPerBlock * pool.allocPoint) / totalAllocation);
            rewardTokenPerShare = rewardTokenPerShare + ((tokenReward * 1e12) / liqPoolSupply);
        }
        return ((user.amount * rewardTokenPerShare) / 1e12) - user.pendingReward;
    }

    // Function to stake tokens into a pool
    function stake(uint256 _pid, uint256 _amount) public validatePool(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if(user.amount > 0) {
            uint256 pending = ((user.amount * pool.rewardTokenPerShare) / 1e12) - user.pendingReward;
            if(pending > 0) {
                safeMzdTransfer(msg.sender, pending);
            }
        }
        if(_amount > 0) {
            pool.liqPoolToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount += _amount;
        }
        user.pendingReward = (user.amount * pool.rewardTokenPerShare) / 1e12;
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Function to unstake tokens from a pool
    function unstake(uint256 _pid, uint256 _amount) public validatePool(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        uint256 pending = ((user.amount * pool.rewardTokenPerShare) / 1e12) - user.pendingReward;
        if(pending > 0) {
            safeMzdTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount -= _amount;
            pool.liqPoolToken.safeTransfer(address(msg.sender), _amount);
        }
        user.pendingReward = (user.amount * pool.rewardTokenPerShare) / 1e12;
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Function to handle the auto-compounding of the staking rewards
    function autoCompound() public {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        updatePool(0);
        if (user.amount > 0) {
            uint256 pending = (user.amount * pool.rewardTokenPerShare / 1e12) - user.pendingReward;
            if(pending > 0) {
                user.amount += pending;
            }
        }
        user.pendingReward = (user.amount * pool.rewardTokenPerShare) / 1e12;
    }

    // Emergency withdrawal in case of any issue
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.liqPoolToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.pendingReward = 0;
    }

    // Safe MZD transfer function to handle rounding errors
    function safeMzdTransfer(address _to, uint256 _amount) internal {
        mzdpay.safeMzdTransfer(_to, amount);
    }

    // Function to change the developer
    function changeDev(address _dev) public {
        require(msg.sender == dev, "Not Authorized");
        dev = _dev;
    }
}