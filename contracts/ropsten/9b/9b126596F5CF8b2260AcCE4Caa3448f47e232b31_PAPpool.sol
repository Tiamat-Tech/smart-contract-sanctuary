// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

interface IPapStaking {
    enum Tier {
        NOTIER,
        TIER3,
        TIER2,
        TIER1
    }
    struct StakeInstance {
        uint256 amount;
        uint256 lastInteracted;
        uint256 lastStaked; //For staking coolDown
        uint256 rewards;
        Tier tier;
    }

    function UserInfo(address user) external view returns (StakeInstance memory);
}

contract PAPpool {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    // Declare a set state variable
    EnumerableSet.AddressSet private addressSet;

    address public owner;
    //    bool public poolStarted;
    uint256 public nextAtIndex;

    IERC20 lotteryToken;
    IERC20 poolToken;

    IPapStaking papStaking;

    // Pool infomation
    struct Pool {
        uint256 poolID;
        uint256 timeStart;
        uint256 timeEnd;
        uint256 minAllocation;
        uint256 maxAllocation;
        uint256 tokensAmount;
        uint256 swapPriceNumerator;
        uint256 swapPriceDenominator;
        bool poolStarted;
        bool poolEnded;
    }
    struct participationRegistration {
        uint256 participationId;
        bool participate;
    }

    struct infoParticipants {
        address _participationAddress;
        uint256 _participatedAmount;
        uint256 _tier;
        bool _didWin;
        bool _claimedBack;
    }

    // Mapping string with Pool's Information
    mapping(string => Pool) public pool;

    // Mapping to check user's participation Information
    mapping(uint256 => infoParticipants) public participationBook;

    // Participation index;
    mapping(address => participationRegistration) public didParticipate;

    // participation Array of addresses
    address[] public participationAddress;

    constructor(
        Pool memory _Tier1,
        Pool memory _Tier2,
        Pool memory _Tier3,
        address _owner,
        address _lotteryTokenAddress,
        address _poolTokenAddress,
        address _papStakingAddress
    ) {
        // Owner of the contract
        owner = _owner;

        // DAITokenInfo
        lotteryToken = IERC20(_lotteryTokenAddress);

        // poolTokenInfo
        poolToken = IERC20(_poolTokenAddress);
        papStaking = IPapStaking(_papStakingAddress);

        pool['tierOne'] = Pool({
            poolID: _Tier1.poolID,
            timeStart: _Tier1.timeStart,
            timeEnd: _Tier1.timeEnd,
            minAllocation: _Tier1.minAllocation,
            maxAllocation: _Tier1.maxAllocation,
            tokensAmount: _Tier1.tokensAmount,
            swapPriceNumerator: _Tier1.swapPriceNumerator,
            swapPriceDenominator: _Tier1.swapPriceDenominator,
            poolStarted: false,
            poolEnded: false
        });

        pool['tierTwo'] = Pool({
            poolID: _Tier2.poolID,
            timeStart: _Tier2.timeStart,
            timeEnd: _Tier2.timeEnd,
            minAllocation: _Tier2.minAllocation,
            maxAllocation: _Tier2.maxAllocation,
            tokensAmount: _Tier2.tokensAmount,
            swapPriceNumerator: _Tier2.swapPriceNumerator,
            swapPriceDenominator: _Tier2.swapPriceDenominator,
            poolStarted: false,
            poolEnded: false
        });

        pool['tierThree'] = Pool({
            poolID: _Tier3.poolID,
            timeStart: _Tier3.timeStart,
            timeEnd: _Tier3.timeEnd,
            minAllocation: _Tier3.minAllocation,
            maxAllocation: _Tier3.maxAllocation,
            tokensAmount: _Tier3.tokensAmount,
            swapPriceNumerator: _Tier3.swapPriceNumerator,
            swapPriceDenominator: _Tier3.swapPriceDenominator,
            poolStarted: false,
            poolEnded: false
        });
    }

    modifier onlyOwner() {
        require(msg.sender == owner, 'Restricted only to owner');
        _;
    }

    function _getTierNumber(uint256 _tierNumber) private pure returns (string memory) {
        string memory _tierIdentifier;
        if (_tierNumber == 1) {
            _tierIdentifier = 'tierOne';
        }
        if (_tierNumber == 2) {
            _tierIdentifier = 'tierTwo';
        }
        if (_tierNumber == 3) {
            _tierIdentifier = 'tierThree';
        }
        return _tierIdentifier;
    }

    // function starting Pool
    function startTierPool(uint256 _TierNumber) public onlyOwner {
        // getting Amount to tansfer;
        string memory _tier = _getTierNumber(_TierNumber);
        require(pool[_tier].poolEnded == false, 'pool already ended');
        require(pool[_tier].poolStarted == false, 'pool already started');
        require(pool[_tier].timeStart <= block.timestamp, 'Too early to set');
        require(pool[_tier].timeEnd >= block.timestamp, 'Too late to set');
        uint256 _idoToDeposit = pool[_tier].tokensAmount;
        lotteryToken.safeTransferFrom(msg.sender, address(this), _idoToDeposit);
        pool[_tier].poolStarted = true;
    }

    function participate(uint256 _amount) public {
        // Retrieving Information about participant and pool
        IPapStaking.StakeInstance memory info = papStaking.UserInfo(msg.sender);
        uint256 _amountStaked = info.amount;
        uint256 _tierNumber = uint256(info.tier);
        require(_amountStaked != 0, "You don't have any staked amount");
        require(_tierNumber > 0, "You don't valid tier");

        string memory _tier = _getTierNumber(_tierNumber);

        uint256 _poolEndTime = pool[_tier].timeEnd;
        uint256 _poolStartTime = pool[_tier].timeStart;

        uint256 _maxParticipationAmount = pool[_tier].maxAllocation;
        uint256 _minParticipationAmount = pool[_tier].minAllocation;

        require(block.timestamp >= _poolStartTime, 'Pool not started');
        require(_poolEndTime >= block.timestamp, 'Pool already Ended');

        require(
            _maxParticipationAmount >=
                ((_amount * pool[_tier].swapPriceNumerator) /
                    pool[_tier].swapPriceDenominator) &&
                ((_amount * pool[_tier].swapPriceNumerator) /
                    pool[_tier].swapPriceDenominator) >=
                _minParticipationAmount,
            'Participation is out of range'
        );

        require(
            didParticipate[msg.sender].participate == false,
            'You have already participated'
        );

        poolToken.safeTransferFrom(msg.sender, address(this), _amount);

        // Updating participationBook information
        participationBook[nextAtIndex]._participationAddress = msg.sender;
        participationBook[nextAtIndex]._participatedAmount = _amount;

        // Updating participation status
        didParticipate[msg.sender].participationId = nextAtIndex;
        didParticipate[msg.sender].participate = true;
        //Adding to addressSet
        addressSet.add(msg.sender);
        //adding msg.senders to address book
        participationAddress.push(msg.sender);
        nextAtIndex++;
    }

    function getParticipationAddress() public view returns (address[] memory) {
        return participationAddress;
    }

    function _generateRandom(uint256 range) internal view returns (uint256) {
        return
            uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty))) %
            range;
    }

    // declaring winners w.r.t pools
    function declareWinner(uint256 _tierNumber) public onlyOwner {
        string memory _tier = _getTierNumber(_tierNumber);

        uint256 amountOfDAIsToClaim;

        // Only when poolEnds
        require(block.timestamp >= pool[_tier].timeEnd, 'PoolTime not ended yet');
        require(pool[_tier].poolStarted == true, 'Pool was not started');
        require(pool[_tier].poolEnded == false, 'Pool Already Ended!');

        // Numbers of winners = TokenAmount / maxAllocation
        uint256 _numberOfWinners = pool[_tier].tokensAmount / pool[_tier].maxAllocation;

        uint256 numberOfParticipants = participationAddress.length;
        for (uint256 i = 0; i < numberOfParticipants; i++) {
            if (i < _numberOfWinners) {
                uint256 _randomIndex = _generateRandom(addressSet.length());
                // getting address at that index in addressSet
                address _selectedAddress = addressSet.at(_randomIndex);

                // getting Index of that selected address
                uint256 _winnerAddressId = didParticipate[_selectedAddress]
                    .participationId;
                amountOfDAIsToClaim =
                    amountOfDAIsToClaim +
                    participationBook[_winnerAddressId]._participatedAmount;

                participationBook[_winnerAddressId]._didWin = true;

                // Popping winning address
                addressSet.remove(_selectedAddress);
            } else {
                break;
            }
        }

        // leave awards to claim (in DAI) here and send the remaining balance of DAI back to Owner
        // dai to return = balance(dai) - (amountOfDAIsToClaim * swapprice)
        uint256 dai_return = lotteryToken.balanceOf(address(this)) -
            ((amountOfDAIsToClaim * pool[_tier].swapPriceNumerator) /
                pool[_tier].swapPriceDenominator); //check it later make it right
        //        console.log(lotteryToken.balanceOf(msg.sender));
        lotteryToken.safeTransfer(msg.sender, dai_return);
        //        console.log(lotteryToken.balanceOf(msg.sender));

        //      claim DFTY Token
        //        console.log('DFTY in Contract', poolToken.balanceOf(address(this)));
        //        console.log('But DFTY pool creator can claim', amountOfDAIsToClaim);
        //        console.log('IDO Token in pool', lotteryToken.balanceOf(address(this)));
        poolToken.safeTransfer(msg.sender, amountOfDAIsToClaim);
        //        console.log('DFTY in to return (remaining)', poolToken.balanceOf(address(this)));
        pool[_tier].poolEnded = true;
    }

    function claimWinToken() public {
        require(
            didParticipate[msg.sender].participate == true,
            'You did not participate'
        );
        //      getting participation ID
        uint256 Id = didParticipate[msg.sender].participationId;
        //        console.log('Id',Id);
        //      checking winner or not:
        require(participationBook[Id]._didWin == true, 'You Did not win');
        require(participationBook[Id]._claimedBack == false, 'You already claimed');
        require(
            participationBook[Id]._participationAddress == msg.sender,
            'You cannot claim'
        );

        // (, , uint256 _tierNumber) = papStaking.UserInfo(msg.sender);
        IPapStaking.StakeInstance memory info = papStaking.UserInfo(msg.sender);
        uint256 _tierNumber = uint256(info.tier);

        string memory _tier = _getTierNumber(_tierNumber);
        //      claiming amount amoutput * swap price
        require(pool[_tier].poolEnded == true, 'Pool has not Ended');

        uint256 amountWon = (participationBook[Id]._participatedAmount *
            pool[_tier].swapPriceNumerator) / pool[_tier].swapPriceDenominator;

        lotteryToken.safeTransfer(msg.sender, amountWon);
        //        console.log(lotteryToken.balanceOf(address(this)));
        //        console.log(amountWon);

        participationBook[Id]._claimedBack = true;
    }

    function claimPoolToken() public {
        //      checking if it is winner
        //      getting msg.sender if pariticpated or not
        require(
            didParticipate[msg.sender].participate == true,
            'You did not participate'
        );

        //      getting participation ID
        uint256 participationId = didParticipate[msg.sender].participationId;

        // Getting User Tier
        uint256 _tierNumber = participationBook[participationId]._tier;
        string memory _tier = _getTierNumber(_tierNumber);
        require(pool[_tier].poolEnded == true, 'Pool has not Ended');

        //      checking winner or not:
        require(
            participationBook[participationId]._claimedBack == false,
            'You already claimed'
        );
        require(participationBook[participationId]._didWin == false, 'You Won');
        require(
            participationBook[participationId]._participationAddress == msg.sender,
            'You cannot claim'
        );
        //      claiming amount amoutput * swap price
        uint256 refundamount = participationBook[participationId]._participatedAmount;
        //        console.log(poolToken.balanceOf(address(this)));
        poolToken.safeTransfer(msg.sender, refundamount);
        participationBook[participationId]._claimedBack = true;
        //        console.log(poolToken.balanceOf(address(this)));
    }

    function getPapPoolInfo()
        external
        view
        returns (
            Pool memory,
            Pool memory,
            Pool memory
        )
    {
        return (pool['tierOne'], pool['tierTwo'], pool['tierThree']);
    }
}

