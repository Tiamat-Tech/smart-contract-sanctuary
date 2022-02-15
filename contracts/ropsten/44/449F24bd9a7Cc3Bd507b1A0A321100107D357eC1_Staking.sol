// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity  ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./libraries/FullMath.sol";
import "./SetParams.sol";

contract Staking is SetParams {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    /// Array of addresses that we use to fund requests
    EnumerableSet.AddressSet internal requestArray;
    /// Constant address of BRBC, which is forbidden to owner for withdraw
    address constant internal BRBC_ADDRESS = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;

    IERC20 public USDC;
    IERC20 public BRBC;

    struct TokenLP {
        // USDC amount in
        uint USDCAmount;
        // BRBC amount in
        uint BRBCAmount;
        // End period of stake
        uint32 deadline;
        // Parameter that represesnts our rewards
        uint lastRewardGrowth;
        // true -> recieving rewards, false -> doesn't recieve
        bool isStaked; // uint 8
    }

    TokenLP[] public tokensLP;

    // Mapping that stores all token ids of an owner (owner => tokenIds[])
    mapping(address => EnumerableSet.UintSet) internal ownerToTokens;
    // tokenId => spender
    mapping(uint => address) public tokenApprovals;
    // owner => tokenId => boolean
    mapping(address => mapping(uint => bool)) public withdrawRequest;
    // withdrawAdress => tokenId => boolean
    mapping(address => mapping(uint => bool)) public approvedWithdrawToken;
    // tokenId => amount total collected
    mapping(uint => uint) public collectedRewardsForToken;

    // Total amount of USDC stacked in pool
    uint public poolUSDC;
    // Total amount of BRBC stacked in pool
    uint public poolBRBC;
    // Parameter that represesnts our rewards
    uint public rewardGrowth = 1;
    uint8 constant internal decimals = 18;

    /// List of events
    event Burn(address from, address to, uint tokenId);
    event Stake(address from, address to, uint amountUsdc, uint amountBrbc, uint period, uint tokenId);
    event Approve(address from, address to, uint tokenId);
    event Transfer(address from, address to, uint tokenId);
    event AddRewards(address from, address to, uint amount);
    event ClaimRewards(address from, address to, uint tokenId, uint userReward);
    event RequestWithdraw(address requestAddress, uint tokenId, uint amountUSDC, uint amountBRBC);
    event FromClaimRewards(address from, address to, uint tokenId, uint userReward);
    event Withdraw(address from, address to, uint tokenId, uint amountUSDC, uint amountBRBC);


    // TokenAddr will be hardcoded
    constructor(address _tokenAddrUSDC, address _tokenAddrBRBC) {
        // Set up roles
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER, msg.sender);
        // Rates for USDC/BRBC
        rate[30 seconds] = 100;
        rate[90 seconds] = 85;
        rate[180 seconds] = 70;
        // Set up penalty amount
        penalty = 10;
        // Initial start and end time
        startTime = block.timestamp; // + 5 seconds;
        endTime = startTime + 500 seconds;
        // set up pool size
        minUSDCAmount = 10000 * 10 ** decimals;
        maxUSDCAmount = 100000 * 10 ** decimals;
        maxPoolUSDC = 3000000 * 10 ** decimals;
        maxPoolBRBC = 3000000 * 10 ** decimals;
        // Set up tokens, might be hardcoded?
        USDC = IERC20(_tokenAddrUSDC);
        BRBC = IERC20(_tokenAddrBRBC);
        // Initial token id = 0 TODO: test is it nedeed?
        tokensLP.push(TokenLP(0, 0, 0, 0, false));
        penaltyReciver = msg.sender;
    }

    /// @dev Prevents calling a function from anyone except the owner,
    /// list all tokens of a user to find a match
    /// @param _tokenId the id of a token
    modifier OwnerOf(uint _tokenId) {
        require(
            ownerToTokens[msg.sender].contains(_tokenId) == true,
            "You need to be an owner"
        );
        _;
    }

    /// @dev Prevents using unstaked tokens
    /// @param _tokenId the id of a token
    modifier IsInStake(uint _tokenId) {
        require(
            tokensLP[_tokenId].isStaked == true,
            "Stake requested for withdraw"
        );
        _;
    }

    /// @dev Prevents calling a function from anyone except the approved person
    /// @param _tokenId the global token id of a token
    modifier ApprovedOf(uint _tokenId) {
        require(
            tokenApprovals[_tokenId] == msg.sender,
            "You must have approval to move your stake"
        );
        _;
    }

    /// @dev Prevents calling a function with two arrays of different length
    /// @param _array1 is the array of addreses with tokens or contracts
    /// @param _array2 is the array of amounts, which macthes addresses or contracts
    modifier ArrayLengthEquals(address[] calldata _array1, uint[] calldata _array2) {
        require(
            _array1.length == _array2.length,
            "Arrays length mismath"
        );
        _;
    }

    /// @dev Prevents withdrawing rewards with zero reward
    /// @param _tokenId global token id
    modifier PositiveRewards(uint _tokenId){
        require(
            viewRewards(_tokenId) > 0,
            "You have 0 rewards"
        );
        _;
    }

    /// @dev This modifier prevents one person to own more than 100k USDC for this address
    /// @param _stakeOwner the address of owner
    /// @param _amount the USDC amount to stake
    modifier MaxStakeAmount(address _stakeOwner, uint _amount) {
        uint[] memory ownerTokenList = getTokensByOwner(_stakeOwner);
        uint _usdcAmount = _amount;
        for (uint i = 0; i < ownerTokenList.length; i++) {
            _usdcAmount += tokensLP[ownerTokenList[i]].USDCAmount;
            require(
                _usdcAmount <= maxUSDCAmount,
                "Maximum amount for stake for one user is 100000 USDC"
            );
        }
        _;
    }

    /// @dev This modifier prevents transfer of tokens to self and null addresses
    /// @param _to the token reciever
    modifier TransferCheck (address _to) {
        require(
            _to != msg.sender && _to != address(0),
            "You can't transfer to yourself or to null address"
        );
        _;
    }

    /// @dev Main function, which recieves deposit, calls _mint LP function, freeze funds
    /// @param _amountUSDC the amount in of USDC
    /// @param _period the time while tokens will be freezed
    function stake(
        uint _amountUSDC,
        uint32 _period
    ) public MaxStakeAmount(msg.sender, _amountUSDC) {
        /// Prevent user enter stake before the start of staking
        require(
            block.timestamp >= startTime,
            "Staking period hasn't started"
        );
        /// Prevent user enter stake afer the end of staking
        require(
            block.timestamp <= endTime,
            "Staking period has ended"
        );
        /// Checks the validity of time input, prevents a user to enter for a long period if stake is already started
        require(
            _period == 30 seconds || _period == 90 seconds || _period == 180 seconds && block.timestamp + _period <= endTime,
            "Invalid period"
        );
        /// Minimal amount of USDC to stake at once
        require(
            _amountUSDC >= minUSDCAmount,
            "Minimum amount for stake is 10000 USDC"
        );
        /// Maximum amount of tokens freezed in pool
        require(
            poolUSDC + _amountUSDC <= maxPoolUSDC && poolBRBC + (_amountUSDC * rate[_period] / 100) <= maxPoolBRBC,
            "Max pool size exceeded"
        );
        /// Transfer USDC from user to the cross chain, BRBC to this contract, mints LP
        USDC.transferFrom(msg.sender, crossChain, _amountUSDC);
        BRBC.transferFrom(msg.sender, address(this), _amountUSDC * rate[_period] / 100);
        _mint(_amountUSDC, _amountUSDC * rate[_period] / 100, _period);
    }

    /// @dev list of all tokens that an address owns
    /// @param _tokenOwner the owner address
    /// returns uint array of token ids
    function getTokensByOwner(address _tokenOwner) public view returns(uint[] memory) {
        uint[] memory _result = new uint[](ownerToTokens[_tokenOwner].length());
        for (uint i = 0; i < ownerToTokens[_tokenOwner].length(); i++) {
            _result[i] = (ownerToTokens[_tokenOwner].at(i));
        }
        return _result;
    }

    /// @dev parsed array with all data from token ids
    /// @param _tokenOwner the owner address
    /// returns parsed array with all data from token ids
    function getTokensByOwnerParsed(address _tokenOwner) public view returns(TokenLP[] memory) {
        uint[] memory _tokens = new uint[](ownerToTokens[_tokenOwner].length());
        _tokens = getTokensByOwner(_tokenOwner);
        TokenLP[] memory _parsedArrayOfTokens = new TokenLP[](ownerToTokens[_tokenOwner].length());
        for (uint i = 0; i < _tokens.length; i++) {
            _parsedArrayOfTokens[i] = tokensLP[_tokens[i]];
        }
        return _parsedArrayOfTokens;
    }

    /// @dev Internal function that mints LP
    /// @param _USDCAmount the amount of USDT in
    /// @param _BRBCAmount the amount of BRBC in
    /// @param _timeBeforeUnlock the period of time, while which tokens are freezed
    function _mint(
        uint _USDCAmount,
        uint _BRBCAmount,
        uint32 _timeBeforeUnlock
    ) internal {
        tokensLP.push(TokenLP(_USDCAmount, _BRBCAmount, uint32(block.timestamp + _timeBeforeUnlock), rewardGrowth, true));
        uint _tokenId = tokensLP.length - 1;
        poolUSDC = poolUSDC + _USDCAmount;
        poolBRBC = poolBRBC + _BRBCAmount;
        ownerToTokens[msg.sender].add(_tokenId);
        emit Stake(address(0), msg.sender, _USDCAmount, _BRBCAmount, _timeBeforeUnlock, _tokenId);
    }

    /// @dev OnlyManager function, withdraws any erc20 tokens on this address except BRBC
    /// @param _tokenAddresses the array of contract addresses
    /// @param _tokenAmounts the array of amounts, which macthes contracts
    /// @param _to token reciever
    function withdrawToOwner(
        address[] calldata _tokenAddresses,
        uint[] calldata _tokenAmounts,
        address _to
    ) external OnlyManager ArrayLengthEquals(_tokenAddresses, _tokenAmounts) {
        if (_tokenAddresses.length > 0) {
            for (uint i = 0; i < _tokenAddresses.length; i++) {
                require(
                    _tokenAddresses[i] != BRBC_ADDRESS,
                    "You can't withdraw user's BRBC"
                );
                IERC20(_tokenAddresses[i]).transferFrom(address(this), _to, _tokenAmounts[i]);
            }
        }
    }

    /// @dev Internal function which burns LP tokens, clears data from mappings, arrays
    /// @param _tokenId the global token id that will be burnt
    function _burn(uint _tokenId) internal {
        poolUSDC = poolUSDC - tokensLP[_tokenId].USDCAmount;
        poolBRBC = poolBRBC - tokensLP[_tokenId].BRBCAmount;
        delete tokensLP[_tokenId];
        ownerToTokens[msg.sender].remove(_tokenId);
        tokenApprovals[_tokenId] = address(0);
        emit Burn(msg.sender, address(0), _tokenId);
    }

    /// @dev Approves _spender to move his stake, can be called only by an owner
    /// @param _spender the address which recieves permission to move the stake
    /// @param _tokenId the token id
    function approve(
        address _spender, uint _tokenId
    ) external
    OwnerOf(_tokenId)
    IsInStake(_tokenId) {
        tokenApprovals[_tokenId] = _spender;
        emit Approve(msg.sender, _spender, _tokenId);
    }

    /// @dev private function which is used to transfer stakes
    /// @param _from the sender address
    /// @param _to the recipient
    /// @param _tokenId global token id
    function _transfer(
        address _from,
        address _to,
        uint _tokenId
    ) private
    IsInStake(_tokenId) {
        ownerToTokens[_from].remove(_tokenId);
        ownerToTokens[_to].add(_tokenId);
        emit Transfer(_from, _to, _tokenId);
    }

    /// @dev Transfer function, check for validity address to, ownership of the token, the USDT amount of recipient
    /// @param _to the recipient
    /// @param _tokenId the token id
    function transfer(
        address _to,
        uint _tokenId
    ) external
    TransferCheck(_to)
    OwnerOf(_tokenId) {
        _transfer(msg.sender, _to, _tokenId);
    }

    /// @dev Transfer function, check for validity address to, allowance of the token, the USDT amount of recipient
    /// @param _from the sender address
    /// @param _to the recipient
    /// @param _tokenId the token id
    function transferFrom(
        address _from,
        address _to,
        uint _tokenId
    ) external
    TransferCheck(_to)
    ApprovedOf(_tokenId) {
        _transfer(_from, _to, _tokenId);
    }

    /// @dev OnlyManager function, adds rewards for users
    /// @param _amount the USDC amount of comission to the pool
    function addRewards(uint _amount) external OnlyManager {
        USDC.transferFrom(msg.sender, address(this), _amount);
        rewardGrowth = rewardGrowth + FullMath.mulDiv(_amount, 10 ** 29, poolUSDC);
        emit AddRewards(msg.sender, address(this), _amount);
    }

    /// @dev Shows the amount of rewards that wasn't for a token, doesn't give permission to see null token
    /// @param _tokenId the token id
    /// returns reward in USDC
    function viewRewards(uint _tokenId) public view IsInStake(_tokenId) returns (uint) {
        return tokensLP[_tokenId].USDCAmount * (rewardGrowth - tokensLP[_tokenId].lastRewardGrowth) / (10 ** 29);
    }

    /// @dev Shows the amount of rewards that wasn claimed for a token, doesn't give permission to see null token
    /// @param _tokenId the token id
    /// returns reward in USDC
    function viewCollectedRewards(uint _tokenId) public view returns (uint) {
        return collectedRewardsForToken[_tokenId];
    }

    /// @dev Withdraw reward USDT from the contract, checks if the reward is positive,
    /// @dev doesn't give permission to use null token
    /// @param _tokenId the global token id
    /// Added param rewardAmount for reentrancy protection
    function claimRewards(uint _tokenId)
    public
    OwnerOf(_tokenId)
    IsInStake(_tokenId)
    PositiveRewards(_tokenId) {
        uint _rewardAmount = viewRewards(_tokenId);
        tokensLP[_tokenId].lastRewardGrowth = rewardGrowth;
        collectedRewardsForToken[_tokenId] += _rewardAmount;
        USDC.transfer(msg.sender, _rewardAmount);
        emit ClaimRewards(address(this), msg.sender, _tokenId, _rewardAmount);
    }

    /// @dev Same as claimRewards function but can be called from approved user
    /// @param _tokenId the token id
    /// Added param rewardAmount for reentrancy protection
    function fromClaimRewards(uint _tokenId)
    external
    IsInStake(_tokenId)
    ApprovedOf(_tokenId)
    PositiveRewards(_tokenId) {
        uint rewardAmount = viewRewards(_tokenId);
        tokensLP[_tokenId].lastRewardGrowth = rewardGrowth;
        USDC.transfer(msg.sender, rewardAmount);
        emit FromClaimRewards(address(this), msg.sender, _tokenId, rewardAmount);
    }

    /// @dev Send a request for withdraw, claims reward, stops staking
    /// @param _tokenId the token id
    function requestWithdraw(uint _tokenId) external OwnerOf(_tokenId) IsInStake(_tokenId) {
        require(
            withdrawRequest[msg.sender][_tokenId] == false,
            "You request is already sent"
        );
        withdrawRequest[msg.sender][_tokenId] = true;
        requestArray.add(msg.sender);

        claimRewards(_tokenId);
        tokensLP[_tokenId].isStaked = false;

        /// TODO: is it reentrancy protected?
        if (tokensLP[_tokenId].deadline < block.timestamp - 1 seconds) {
            poolUSDC -= tokensLP[_tokenId].USDCAmount * penalty / 100;
            tokensLP[_tokenId].USDCAmount = tokensLP[_tokenId].USDCAmount * (100 - penalty) / 100;
            poolBRBC -= tokensLP[_tokenId].BRBCAmount * penalty / 100;
            uint beforePenaltyBRBC = tokensLP[_tokenId].BRBCAmount;
            tokensLP[_tokenId].BRBCAmount = tokensLP[_tokenId].BRBCAmount * (100 - penalty) / 100;
            BRBC.transfer(penaltyReciver, beforePenaltyBRBC * penalty / 100);
        }
        emit RequestWithdraw(msg.sender, _tokenId, tokensLP[_tokenId].USDCAmount, tokensLP[_tokenId].BRBCAmount);
    }

    /// @dev Shows the status of the user's token id for withdraw
    /// @param _from token owner
    /// @param _tokenId the token id
    function viewRequests(address _from, uint _tokenId) public view returns(bool) {
        return withdrawRequest[_from][_tokenId];
    }

    /// @dev Shows the array of addresses, which made a request
    function getRequestArray() public view returns (address[] memory) {
        address[] memory _result = new address[](requestArray.length());
        for (uint i = 0; i < requestArray.length(); i++) {
            _result[i] = requestArray.at(i);
        }
        return _result;
    }

    /// @dev Send USDC to contract, after this address can withdraw funds back
    /// @param _withdrawAddress the array of addresses reciving withdraw
    /// @param _tokenIds the array of token ids, which macthes addresses
    function fundRequestsForWithdraw(
        address[] calldata _withdrawAddress,
        uint[] calldata _tokenIds
        ) external OnlyManager ArrayLengthEquals(_withdrawAddress, _tokenIds) {
        uint _fundAmount;
        for (uint i = 0; i < _withdrawAddress.length; i++) {
            require(
                withdrawRequest[_withdrawAddress[i]][_tokenIds[i]] == true,
                "Address doesn't make request to withdraw"
            );
            _fundAmount += tokensLP[_tokenIds[i]].USDCAmount;

            approvedWithdrawToken[_withdrawAddress[i]][_tokenIds[i]] = true;
            requestArray.remove(_withdrawAddress[i]); /// TODO: TEST
            delete(withdrawRequest[_withdrawAddress[i]][_tokenIds[i]]);
        }
        USDC.transferFrom(msg.sender, address(this), _fundAmount);
    }

    /// @dev User withdraw his freezed USDC and BRBC after stake
    /// @param _tokenId the token id
    function withdraw(uint _tokenId) external OwnerOf(_tokenId) {
        require(
            approvedWithdrawToken[msg.sender][_tokenId] == true,
            "Your must send withdraw request first, or your request hasn't been approved"
        );
        delete(approvedWithdrawToken[msg.sender][_tokenId]);
        USDC.transfer(msg.sender, tokensLP[_tokenId].USDCAmount);
        BRBC.transfer(msg.sender, tokensLP[_tokenId].BRBCAmount);
        _burn(_tokenId);
        emit Withdraw(address(this), msg.sender, _tokenId, tokensLP[_tokenId].USDCAmount, tokensLP[_tokenId].BRBCAmount);
    }

}