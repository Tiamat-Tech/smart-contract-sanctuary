// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import './PapStaking.sol';

/**
    @dev IDO contract pool
 */
contract PAPpool {
    using SafeERC20 for IERC20Metadata;

    address public owner;

    IERC20Metadata lotteryToken;
    IERC20Metadata poolToken;
    PapStaking papStaking;
    CreatePapPool createPapPool;
    string description;

    struct Pool {
        uint256 poolID;
        uint256 timeStart;
        uint256 timeEnd;
        uint256 minAllocation;
        uint256 maxAllocation;
        uint256 tokensAmount;
        uint256 swapPriceNumerator;
        uint256 swapPriceDenominator;
    }

    struct VestingSettings {
        uint256 cliff;
        uint256 period;
        uint256 timeUnit;
        uint256 onTGE;
        uint256 afterUnlock;
        uint256 percentDenominator;
    }

    struct infoParticipants {
        address _participationAddress;
        uint256 _participatedAmount;
        uint256 _bank;
        uint256 _claimedIDO;
        PapStaking.Tier _tier;
        bool _claimedBack;
        bool _didParticipate;
    }

    mapping(address => infoParticipants) public participants;

    mapping(PapStaking.Tier => Pool) public pool;
    mapping(PapStaking.Tier => uint256) totalSupply;
    mapping(PapStaking.Tier => uint256) raised;
    mapping(PapStaking.Tier => address[]) winners;
    mapping(PapStaking.Tier => address[]) participantsAddressesByTier;
    mapping(PapStaking.Tier => uint256) poolTokenAmount;

    uint256 TGEStarted;
    bool isPoolClosed;
    VestingSettings settings;

    event ClosedPool(address indexed sender, uint256 indexed time, uint256 amount);
    event ClaimStarted(
        address indexed sender,
        uint256 indexed time,
        uint256 lotteryTokenAmount,
        uint256 poolTokenAmount
    );
    event ClaimedWinToken(address indexed sender, uint256 indexed time, uint256 amount);
    event ClaimedBack(address indexed sender, uint256 indexed time, uint256 amount);

    constructor(
        Pool memory _Tier1,
        Pool memory _Tier2,
        Pool memory _Tier3,
        address _lotteryTokenAddress,
        address _poolTokenAddress,
        address _papStakingAddress,
        address _createPapPoolAddress,
        string memory _description,
        VestingSettings memory _settings
    ) {
        lotteryToken = IERC20Metadata(_lotteryTokenAddress);
        poolToken = IERC20Metadata(_poolTokenAddress);

        papStaking = PapStaking(_papStakingAddress);
        createPapPool = CreatePapPool(_createPapPoolAddress);

        pool[PapStaking.Tier.TIER1] = _Tier1;
        pool[PapStaking.Tier.TIER2] = _Tier2;
        pool[PapStaking.Tier.TIER3] = _Tier3;

        totalSupply[PapStaking.Tier.TIER1] = _Tier1.tokensAmount;
        totalSupply[PapStaking.Tier.TIER2] = _Tier2.tokensAmount;
        totalSupply[PapStaking.Tier.TIER3] = _Tier3.tokensAmount;

        description = _description;
        settings = _settings;
    }

    modifier onlyAdmin() {
        require(createPapPool.poolAdmin(msg.sender), 'Restricted only to admins!');
        _;
    }

    function participate(uint256 _amount) public {
        require(
            participants[msg.sender]._didParticipate == false,
            'participate: you have already participated'
        );
        // Retrieving Information about participant and pool
        PapStaking.StakeInstance memory info = papStaking.UserInfo(msg.sender);

        PapStaking.Tier _tier = info.tier;

        require(
            _tier != PapStaking.Tier.NOTIER,
            "participate: you don't have a valid tier"
        );

        Pool storage _pool = pool[_tier];

        require(block.timestamp < _pool.timeEnd, 'participate: pool already ended');
        require(_pool.timeStart < block.timestamp, 'participate: pool not started');
        require(_amount > 0, 'participate: amount cant be zero');

        uint256 _maxParticipationAmount = _pool.maxAllocation;
        uint256 _minParticipationAmount = _pool.minAllocation;

        uint256 amountInLotteryTokens = ((_amount * _pool.swapPriceNumerator) *
            10**lotteryToken.decimals()) /
            _pool.swapPriceDenominator /
            10**poolToken.decimals();
        require(
            (_maxParticipationAmount >= amountInLotteryTokens) &&
                (amountInLotteryTokens >= _minParticipationAmount),
            'participate: amoutn is out of range'
        );

        require(
            amountInLotteryTokens <= totalSupply[_tier],
            'participate : amount value in lottery tokens is bigger that remained tokens'
        );

        poolToken.safeTransferFrom(msg.sender, address(this), _amount);
        totalSupply[_tier] -= amountInLotteryTokens;
        poolTokenAmount[_tier] += _amount;

        // Updating participationBook information
        participants[msg.sender]._participationAddress = msg.sender;
        participants[msg.sender]._participatedAmount = _amount;
        participants[msg.sender]._bank =
            ((_amount * pool[_tier].swapPriceNumerator) * 10**lotteryToken.decimals()) /
            pool[_tier].swapPriceDenominator /
            10**poolToken.decimals();

        // Updating participation status
        participants[msg.sender]._didParticipate = true;
        participants[msg.sender]._tier = _tier;
        //Adding to addressSet
        participantsAddressesByTier[_tier].push(msg.sender);
    }

    function closePool() public onlyAdmin {
        require(!isPoolClosed, 'closePool: pool is closed already');
        require(TGEStarted == 0, 'closePool: tge is started');
        require(
            (block.timestamp > pool[PapStaking.Tier.TIER1].timeEnd) &&
                (block.timestamp > pool[PapStaking.Tier.TIER1].timeEnd) &&
                (block.timestamp > pool[PapStaking.Tier.TIER1].timeEnd),
            'closePool: participation phase in not ended'
        );

        uint256 amountToTransfer = lotteryToken.balanceOf(address(this));
        if (amountToTransfer > 0)
            lotteryToken.safeTransfer(msg.sender, lotteryToken.balanceOf(address(this)));
        isPoolClosed = true;
        emit ClosedPool(msg.sender, block.timestamp, amountToTransfer);
    }

    /**
        @dev Admin can start TGE at any moment after end of participation phase.
        
     */
    function startClaim() public onlyAdmin {
        require(!isPoolClosed, 'closePool: pool is closed already');

        uint256 poolTokenToClaim;
        require(
            (block.timestamp > pool[PapStaking.Tier.TIER1].timeEnd) &&
                (block.timestamp > pool[PapStaking.Tier.TIER2].timeEnd) &&
                (block.timestamp > pool[PapStaking.Tier.TIER3].timeEnd),
            'startClaim: participation phase not ended yet'
        );
        require(TGEStarted == 0, 'startClaim: claim already started');

        winners[PapStaking.Tier.TIER1] = participantsAddressesByTier[
            PapStaking.Tier.TIER1
        ];
        winners[PapStaking.Tier.TIER2] = participantsAddressesByTier[
            PapStaking.Tier.TIER2
        ];

        winners[PapStaking.Tier.TIER3] = participantsAddressesByTier[
            PapStaking.Tier.TIER3
        ];

        poolTokenToClaim = poolToken.balanceOf(address(this));
        uint256 lotteryTokenToReturn = lotteryToken.balanceOf(address(this)) -
            ((((poolTokenAmount[PapStaking.Tier.TIER1] *
                pool[PapStaking.Tier.TIER1].swapPriceNumerator) *
                10**lotteryToken.decimals()) /
                pool[PapStaking.Tier.TIER1].swapPriceDenominator /
                10**poolToken.decimals()) +
                (((poolTokenAmount[PapStaking.Tier.TIER2] *
                    pool[PapStaking.Tier.TIER2].swapPriceNumerator) *
                    10**lotteryToken.decimals()) /
                    pool[PapStaking.Tier.TIER2].swapPriceDenominator /
                    10**poolToken.decimals()) +
                (((poolTokenAmount[PapStaking.Tier.TIER3] *
                    pool[PapStaking.Tier.TIER3].swapPriceNumerator) *
                    10**lotteryToken.decimals()) /
                    pool[PapStaking.Tier.TIER3].swapPriceDenominator /
                    10**poolToken.decimals()));

        raised[PapStaking.Tier.TIER1] = poolTokenAmount[PapStaking.Tier.TIER1];
        raised[PapStaking.Tier.TIER2] = poolTokenAmount[PapStaking.Tier.TIER2];
        raised[PapStaking.Tier.TIER3] = poolTokenAmount[PapStaking.Tier.TIER3];

        if (lotteryTokenToReturn > 0)
            lotteryToken.safeTransfer(msg.sender, lotteryTokenToReturn);
        if (poolTokenToClaim > 0) poolToken.safeTransfer(msg.sender, poolTokenToClaim);
        TGEStarted = block.timestamp;
        emit ClaimStarted(msg.sender, TGEStarted, lotteryTokenToReturn, poolTokenToClaim);
    }

    function calculateClaim(address user) public view returns (uint256) {
        if (TGEStarted == 0) return 0;
        uint256 startTimestamp = TGEStarted;
        uint256 vestingTime;
        if (block.timestamp > settings.period + startTimestamp)
            vestingTime = settings.period;
        else vestingTime = block.timestamp - startTimestamp;
        //getting bank of user
        uint256 bank = participants[user]._bank;
        //calculating onTGE reward
        uint256 rewardTGE = (bank * settings.onTGE) / settings.percentDenominator;
        //checking is round.onTGE is incorrect
        if (rewardTGE > bank) return bank;
        //if cliff isn't passed return only rewardTGE
        if (settings.cliff > vestingTime) return rewardTGE;
        //calculcating amount on unlock after cliff
        uint256 amountOnUnlock = (bank * settings.afterUnlock) /
            settings.percentDenominator;

        uint256 timePassedRounded = ((vestingTime - settings.cliff) / settings.timeUnit) *
            settings.timeUnit;
        if (amountOnUnlock + rewardTGE > bank) return bank;
        uint256 amountAfterUnlock = ((bank - amountOnUnlock - rewardTGE) *
            timePassedRounded) / (settings.period - settings.cliff);

        uint256 reward = rewardTGE + amountOnUnlock + amountAfterUnlock;
        if (reward > bank) return bank;
        return reward;
    }

    function claimWinToken() public {
        require(
            participants[msg.sender]._didParticipate == true,
            'claimWinToken: you did not participate'
        );

        PapStaking.Tier _tier = participants[msg.sender]._tier;
        require(_tier != PapStaking.Tier.NOTIER, 'claimWinToken: not valid tier');

        //      checking winner or not:
        require(
            participants[msg.sender]._claimedBack == false,
            'claimWinToken: you already claimed'
        );

        require(TGEStarted > 0, 'claimWinToken: claim is not started');

        //      claiming amount amoutput * swap price
        uint256 pending = calculateClaim(msg.sender) -
            participants[msg.sender]._claimedIDO;
        require(pending > 0, 'Nothing to claim at this moment');
        participants[msg.sender]._claimedIDO += pending;
        lotteryToken.safeTransfer(msg.sender, pending);
        emit ClaimedWinToken(msg.sender, block.timestamp, pending);
        if (participants[msg.sender]._claimedIDO == participants[msg.sender]._bank) {
            participants[msg.sender]._claimedBack = true;
        }
    }

    function claimPoolToken() public {
        require(isPoolClosed, 'claimPoolToken: pool is not closed');
        require(
            participants[msg.sender]._didParticipate == true,
            'You did not participate'
        );

        PapStaking.Tier _tier = participants[msg.sender]._tier;
        require(_tier != PapStaking.Tier.NOTIER, 'claimPoolToken: not valid tier');
        require(
            participants[msg.sender]._claimedBack == false,
            'claimPoolToken: You already claimed'
        );
        uint256 refundamount = participants[msg.sender]._participatedAmount;
        if (refundamount > 0) {
            poolToken.safeTransfer(msg.sender, refundamount);
        }
        participants[msg.sender]._claimedBack = true;
        emit ClaimedBack(msg.sender, block.timestamp, refundamount);
    }

    struct PapPoolInfo {
        Pool[3] pools;
        uint256[3] supplies;
        uint256[3] raised;
        address lotteryToken;
        address poolToken;
        address papStaking;
        uint256 TGEStarted;
        string description;
        VestingSettings settings;
        bool isPoolClosed;
    }

    function getPapPoolInfo() external view returns (PapPoolInfo memory info) {
        info = PapPoolInfo({
            pools: [
                pool[PapStaking.Tier.TIER1],
                pool[PapStaking.Tier.TIER2],
                pool[PapStaking.Tier.TIER3]
            ],
            supplies: [
                totalSupply[PapStaking.Tier.TIER1],
                totalSupply[PapStaking.Tier.TIER2],
                totalSupply[PapStaking.Tier.TIER3]
            ],
            raised: [
                raised[PapStaking.Tier.TIER1],
                raised[PapStaking.Tier.TIER2],
                raised[PapStaking.Tier.TIER3]
            ],
            lotteryToken: address(lotteryToken),
            poolToken: address(poolToken),
            papStaking: address(papStaking),
            TGEStarted: TGEStarted,
            description: description,
            settings: settings,
            isPoolClosed: isPoolClosed
        });
    }

    function getWinners(PapStaking.Tier _tier)
        external
        view
        returns (address[] memory _winners)
    {
        _winners = winners[_tier];
    }

    //mapping(address => participationRegistration) public didParticipate;
    function getUserInfo(address user)
        external
        view
        returns (infoParticipants memory userInfo)
    {
        return participants[user];
    }
}

