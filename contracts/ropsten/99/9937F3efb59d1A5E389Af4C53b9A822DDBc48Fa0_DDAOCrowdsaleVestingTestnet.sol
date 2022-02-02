// SPDX-License-Identifier: MIT
/* ========================================================== DEFI HUNTERS DAO ========================================================================
	                                                https://defihuntersdao.club/
--------------------------------------------------------------- February 2021 -------------------------------------------------------------------------
 #######       #######         #####         ####              #####                                           ####                     ###               
##########    ##########       #####      ##########         ########                                          ####                     ###               
###########   ###########     #######    ############      ##########                                          ####                     ###               
####    ####  ####    ####    #######    ####    ####      ####       ###  ##   ######   ###   ###   ###  #########   ######  #######   ###    ######     
####    ####  ####    ####    ### ###   ####      ####    ####        ####### #########  #### ####  #### ##########  #######  ########  ###   ########    
####     ###  ####     ###   #### ####  ####      ####    ####        ####### ####  #### #### ##### #### ####  #### ####           ###  ###  ####  ####   
####     ###  ####     ###   #########  ####      ####    ####        ####   ####    ###  ### ##### ### ####   ####  ######   ########  ###  ##########   
####    ####  ####    ####  ########### ####      ####    ####        ####   ####    ###  ###### ###### ####   ####   ###### #########  ###  ##########   
####   #####  ####   #####  ###########  ####    ####      #####      ####   ####   ####   ##### #####  ####   ####     #### ###   ###  ###  ####         
###########   ###########  ####     ###  ###########        ######### ####    ##########   ####  #####   ########## ######## #########  ###   ########    
#########     #########    ####     ####   ########          ######## ####     ########    ####   ###     ######### #######   ########  ###    #######    
                                                                       ##                                                                                 
                                            ####     ####                           ###                        
                                            ####     ####                      #    ###
                                             ####   ####                     ###    ###
                                             ####   ####   ######    ############## ###  ### #####     ########
                                             ####  ####   ########  ############### ###  ##########   #########
                                              #### ####  ####  ########     ######  ###  ##### ####  ####  ####
                                              #### ###   ########## ######   ###    ###  ####   ###  ###    ###
                                               #######   ##########  ######  ###    ###  ####   ###  ###    ###
                                               ######    ####          ####  ###    ###  ####   ###  ####  ####
                                                #####     ######## ########  ###### ###  ####   ###   #########
                                                ####       ####### #######   ###### ###  ####   ###    ########
                                                                                                          ####
                                                                                                      #########
                                                                                                      ####*/
pragma solidity 0.8.11;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

import "./Participants.sol";


/**
 * @notice Allows each token to be associated with a creator.
 */
