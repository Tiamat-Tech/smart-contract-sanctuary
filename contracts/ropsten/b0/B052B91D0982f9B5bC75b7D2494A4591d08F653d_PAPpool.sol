// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import './PapStaking.sol';

contract PAPpool {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 constant DELAY = 3 days;

    address public owner;

    IERC20 lotteryToken;
    IERC20 poolToken;
    PapStaking papStaking;

    struct Pool {
        uint256 poolID;
        uint256 timeStart;
        uint256 timeEnd;
        uint256 minAllocation;
        uint256 maxAllocation;
        uint256 tokensAmount;
        uint256 swapPriceNumerator;
        uint256 swapPriceDenominator;
        bool finished;
    }

    struct infoParticipants {
        address _participationAddress;
        uint256 _participatedAmount;
        PapStaking.Tier _tier;
        bool _didWin;
        bool _claimedBack;
        bool _didParticipate;
    }

    mapping(address => infoParticipants) public participants;

    mapping(PapStaking.Tier => Pool) public pool;
    mapping(PapStaking.Tier => uint256) totalSupply;
    mapping(PapStaking.Tier => address[]) participantsAddressesByTier;
    mapping(PapStaking.Tier => EnumerableSet.AddressSet) private addressSet;

    constructor(
        Pool memory _Tier1,
        Pool memory _Tier2,
        Pool memory _Tier3,
        address _owner,
        address _lotteryTokenAddress,
        address _poolTokenAddress,
        address _papStakingAddress
    ) {
        owner = _owner;

        lotteryToken = IERC20(_lotteryTokenAddress);

        poolToken = IERC20(_poolTokenAddress);
        papStaking = PapStaking(_papStakingAddress);

        pool[PapStaking.Tier.TIER1] = _Tier1;
        pool[PapStaking.Tier.TIER2] = _Tier2;
        pool[PapStaking.Tier.TIER3] = _Tier3;

        totalSupply[PapStaking.Tier.TIER1] = _Tier1.tokensAmount;
        totalSupply[PapStaking.Tier.TIER2] = _Tier2.tokensAmount;
        totalSupply[PapStaking.Tier.TIER3] = _Tier3.tokensAmount;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, 'Restricted only to owner');
        _;
    }

    function participate(uint256 _amount) public {
        // Retrieving Information about participant and pool
        PapStaking.StakeInstance memory info = papStaking.UserInfo(msg.sender);

        PapStaking.Tier _tier = info.tier;
        Pool storage _pool = pool[_tier];

        require(
            _tier != PapStaking.Tier.NOTIER,
            "participate: you don't have a valid tier"
        );
        require(block.timestamp >= _pool.timeEnd, 'participate: pool already ended');
        require(_pool.timeStart >= block.timestamp, 'participate: pool not started');

        uint256 _maxParticipationAmount = _pool.maxAllocation;
        uint256 _minParticipationAmount = _pool.minAllocation;

        uint256 amountInLotteryTokens = (_amount * _pool.swapPriceNumerator) /
            _pool.swapPriceDenominator;
        require(
            (_maxParticipationAmount >= amountInLotteryTokens) &&
                (amountInLotteryTokens >= _minParticipationAmount),
            'participate: amoutn is out of range'
        );

        require(
            amountInLotteryTokens <= totalSupply[_tier],
            'participate : amount value in lottery tokens is bigger that remained tokens'
        );

        require(
            participants[msg.sender]._didParticipate == false,
            'participate: you have already participated'
        );

        poolToken.safeTransferFrom(msg.sender, address(this), _amount);
        totalSupply[_tier] -=
            (_amount * _pool.swapPriceNumerator) /
            _pool.swapPriceDenominator;

        // Updating participationBook information
        participants[msg.sender]._participationAddress = msg.sender;
        participants[msg.sender]._participatedAmount = _amount;

        // Updating participation status
        participants[msg.sender]._didParticipate = true;
        participants[msg.sender]._tier = _tier;
        //Adding to addressSet
        addressSet[_tier].add(msg.sender);

        participantsAddressesByTier[_tier].push(msg.sender);
    }

    function _generateRandom(uint256 range) internal view returns (uint256) {
        return
            uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty))) %
            range;
    }

    // declaring winners w.r.t pools
    //add time to declareWinner?
    function declareWinner(PapStaking.Tier _tier) public onlyOwner {
        Pool storage _pool = pool[_tier];
        uint256 poolTokenToClaim;

        // Only when poolEnds
        require(block.timestamp >= _pool.timeEnd, 'declareWinner: pool not ended yet');
        require(
            block.timestamp >= _pool.timeStart,
            'declareWinner: pool was not started'
        );
        require(
            _tier != PapStaking.Tier.NOTIER,
            'declareWinner: it is not a valid tier!'
        );
        if (block.timestamp >= _pool.timeEnd + DELAY) {
            require(_pool.finished == false, 'declareWinner: declare winner is blocked');
            lotteryToken.safeTransfer(msg.sender, lotteryToken.balanceOf(address(this)));
            _pool.finished = true;
            return;
        }
        require(_pool.finished == false, 'declareWinner: claim already started');

        uint256 _numberOfWinners = _pool.tokensAmount / _pool.maxAllocation; // check it on maxAllocation: 0;

        uint256 numberOfParticipants = participantsAddressesByTier[_tier].length; //change it to separate arrays
        if (numberOfParticipants <= _numberOfWinners) {
            for (uint256 i = 0; i < numberOfParticipants; i++) {
                participants[participantsAddressesByTier[_tier][i]]._didWin = true;
                poolTokenToClaim =
                    poolTokenToClaim +
                    participants[participantsAddressesByTier[_tier][i]]
                        ._participatedAmount;
            }
        } else {
            for (uint256 i = 0; i < _numberOfWinners; i++) {
                uint256 _randomIndex = _generateRandom(addressSet[_tier].length());
                address _selectedAddress = addressSet[_tier].at(_randomIndex);
                poolTokenToClaim =
                    poolTokenToClaim +
                    participants[_selectedAddress]._participatedAmount;
                participants[_selectedAddress]._didWin = true;
                addressSet[_tier].remove(_selectedAddress);
            }
        }
        // leave awards to claim here and send the remaining balance of DAI back to Owner
        // dai to return = balance(dai) - (poolTokenToClaim * swapprice)
        uint256 lotteryTokenToReturn = lotteryToken.balanceOf(address(this)) -
            ((poolTokenToClaim * _pool.swapPriceNumerator) / _pool.swapPriceDenominator);
        lotteryToken.safeTransfer(msg.sender, lotteryTokenToReturn);
        poolToken.safeTransfer(msg.sender, poolTokenToClaim);
        _pool.finished = true;
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
            participants[msg.sender]._didWin == true,
            'claimWinToken: you did not win'
        );
        require(
            participants[msg.sender]._claimedBack == false,
            'claimWinToken: you already claimed'
        );

        require(pool[_tier].finished == true, 'Pool has not finished');

        //      claiming amount amoutput * swap price

        uint256 amountWon = (participants[msg.sender]._participatedAmount *
            pool[_tier].swapPriceNumerator) / pool[_tier].swapPriceDenominator;

        lotteryToken.safeTransfer(msg.sender, amountWon);

        participants[msg.sender]._claimedBack = true;
    }

    function claimPoolToken() public {
        //      checking if it is winner
        //      getting msg.sender if pariticpated or not
        require(
            participants[msg.sender]._didParticipate == true,
            'You did not participate'
        );

        // Getting User Tier
        PapStaking.Tier _tier = participants[msg.sender]._tier;
        require(_tier != PapStaking.Tier.NOTIER, 'claimPoolToken: not valid tier');

        // if admin did not declareWinner in time
        if (block.timestamp <= pool[_tier].timeEnd + DELAY) {
            require(pool[_tier].finished == true, 'claimPoolToken: pool has not ended');
        }

        //      checking winner or not:
        require(
            participants[msg.sender]._claimedBack == false,
            'claimPoolToken: You already claimed'
        );
        require(participants[msg.sender]._didWin == false, 'claimPoolToken: You Won');

        uint256 refundamount = participants[msg.sender]._participatedAmount;

        poolToken.safeTransfer(msg.sender, refundamount);
        participants[msg.sender]._claimedBack = true;
    }

    struct PapPoolInfo {
        Pool[3] pools;
        uint256[3] supplies;
        address lotteryToken;
        address poolToken;
        address papStaking;
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
            lotteryToken: address(lotteryToken),
            poolToken: address(poolToken),
            papStaking: address(papStaking)
        });
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
    using SafeERC20 for IERC20;

    PAPpool[] public papAddressPool;
    address public papStakingAddress;
    address public lastPool;

    // For individual pap address, there is index(incremented) that stores address
    mapping(address => address[]) public OwnerPoolBook;
    // Array that will store all the PAP addresses, regardless of Owner
    mapping(address => bool) public poolAdmin;

    constructor(address _papStaking) {
        transferOwnership(msg.sender);
        papStakingAddress = _papStaking;
    }

    modifier isAdmin() {
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
        address _poolToken
    ) external isAdmin {
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
            _Tier1.tokensAmount > _Tier1.maxAllocation &&
                _Tier2.tokensAmount > _Tier2.maxAllocation &&
                _Tier3.tokensAmount > _Tier3.maxAllocation,
            'TokensAmount > 0'
        );
        require(
            (_Tier1.swapPriceDenominator > 0) &&
                (_Tier2.swapPriceDenominator > 0) &&
                (_Tier3.swapPriceDenominator > 0),
            "createPool: swapPriceDenominator can't be zero"
        );
        require(
            (_Tier1.swapPriceDenominator * _Tier1.swapPriceNumerator > 0) &&
                (_Tier2.swapPriceDenominator * _Tier2.swapPriceNumerator > 0) &&
                (_Tier3.swapPriceDenominator * _Tier3.swapPriceNumerator > 0),
            'swapNumerator != 0 and swapDenominator != 0 '
        );
        require(
            (_lotteryToken != address(0)) && (_poolToken != address(0)),
            'createPool: address cant be 0x0!'
        );
        _Tier1.finished = false;
        _Tier2.finished = false;
        _Tier3.finished = false;

        PAPpool pappool = new PAPpool(
            _Tier1,
            _Tier2,
            _Tier3,
            msg.sender,
            _lotteryToken,
            _poolToken,
            papStakingAddress
        );
        uint256 _idoToDeposit = _Tier1.tokensAmount +
            _Tier2.tokensAmount +
            _Tier3.tokensAmount;
        IERC20(_lotteryToken).safeTransferFrom(msg.sender, address(this), _idoToDeposit);
        IERC20(_lotteryToken).safeTransfer(address(pappool), _idoToDeposit);
        papAddressPool.push(pappool);
        lastPool = address(pappool);
        OwnerPoolBook[msg.sender].push(address(pappool));
    }

    function PAPAddresses() public view returns (PAPpool[] memory) {
        return papAddressPool;
    }

    //need to check
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