// ▄██▓███   ▄▄▄       ██ ▄█▀ ███▄ ▄███▓ ▄▄▄       ███▄    █
// ▓██░  ██▒▒████▄     ██▄█▒ ▓██▒▀█▀ ██▒▒████▄     ██ ▀█   █
// ▓██░ ██▓▒▒██  ▀█▄  ▓███▄░ ▓██    ▓██░▒██  ▀█▄  ▓██  ▀█ ██▒
// ▒██▄█▓▒ ▒░██▄▄▄▄██ ▓██ █▄ ▒██    ▒██ ░██▄▄▄▄██ ▓██▒  ▐▌██▒
// ▒██▒ ░  ░ ▓█   ▓██▒▒██▒ █▄▒██▒   ░██▒ ▓█   ▓██▒▒██░   ▓██░
// ▒▓▒░ ░  ░ ▒▒   ▓▒█░▒ ▒▒ ▓▒░ ▒░   ░  ░ ▒▒   ▓▒█░░ ▒░   ▒ ▒
// ░▒ ░       ▒   ▒▒ ░░ ░▒ ▒░░  ░      ░  ▒   ▒▒ ░░ ░░   ░ ▒░
// ░░         ░   ▒   ░ ░░ ░ ░      ░     ░   ▒      ░   ░ ░
// ░              ░  ░░  ░          ░         ░  ░         ░

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Token.sol";

//not upgradable by design
contract YieldFarm {
    /* MAPPINGS */
    // userAddress => stakingBalance
    mapping(address => uint256) public stakingBalance;
    // userAddress => isStaking boolean
    mapping(address => bool) public isStaking;
    // userAddress => timeStamp
    mapping(address => uint256) public startTime;
    //// startTime will watch userAddress' timestamp
    //// in order to track the unrealized yield

    // userAddress => tokenBalance
    mapping(address => uint256) public tokenBalance;
    //// tokenBalance will point to the realized
    //// Token yield associated with userAddress

    /* STATE VARIABLES */
    IERC20 public wethToken;
    Token public token;

    /* EVENTS */
    event Stake(address indexed from, uint256 amount);
    event Unstake(address indexed from, uint256 amount);
    event YieldWithdraw(address indexed to, uint256 amount);

    constructor(IERC20 _wethToken, Token _token) {
        wethToken = _wethToken;
        token = _token;
    }

    /* FUNCTIONS */
    function stake(uint256 amount) public {
        require(amount > 0 && wethToken.balanceOf(msg.sender) >= amount, "Insufficient amount of tokens to stake");

        if (isStaking[msg.sender] == true) {
            uint256 toTransfer = calculateYieldTotal(msg.sender);
            // toTransfer variable equal to the
            // calculateYieldTotal function so to help with test latency
            tokenBalance[msg.sender] += toTransfer;
        }

        wethToken.transferFrom(msg.sender, address(this), amount);
        stakingBalance[msg.sender] += amount;
        startTime[msg.sender] = block.timestamp;
        isStaking[msg.sender] = true;
        emit Stake(msg.sender, amount);
    }

    function unstake(uint256 amount) public {
        require(
            isStaking[msg.sender] = true && stakingBalance[msg.sender] >= amount,
            "Insufficient amount of tokens to unstake"
        );
        uint256 yieldTransfer = calculateYieldTotal(msg.sender);

        startTime[msg.sender] = block.timestamp;
        uint256 balanceTransfer = amount;
        amount = 0;
        // checks-effects-transactions design pattern
        //// sets balanceTransfer to equal the amount and then sets
        //// the amount to 0 (Re-entracy attack prevention)
        stakingBalance[msg.sender] -= balanceTransfer;
        wethToken.transfer(msg.sender, balanceTransfer);
        tokenBalance[msg.sender] += yieldTransfer;
        yieldTransfer = 0;
        if (stakingBalance[msg.sender] == 0) {
            isStaking[msg.sender] = false;
        }
        emit Unstake(msg.sender, amount);
    }

    function withdrawYield() public {
        uint256 toTransfer = calculateYieldTotal(msg.sender);

        require(toTransfer > 0 || tokenBalance[msg.sender] > 0, "Yield insufficient to be withdrawn");
        //if tokenBalance > 0, userAddress staked WETH more than once

        if (tokenBalance[msg.sender] != 0) {
            uint256 oldBalance = tokenBalance[msg.sender];
            tokenBalance[msg.sender] = 0;
            toTransfer += oldBalance;
            // old tokenBalance gets added to yield total provided
            // by calculateYieldTotal and checks-effects-transactions
            // pattern used as token is assigned 0 (Re-entracy attack prevention)
        }

        startTime[msg.sender] = block.timestamp;
        token.mint(msg.sender, toTransfer);

        emit YieldWithdraw(msg.sender, toTransfer);
    }

    // auxiliary functions - time and yield automation
    function calculateYieldTime(address user) public view returns (uint256) {
        // visibility set to public due to testing and
        // so the frontend can fetch data
        uint256 end = block.timestamp;
        uint256 totalTime = end - startTime[user];
        return totalTime;
    }

    function calculateYieldTotal(address user) public view returns (uint256) {
        uint256 time = calculateYieldTime(user) * 10**18;
        //multiply by 10**18 to turn time timestamp difference into a BigNumber
        uint256 rate = 86400;
        //rate equals to 86400 since thats is the number of seconds in a day
        uint256 timeRate = time / rate;
        uint256 rawYield = (stakingBalance[user] * timeRate) / 10**18;
        //user receives 100% of staked value every 24 hours
        //frontend must divide by 10**18 again to display user yield
        return rawYield;
    }
}

//startTime is reset to block.timestamp each time any of the
// three main functions are called (stake, unstake, withdrawYield)

// In a more traditional yield farm, the rate is determined by the user’s percentage of the pool instead of time

// fixed interest rate of 100% of staked value per 24 hrs.