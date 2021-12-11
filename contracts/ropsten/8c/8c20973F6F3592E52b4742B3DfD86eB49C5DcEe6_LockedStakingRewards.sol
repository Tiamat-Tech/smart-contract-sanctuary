//SPDX License Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract LockedStakingRewards is Ownable, ReentrancyGuard {
    IERC20 public stakeToken;

    uint256 public constant depositDuration = 7 days;

    struct Pool {
        uint256 tokenPerShareMuliplier;
        bool isTerminated;
        uint256 cycleDuration;
        uint256 startOfDeposit;
        uint256 tokenPerShare;
    }

    mapping(uint256 => Pool) private pool;

    mapping(address => mapping(uint256 => uint256)) private _shares;

    constructor(IERC20 _stakeToken, Pool[] memory _initialPools) {
        stakeToken = _stakeToken;
        for (uint256 i = 0; i < _initialPools.length; i++) {
            createPool(i, _initialPools[i]);
        }
    }

    function receiveApproval
    (
        address _sender,
        uint256 _amount,
        address _stakeToken,
        bytes memory data
    )
        external
        nonReentrant
    {
        uint256 _pool;
        assembly {
            _pool := mload(add(data, 0x20))
        }
        require(isTransferPhase(_pool), "pool is locked currently");

        require(stakeToken.transferFrom(_sender, address(this), _amount));
        _shares[_sender][_pool] += _amount * 1e4 / pool[_pool].tokenPerShare;
        emit Staked(_sender, _pool, _amount);
    }

    function withdraw(uint256 _sharesAmount, uint256 _pool) external nonReentrant {
        require(isTransferPhase(_pool), "pool is locked currently");
        require(_sharesAmount <= _shares[msg.sender][_pool], "cannot withdraw more than balance");

        _shares[msg.sender][_pool] -= _sharesAmount;
        uint256 tokenAmount = _sharesAmount * pool[_pool].tokenPerShare / 1e4;
        require(stakeToken.transfer(msg.sender, tokenAmount));
        emit Unstaked(msg.sender, _pool, tokenAmount);
    }

    function updatePool(uint256 _pool) public {
        require
        (
            block.timestamp > pool[_pool].startOfDeposit + depositDuration &&
            block.timestamp < pool[_pool].startOfDeposit + pool[_pool].cycleDuration &&
            ! pool[_pool].isTerminated,
            "can only update once per cycle on not terminated pools"
        );
        pool[_pool].startOfDeposit += pool[_pool].cycleDuration;
        pool[_pool].tokenPerShare = pool[_pool].tokenPerShare * pool[_pool].tokenPerShareMuliplier / 1e4;
        emit PoolUpdated(_pool, pool[_pool].startOfDeposit, pool[_pool].tokenPerShare);
    }

        ///////////// Restricted Access Functions /////////////

    function updateTokenPerShareMuliplier(uint256 _pool, uint256 newTokenPerShareMuliplier) external onlyOwner {
        require(isTransferPhase(_pool), "pool only updateable during transfer phase");
        pool[_pool].tokenPerShareMuliplier = newTokenPerShareMuliplier;
    }

    function terminatePool(uint256 _pool) public onlyOwner {
        pool[_pool].isTerminated = true;
        emit PoolKilled(_pool);
    }

    function createPool(uint256 _pool, Pool memory pool_) public onlyOwner {
        require(pool[_pool].cycleDuration == 0, "cannot override an existing pool");
        pool[_pool] = pool_;
        emit PoolUpdated(_pool, pool[_pool].startOfDeposit, pool[_pool].tokenPerShare);
    }

        ///////////// View Functions /////////////

    function isTransferPhase(uint256 _pool) public view returns(bool) {
        return(
            (block.timestamp > pool[_pool].startOfDeposit &&
            block.timestamp < pool[_pool].startOfDeposit + depositDuration) ||
            pool[_pool].isTerminated
        );
    }

    function getPoolInfo(uint256 _pool) public view returns(Pool memory) {
        return pool[_pool];
    }

    function viewUserShares(address _user, uint256 _pool) public view returns(uint256) {
        return _shares[_user][_pool];
    }

    function viewUserTokenAmount(address _user, uint256 _pool) public view returns(uint256) {
        return viewUserShares(_user, _pool) * pool[_pool].tokenPerShare;
    }

    function sharesToToken(uint256 _sharesAmount, uint256 _pool) public view returns(uint256) {
        return _sharesAmount * pool[_pool].tokenPerShare / 1e4;
    }

    function tokenToShares(uint256 _tokenAmount, uint256 _pool) public view returns(uint256) {
        return _tokenAmount * 1e4 / pool[_pool].tokenPerShare;
    }

        ///////////// Events /////////////
    
    event Staked(address indexed staker, uint256 indexed pool, uint256 amount);
    event Unstaked(address indexed staker, uint256 indexed pool, uint256 amount);
    event PoolUpdated(uint256 indexed pool, uint256 newDepositStart, uint256 newTokenPerShare);
    event PoolKilled(uint256 indexed pool);
}