contract DDAOCrowdsaleVestingTestnet is Ownable, Participants, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // https://polygonscan.com/token/0x90F3edc7D5298918F7BB51694134b07356F7d0C7 
    IERC20 public ddao = IERC20(0xF870b9C48C2B9757696c25988426e2A0941334B5);

    // https://polygonscan.com/token/0xca1931c970ca8c225a3401bb472b52c46bba8382
    IERC20 public addao = IERC20(0xB39f2AC6C5a9846d13B1644cae6d7AeF820eB0B3);

    mapping(uint8 => mapping(address => uint256)) public tokensClaimed;
    mapping(address => bool) public blacklist;

    uint256 constant public ROUND_SEED = 0;
    uint256 constant public ROUND_PRIVATE_1 = 1;
    uint256 constant public ROUND_PRIVATE_2 = 2;

    uint48 constant public START_DATE = 1646092800 - 86400*120; // 1 MAR.

    // Vesting periods are set in months
    uint256 constant public VESTING_PERIOD_SEED = 24;
    uint256 constant public VESTING_PERIOD_PRIVATE_1 = 18;
    uint256 constant public VESTING_PERIOD_PRIVATE_2 = 12;

    uint256 public oneMonth = 30 days;

    struct ClaimedInfo {
        uint48 timestamp;
        uint256 ddaoTokenAmount;
        uint256 claimNumber;
        uint256 blockNumber;
    }
    mapping(uint8 => mapping(address => uint256)) public claimAddressNumber;
    mapping(uint8 => mapping(address => mapping(uint256 => ClaimedInfo))) public claimByAddress; // Should know about round

    function claim(uint8 _round) public nonReentrant {
        require(_round == ROUND_SEED || _round == ROUND_PRIVATE_1 || _round == ROUND_PRIVATE_2, "CrowdsaleVesting: This round has not supported");
        uint256 tokensToSend = getTokensToSend(msg.sender, _round);

        require(seed[msg.sender] != 0 || private1[msg.sender] != 0 || private2[msg.sender] != 0, "CrowdsaleVesting: This wallet address is not in whitelist");
        require(tokensToSend > 0, "CrowdsaleVesting: Nothing to claim");
        require(!blacklist[msg.sender], "CrowdsaleVesting: This wallet address has been blocked");

        tokensClaimed[_round][msg.sender] += tokensToSend;

        addao.safeTransferFrom(msg.sender, address(this), tokensToSend);

        ddao.safeTransfer(msg.sender, tokensToSend);

        uint256 nextNumber = claimAddressNumber[_round][msg.sender] + 1;
        claimAddressNumber[_round][msg.sender] = nextNumber;

        claimByAddress[_round][msg.sender][nextNumber] = ClaimedInfo(uint48(block.timestamp), tokensToSend, nextNumber, block.number);
    }

    function getTokensToSend(address _address, uint8 _round) view public returns (uint256) {
        uint256 vestedAmount = addao.balanceOf(_address);
        if (vestedAmount == 0) {
            return 0;
        }
        uint256 calc = calculateUnlockedTokens(_address, _round, 0);
        if (calc > 0) {
            return calc - tokensClaimed[_round][_address];
        }
        return 0;
    }

    function calculateUnlockedTokens(address _address, uint8 _round, uint48 _date) public view returns (uint256 result) {
        require(_round == ROUND_SEED || _round == ROUND_PRIVATE_1 || _round == ROUND_PRIVATE_2, "CrowdsaleVesting: This round has not supported");

        uint48 timestamp;
        if (_date != 0) {
            timestamp = _date;
        } else {
            timestamp = uint48(block.timestamp);
        }

        if (timestamp <= START_DATE) {
            return result;
        }

        if (_round == ROUND_SEED) {
            result += availableTokenByRound(seed[_address], VESTING_PERIOD_SEED, timestamp);
        }
        if (_round == ROUND_PRIVATE_1) {
            result += availableTokenByRound(private1[_address], VESTING_PERIOD_PRIVATE_1, timestamp);
        }
        if (_round == ROUND_PRIVATE_2) {
            result += availableTokenByRound(private2[_address], VESTING_PERIOD_PRIVATE_2, timestamp);
        }
    }

    function availableTokenByRound(uint256 _availableAmount, uint256 _vestingPeriod, uint48 _timestamp) internal view returns (uint256) {
        uint256 secondsPassed = _timestamp - START_DATE;
        secondsPassed = secondsPassed > _vestingPeriod * oneMonth ? (_vestingPeriod * oneMonth) : secondsPassed;

        return (_availableAmount * secondsPassed) / (_vestingPeriod * oneMonth);
    }

    function lockAddress(address _address) public onlyOwner {
        blacklist[_address] = true;
    }

    function unlockAddress(address _address) public onlyOwner {
        blacklist[_address] = false;
    }

    function adminGetCoin(uint256 _amount) public onlyOwner {
        payable(msg.sender).transfer(_amount);
    }

    function adminGetToken(address _tokenAddress, uint256 _amount) public onlyOwner {
        IERC20(_tokenAddress).safeTransfer(msg.sender, _amount);
    }

    function balanceOf(address _address) public view returns (uint256 result) {
        result += seed[_address] - tokensClaimed[0][_address];
        result += private1[_address] - tokensClaimed[1][_address];
        result += private2[_address] - tokensClaimed[2][_address];
    }
}