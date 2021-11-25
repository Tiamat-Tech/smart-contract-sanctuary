// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.2;

import "./TokenA.sol";
import "./TokenB.sol";
import "./TokenDjango.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Contract for usage of the django app
/// @author Giuseppe Trieste
/// @notice Allows a user to use the django application (get tokens, swap, deposit ...)
/// @dev Pausable and Ownable are there in case of data migration to another contract
contract DjangoApp is ReentrancyGuard, Pausable, Ownable {

    /// @notice DJG tokens as reward per block minted, every 100 TKB deposited
    /// @dev This amount does consider decimals
    uint public REWARD_PER_BLOCK = 1 * (10 ** 18);

    /// @notice Amount of TKA given from the faucet
    /// @dev This amount does consider decimals
    uint public FAUCET_AMOUNT = 100 * (10 ** 18);

    /// @notice TKA token, the one given by using the faucet
    TokenA public tokenA;

    /// @notice TKB token, the one used for depositing and earn rewards
    TokenB public tokenB;

    /// @notice DJG token, the one used rewarding the user for depositing TKB
    TokenDjango public tokenDjango;

    /// @dev Last time that an address used the faucet, the time is in seconds since the epoch
    mapping(address => uint256) private lastTimeFaucet;

    /// @dev Amount of TKB tokens deposited by an address;
    /// The tokens deposited are held by the smart contract
    mapping(address => uint256) private depositedTokenBalances;

    /// @dev DJG tokens earned (not withdrawn yet) by an address
    mapping(address => uint256) private earnedDjangoBalances;

    /// @dev Last block that reward amount was updated
    mapping(address => uint256) private lastBlockUpdate;

    /// @notice Emitted when someone successfully uses the faucet
    /// @param from The address that used it
    /// @param timestamp The block timestamp of the successful transaction
    event FaucetUsed(address indexed from, uint timestamp);

    /// @notice Emitted when someone successfully deposits TKB in the contract
    /// @param from The address that deposited the tokens
    /// @param amount The amount of TKB deposited
    event Deposit(address indexed from, uint amount);

    /// @notice Emitted when someone successfully withdraws TKB from the contract
    /// @param from The address that has withdrawn the tokens
    /// @param amount The amount of TKB withdrawn
    event Withdraw(address indexed from, uint amount);

    /// @notice Emitted when someone successfully claims DJG
    /// @param from The address that has claimed the tokens
    /// @param amount The amount of DJG claimed
    event Claim(address indexed from, uint amount);

    /// @dev The three tokens contract addresses are passed as params at the time of deployment
    /// @param _tokenA The TKA token contract address
    /// @param _tokenB The TKB token contract address
    /// @param _tokenDjango The DJG token contract address
    constructor(address _tokenA, address _tokenB, address _tokenDjango) {
        tokenA = TokenA(_tokenA);
        tokenB = TokenB(_tokenB);
        tokenDjango = TokenDjango(_tokenDjango);
    }

    /// @dev Pauses the contract, so all the (non-view) functions will be unusable
    function pause() public onlyOwner {
        _pause();
    }

    /// @dev Upauses the contract
    function unpause() public onlyOwner {
        _unpause();
    }

    /// @dev Getter function for lastTimeFaucet mapping
    /// @param account_ The address of the user
    /// @return Time in seconds since epoch of last time the user used the faucet
    function lastTimeUsedFaucet(address account_) external view returns (uint) {
        return lastTimeFaucet[account_];
    }

    /// @notice Mints faucet tokens (TKA) to the requester (msg.sender) if it's not in cooldown (24 hours)
    /// @dev TKA is an openzeppelin ERC20Capped, so after its limit has been reached, the faucet won't give 
    /// tokens anymore; The function uses block.timestamp for the time difference
    function useFaucet() external whenNotPaused {
        require(block.timestamp >= lastTimeFaucet[msg.sender] + (24 * 60 * 60), "Faucet in cooldown");
        
        lastTimeFaucet[msg.sender] = block.timestamp;
        
        tokenA.mint(msg.sender, FAUCET_AMOUNT);

        emit FaucetUsed(msg.sender, block.timestamp);
    }

    /// @notice Swaps TKA for TKB, ratio 1:1
    /// @dev The TKB tokens are minted directly to the requester
    /// @param amountTokenA_ Amount of TKA to be swapped
    function swapFaucetTokensForDepositTokens(uint amountTokenA_) external nonReentrant whenNotPaused {
        tokenA.transferFrom(msg.sender, address(this), amountTokenA_);
        tokenB.mint(msg.sender, amountTokenA_);
    }

    /// @notice Swaps TKB for TKA, ratio 1:1
    /// @dev The TKB tokens are burned directly from the requester
    /// @param amountTokenB_ Amount of TKB to be swapped
    function swapDepositTokensForFaucetTokens(uint amountTokenB_) external nonReentrant whenNotPaused {
        tokenB.burnFrom(msg.sender, amountTokenB_);
        tokenA.transfer(msg.sender, amountTokenB_);
    }

    /// @dev Getter function for depositedTokenBalances mapping
    /// @param account_ The address of the user
    /// @return Amount of TKB deposited by an user
    function depositedTokens(address account_) external view returns (uint) {
        return depositedTokenBalances[account_];
    }

    /// @dev Calculates the DJG earned since last block update (doesn't consider the ones before that, stored in earnedDjangoBalances)
    /// @param account_ The address of the user
    /// @return Partial amount of DJG earned from the user until now
    function calculateDjangoEarned(address account_) internal view returns (uint) {
        uint deposited = depositedTokenBalances[account_];
        uint lastBlock = lastBlockUpdate[account_];

        return ((block.number - lastBlock ) * deposited * REWARD_PER_BLOCK) / (FAUCET_AMOUNT);
    }

    /// @notice This is the total amount of DJG the user has earned until now
    /// @dev It considers both the ones earned since last update and those already stored in earnedDjangoBalances
    /// @param account_ The address of the user
    /// @return Total amount of DJG earned from the user until now
    function getDjangoEarned(address account_) external view returns (uint) {
        return earnedDjangoBalances[account_] + calculateDjangoEarned(account_);
    }

    /// @dev DJG are earned for each block, but the earned balance is updated every time that user makes a transaction 
    /// depositing, withdrawing or claiming. The lastBlockUpdate is also updated in these three types of transactions
    /// @param account_ The address of the user
    /// @param amount_ New amount of DJG earned
    function updateDjangoEarned(address account_, uint amount_) internal {
        earnedDjangoBalances[account_] = amount_;
        lastBlockUpdate[account_] = block.number;
    }

    /// @notice The user deposits TKB in the contract
    /// @dev The contracts knows who and how much each user deposited thanks to depositedTokenBalances. The basic checks (enough amount 
    ///of tokens, enough allowance) are already done by the ERC20 functions
    /// @param amount_ Amount of TKB to deposit
    function deposit(uint amount_) external whenNotPaused {
        tokenB.transferFrom(msg.sender, address(this), amount_);

        updateDjangoEarned(msg.sender, this.getDjangoEarned(msg.sender));
        depositedTokenBalances[msg.sender] += amount_;

        emit Deposit(msg.sender, amount_);
    }

    /// @notice The user withdraws TKB from the contract
    /// @dev Only checks that user deposited enough amount, the others are already done by the ERC20 functions
    /// @param amount_ Amount of TKB to withdraw
    function withdraw(uint amount_) external whenNotPaused {
        require(depositedTokenBalances[msg.sender] >= amount_, "Not enough deposited tokens");

        updateDjangoEarned(msg.sender, this.getDjangoEarned(msg.sender));
        depositedTokenBalances[msg.sender] -= amount_;

        tokenB.transfer(msg.sender, amount_);

        emit Withdraw(msg.sender, amount_);
    }

    /// @notice The user claims all the DJG earned until now (if any)
    /// @dev The DJG are minted directly to the user
    function claim() external whenNotPaused {
        uint djangoEarned = this.getDjangoEarned(msg.sender);
        require(djangoEarned > 0, "No DJG to claim");

        updateDjangoEarned(msg.sender, 0);

        tokenDjango.mint(msg.sender, djangoEarned);

        emit Claim(msg.sender, djangoEarned);
    }
}