contract CreatePapPool is Ownable {
    using SafeERC20 for IERC20Metadata;

    PAPpool[] public papAddressPool;
    address public papStakingAddress;
    address public lastPool;

    // For individual pap address, there is index(incremented) that stores address
    mapping(address => address[]) public OwnerPoolBook;
    // Array that will store all the PAP addresses, regardless of Owner
    mapping(address => bool) public poolAdmin;

    event CreatedPool(address pool, address indexed creator, uint256 indexed time);

    constructor(address _papStaking) {
        transferOwnership(msg.sender);
        papStakingAddress = _papStaking;
    }

    modifier onlyAdmin() {
        require(poolAdmin[msg.sender] == true, 'restricted to Admins!');
        _;
    }

    function setAdmin(address _address) public onlyOwner {
        require(poolAdmin[_address] == false, 'Already Admin');
        poolAdmin[_address] = true;
    }

    function revokeAdmin(address _address) public onlyOwner {
        require(poolAdmin[_address] == true, 'Not Admin');
        poolAdmin[_address] = false;
    }

    /** 
        @dev Creates a PAPpool contract;  
        @param _Tier1: Array of parameter(from front end), that is passed as transaction that will create pool
        @param _Tier2: Array of parameter(from front end), that is passed as transaction that will create pool
        @param _Tier3: Array of parameter(from front end), that is passed as transaction that will create pool
        @param _lotteryToken: Address of lotteryToken,
        @param _poolToken: Address of poolToken,
    */

    function createPool(
        PAPpool.Pool memory _Tier1,
        PAPpool.Pool memory _Tier2,
        PAPpool.Pool memory _Tier3,
        address _lotteryToken,
        address _poolToken,
        string memory _description,
        PAPpool.VestingSettings memory _settings
    ) external onlyAdmin {
        require(
            _Tier1.timeStart < _Tier1.timeEnd &&
                _Tier2.timeStart < _Tier2.timeEnd &&
                _Tier3.timeStart < _Tier3.timeEnd,
            'createPool : endTime to be more than startTime'
        );
        require(
            _Tier1.timeStart > block.timestamp &&
                _Tier2.timeStart > block.timestamp &&
                _Tier3.timeStart > block.timestamp,
            'createPool: invalid timeStart!'
        );
        require(
            _Tier1.maxAllocation >= _Tier1.minAllocation &&
                _Tier2.maxAllocation >= _Tier2.minAllocation &&
                _Tier3.maxAllocation >= _Tier3.minAllocation,
            'createPool: maxAllocation should be >= minAllocation'
        );
        require(
            _Tier1.maxAllocation > 0 &&
                _Tier2.maxAllocation > 0 &&
                _Tier3.maxAllocation > 0,
            'createPool: maxAllocation > 0'
        );
        require(
            _Tier1.tokensAmount >= _Tier1.maxAllocation &&
                _Tier2.tokensAmount >= _Tier2.maxAllocation &&
                _Tier3.tokensAmount >= _Tier3.maxAllocation,
            'createPool: tokensAmount > 0'
        );
        require(
            (_Tier1.swapPriceDenominator * _Tier1.swapPriceNumerator > 0) &&
                (_Tier2.swapPriceDenominator * _Tier2.swapPriceNumerator > 0) &&
                (_Tier3.swapPriceDenominator * _Tier3.swapPriceNumerator > 0),
            'createPool: swapNumerator != 0 and swapDenominator != 0 '
        );
        require(
            (_lotteryToken != address(0)) && (_poolToken != address(0)),
            'createPool: address cant be 0x0!'
        );
        require(
            (_settings.timeUnit > 0) &&
                (_settings.percentDenominator > 0) &&
                (_settings.cliff <= _settings.period) &&
                ((_settings.onTGE + _settings.afterUnlock) <=
                    _settings.percentDenominator),
            'createPool: invalid Vesting settings!'
        );

        PAPpool pappool = new PAPpool(
            _Tier1,
            _Tier2,
            _Tier3,
            _lotteryToken,
            _poolToken,
            papStakingAddress,
            address(this),
            _description,
            _settings
        );
        uint256 _idoToDeposit = _Tier1.tokensAmount +
            _Tier2.tokensAmount +
            _Tier3.tokensAmount;
        IERC20Metadata(_lotteryToken).safeTransferFrom(
            msg.sender,
            address(this),
            _idoToDeposit
        );
        IERC20Metadata(_lotteryToken).safeTransfer(address(pappool), _idoToDeposit);
        papAddressPool.push(pappool);
        lastPool = address(pappool);
        OwnerPoolBook[msg.sender].push(address(pappool));
        emit CreatedPool(address(pappool), msg.sender, block.timestamp);
    }

    function PAPAddresses(int256 offset, uint256 limit)
        public
        view
        returns (PAPpool[] memory)
    {
        uint256 len = papAddressPool.length;
        PAPpool[] memory poolAddresses;
        if (offset < 0) {
            if (limit >= len) return papAddressPool;
            poolAddresses = new PAPpool[](limit);
            for (uint256 i = 0; i < limit; i++) {
                poolAddresses[i] = papAddressPool[i + len - limit];
            }
            return poolAddresses;
        }
        if (limit == 0) return papAddressPool;
        if (uint256(offset) >= len) return new PAPpool[](0);
        if (uint256(offset) + limit > len) limit = len - uint256(offset);
        poolAddresses = new PAPpool[](limit);
        for (uint256 i = 0; i < limit; i++) {
            poolAddresses[i] = papAddressPool[i + uint256(offset)];
        }
        return poolAddresses;
    }

    //add limit and offset;
    function getOwnedPoolsAddresses(address user)
        external
        view
        returns (address[] memory ownedAddresses)
    {
        ownedAddresses = OwnerPoolBook[user];
    }

    function getPoolsInfo(PAPpool[] memory pools)
        external
        view
        returns (PAPpool.PapPoolInfo[] memory infos)
    {
        infos = new PAPpool.PapPoolInfo[](pools.length);
        for (uint256 i = 0; i < pools.length; i++) {
            infos[i] = pools[i].getPapPoolInfo();
        }
    }

    function getUserInfo(address[] memory pools, address user)
        external
        view
        returns (PAPpool.infoParticipants[] memory userInfo)
    {
        uint256 len = pools.length;
        userInfo = new PAPpool.infoParticipants[](len);
        for (uint256 i = 0; i < len; i++) {
            userInfo[i] = PAPpool(pools[i]).getUserInfo(user);
        }
    }
}