contract CreatePapPool is Ownable {
    using SafeERC20 for IERC20;
    struct Counter {
        uint256 counter;
    }

    PAPpool[] public papAddressPool;
    address public papStakingAddress;
    address public lastPool;

    // Indexing for each user separate PAP contract addresses
    mapping(address => Counter) public NextCounterAt;
    // For individual pap address, there is index(incremented) that stores address
    mapping(address => mapping(uint256 => address)) public OwnerPoolBook;
    // Array that will store all the PAP addresses, regardless of Owner

    event papStakingChanged(address newPapStaking, uint256 time);

    constructor(address _papStaking) {
        transferOwnership(msg.sender);
        setPapStaking(_papStaking);
    }

    mapping(address => bool) public poolAdmin;

    function setPapStaking(address _papStaking) public onlyOwner {
        require(_papStaking != address(0), "Can't set 0x0 address!");
        papStakingAddress = _papStaking;
        emit papStakingChanged(_papStaking, block.timestamp);
    }

    function setAdmin(address _address) public onlyOwner {
        require(poolAdmin[_address] == false, 'Already Admin');
        poolAdmin[_address] = true;
    }

    function revokeAdmin(address _address) public onlyOwner {
        require(poolAdmin[_address] == true, 'Not Admin');
        poolAdmin[_address] = false;
    }

    modifier isAdmin() {
        require(poolAdmin[msg.sender] == true, 'restricted to Admins!');
        _;
    }

    /*
    @dev: function to allocate information as per pool, this function can be called once. It will create all tire at once.
    @Params _Tier: Array of parameter(from front end), that is passed as transaction that will create pool
    */
    function createPool(
        PAPpool.Pool memory _Tier1,
        PAPpool.Pool memory _Tier2,
        PAPpool.Pool memory _Tier3,
        address _lotteryTokenAddress,
        address _poolTokenAddress
    ) external isAdmin {
        // checking Parameters length
        //        require(_Tier1.length == 6 && _Tier2.length == 6 && _Tier3.length == 6, 'Wrong Tier Parameters');
        // StartTime to be more than endTime
        require(
            _Tier1.timeStart <= _Tier1.timeEnd &&
                _Tier2.timeStart <= _Tier2.timeEnd &&
                _Tier3.timeStart <= _Tier3.timeEnd,
            'EndTime to be more than startTime'
        );
        // _timeStart Cannot be in past
        require(
            _Tier1.timeStart >= block.timestamp &&
                _Tier2.timeStart >= block.timestamp &&
                _Tier3.timeStart >= block.timestamp,
            'Time cannot be in Past'
        );
        // maxAllocation >= minAllocation
        require(
            _Tier1.maxAllocation >= _Tier1.minAllocation &&
                _Tier2.maxAllocation >= _Tier2.minAllocation &&
                _Tier3.maxAllocation >= _Tier3.minAllocation,
            'maxAllocation >= minAllocation'
        );
        //
        //        uint256 _tokenAmountT1 = (_Tier1.tokensAmount;
        //        uint256 _tokenAmountT2 = (_Tier2.maxAllocation * _Tier2.swapPriceNumerator) /
        //            _Tier2.swapPriceDenominator;
        //        uint256 _tokenAmountT3 = (_Tier3.maxAllocation * _Tier3.swapPriceNumerator) /
        //            _Tier3.swapPriceDenominator;

        // get current counter
        uint256 _nextCounter = NextCounterAt[msg.sender].counter;

        PAPpool pappool = new PAPpool(
            _Tier1,
            _Tier2,
            _Tier3,
            msg.sender,
            _lotteryTokenAddress,
            _poolTokenAddress,
            papStakingAddress
        );
        papAddressPool.push(pappool);
        lastPool = address(pappool);
        OwnerPoolBook[msg.sender][_nextCounter] = address(pappool);
        NextCounterAt[msg.sender].counter++;
    }

    //
    function PAPAddresses() public view returns (PAPpool[] memory) {
        return papAddressPool;
    }
}