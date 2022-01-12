// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract Vesting is Ownable {
    IERC20 public token;

    bool public TGEStarted;
    uint256 public constant WEEKS = 7 days;
    uint256 public constant MONTHS = 30 days;

    uint256 public startTimestamp;

    struct Round {
        uint256 roundID;
        uint256 lockPeriod;
        uint256 period;
        uint256 timeUnit;
        uint256 onTGE;
        uint256 afterUnlock;
        uint256 afterUnlockDenominator;
    }

    constructor(address _tokenAddress) {
        token = IERC20(_tokenAddress);
        transferOwnership(msg.sender);

        round_['seed'] = Round({
            roundID: 0,
            lockPeriod: MONTHS,
            period: 12 * MONTHS,
            timeUnit: MONTHS, //Time of withdraw should be in seconds.
            onTGE: 0,
            afterUnlock: 5,
            afterUnlockDenominator: 100
        });

        round_['private'] = Round({
            roundID: 1,
            lockPeriod: MONTHS,
            period: 12 * MONTHS,
            timeUnit: MONTHS, //Time of withdraw should be in seconds.
            onTGE: 8,
            afterUnlock: 0,
            afterUnlockDenominator: 100
        });

        round_['public'] = Round({
            roundID: 2,
            lockPeriod: 2 * WEEKS,
            period: 8 * WEEKS,
            timeUnit: 1 seconds, //Time of withdraw should be in seconds.
            onTGE: 30,
            afterUnlock: 0,
            afterUnlockDenominator: 100
        });
    }

    // Mapping to initialise Rounds (string) with token release.
    mapping(string => Round) public round_;
    // Mapping to check the amount of balance already claimed
    mapping(address => uint256) public BalanceClaimed;
    // Mapping to see how much token allocated for address for a specific round.
    mapping(string => mapping(address => uint256)) public TotalTokenAllocations;

    /**
    * @dev grants tokens to whitelisted accounts with respect to rounds.
           One account can be part of multiple accounts. This is only valid when TGE has not started.
           For any account re-specification, a new transaction should be sent.
    * @param _round: string input specifying round name
    * @param _accounts: With respect to one _round, the whitelisted account is initialised with tokens.
    * @param _amount: Amount initialised w.r.t. to account address for rounds
    */
    function grantToken(
        string memory _round,
        address[] memory _accounts,
        uint256[] memory _amount
    ) external TGENotStarted onlyOwner {
        bytes32 keccakSeed = keccak256(abi.encodePacked('seed'));
        bytes32 keccakPrivate = keccak256(abi.encodePacked('private'));
        bytes32 keccakPublic = keccak256(abi.encodePacked('public'));

        require(
            keccakSeed == keccak256(abi.encodePacked(_round)) ||
                keccakPrivate == keccak256(abi.encodePacked(_round)) ||
                keccakPublic == keccak256(abi.encodePacked(_round)),
            'Such round does not exist'
        );
        require(_accounts.length == _amount.length, 'Wrong inputs');

        uint256 length = _accounts.length;
        for (uint256 i = 0; i < length; i++) {
            require(_accounts[i] != address(0), 'The account cannot be zero');
            TotalTokenAllocations[_round][_accounts[i]] = _amount[i];
        }
    }

    /**
     * @dev As the timelapses, per second, the address, i.e. msg.sender can claim transaction
     */
    event Claimed(uint256, address, uint256);

    function claim() public TGEisStarted {
        uint256 claimed_ = claimed(msg.sender);
        require(claimed_ > 0, 'You dont have any tokens to claim.');
        require(
            token.balanceOf(address(this)) > claimed_,
            'Vesting contract doesnt have enough tokens'
        );
        BalanceClaimed[msg.sender] += claimed_;
        token.transfer(msg.sender, claimed_);
        emit Claimed(block.timestamp, msg.sender, claimed_);
    }

    /**
     * @dev User can check the amount available to claim from the timelapsed.
     * @param user: address for user to check available amount
     */
    function claimed(address user) public view TGEisStarted returns (uint256 amount) {
        uint256 total = claimedInCategory(user, 'seed') +
            claimedInCategory(user, 'private') +
            claimedInCategory(user, 'public') -
            BalanceClaimed[user];
        return total;
    }

    /**
     * @dev User can check the amount available to claim from the timelapsed for specific amount.
     * @param user: address for user to check available amount
     * @param categoryName: string name of the round
     */
    function claimedInCategory(address user, string memory categoryName)
        public
        view
        TGEisStarted
        returns (uint256 amount)
    {
        Round memory round = round_[categoryName];
        uint256 vestingTime;
        if (block.timestamp > round.period + startTimestamp) vestingTime = round.period;
        else vestingTime = block.timestamp - startTimestamp;
        //getting bank of user on category
        uint256 bank = TotalTokenAllocations[categoryName][user];
        //calculating onTGE reward
        uint256 rewardTGE = (bank * round.onTGE) / round.afterUnlockDenominator;
        //checking is round.onTGE is incorrect
        if (rewardTGE > bank) return bank;
        //if cliff isn't passed return only rewardTGE
        if (round.lockPeriod >= vestingTime) return rewardTGE;
        //calculcating amount on unlock after cliff
        uint256 amountOnUnlock = (bank * round.afterUnlock) /
            round.afterUnlockDenominator;

        uint256 timePassedRounded = ((vestingTime - round.lockPeriod) / round.timeUnit) *
            round.timeUnit;
        if (amountOnUnlock + rewardTGE > bank) return bank;
        uint256 amountAfterUnlock = ((bank - amountOnUnlock - rewardTGE) *
            timePassedRounded) / (round.period - round.lockPeriod);

        uint256 reward = rewardTGE + amountOnUnlock + amountAfterUnlock;
        if (reward > bank) return bank;
        return reward;
    }

    /**
     * @dev _address can check the total i.e. aggregated amount for specific address. Only owner
     * @param _address: address for user to check available amount
     */
    function totalTokensAllocated(address _address) public view returns (uint256) {
        uint256 totalTokens = TotalTokenAllocations['seed'][_address] +
            TotalTokenAllocations['private'][_address] +
            TotalTokenAllocations['public'][_address];

        return totalTokens;
    }

    /**
     * @dev Initialising TGE for starting claiming for token holders. Restricted to Only Contract Owner
     */
    function startTGE() external TGENotStarted onlyOwner {
        TGEStarted = true;
        startTimestamp = block.timestamp;
    }

    modifier TGEisStarted() {
        require(TGEStarted == true, 'TGE Not started');
        _;
    }

    modifier TGENotStarted() {
        require(TGEStarted == false, 'TGE Already started');
        _;
    }
}