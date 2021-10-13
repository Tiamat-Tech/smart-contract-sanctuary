// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

contract DFYNWorldCup is Initializable, OwnableUpgradeable, ERC1155SupplyUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public token;
    address public treasury;
    uint256 public treasuryRate;
    uint256 public winnerRate;
    uint256 public runnerUpRate;
    uint256 public BASE_PRICE; // solhint-disable-line var-name-mixedcase
    uint256 public endTime;
    uint256 public winner;
    uint256 public runnerUp;
    uint256 public totalTeams;
    bool public treasuryClaimed;

    uint256 public rewardPoolLocked;
    uint256 public winnerTotalLocked;
    uint256 public runnerUpTotalLocked;

    event WinnerDeclared(uint256 winner);
    event RunnerUpDeclared(uint256 runnerUp);
    event Buy(uint256 _id, uint256 amount, address indexed buyer);
    event ClaimReward(address indexed user, uint256 amount);
    event SetEndTime(uint256 endTime);
    event TotalTeamsChanged(uint256 totalTeams);
    event TreasuryClaimed(uint256 amountWithdrawn);
    event EmergencyWithdraw(uint256 amountWithdrawn);

    /// @dev Initialize contract (constructor)
    /// @param _uri NFT uri
    /// @param _basePrice fixed price for each NFT
    /// @param _tokenAddr address of the stablecoin
    /// @param _treasury treasury/fees wallet for burn
    /// @param _treasuryRate % of rewardPool to use for burn ( < 100)
    /// @param _winnerRate % of rewardPool to reward winner ( < 100)
    /// @param _runnerUpRate % of rewardPool to reward runnerup  ( < 100)
    /// @param _endTime sale end time
    /// @param _totalTeams total number of teams
    function initialize(
        string calldata _uri,
        uint256 _basePrice,
        IERC20Upgradeable _tokenAddr,
        address _treasury,
        uint256 _treasuryRate,
        uint256 _winnerRate,
        uint256 _runnerUpRate,
        uint256 _endTime,
        uint256 _totalTeams
    ) external initializer {
        __Ownable_init();
        __ERC1155_init(_uri);
        __ERC1155Supply_init();

        require(address(_tokenAddr) != address(0), "Invalid Stablecoin address");
        require(address(_treasury) != address(0), "Invalid Treasury address");
        require(_endTime > block.timestamp, "Invalid Value for timestamp");
        require(_winnerRate + _runnerUpRate + _treasuryRate == 100, "Reward total should be 100");

        BASE_PRICE = _basePrice;
        token = _tokenAddr;
        treasury = _treasury;
        treasuryRate = _treasuryRate;
        winnerRate = _winnerRate;
        runnerUpRate = _runnerUpRate;
        endTime = _endTime;
        totalTeams = _totalTeams;
        winner = ~uint256(0);
        runnerUp = ~uint256(0);
    }

    /// @notice Buy the NFT at the fixed price by paying in Stablecoins
    /// @dev mint the token with the id = _id, after getting payment
    /// @param _id token id of the NFT
    function buy(uint256 _id, uint256 amount) external {
        require(block.timestamp < endTime, "Sale has ended");
        require(amount > 0, "amount > 0");
        require(_id < totalTeams, "Invalid team id");
        token.safeTransferFrom(_msgSender(), address(this), BASE_PRICE * amount);
        _mint(_msgSender(), _id, amount, "0x0");

        emit Buy(_id, amount, _msgSender());
    }

    /// @dev Adds new teams, increase the value of totalTeams variable (onlyOwner)
    /// @param newTeams number of teams to add to the total
    function addTeams(uint256 newTeams) external onlyOwner {
        require(winner == ~uint256(0), "Winner has already been declared");
        require(runnerUp == ~uint256(0), "Runner Up has already been declared");
        totalTeams += newTeams;
        emit TotalTeamsChanged(totalTeams);
    }

    /// @dev Set the winner and runnerUp (only Owner)
    /// @param _idWinner id of the token to be set as the winner
    /// @param _idRunnerUp id of the token to be set as the runnerUp
    function setWinners(uint256 _idWinner, uint256 _idRunnerUp) external onlyOwner {
        require(block.timestamp >= endTime, "Not allowed");
        require(_idWinner < totalTeams && _idRunnerUp < totalTeams, "Invalid team id");
        require(_idWinner != _idRunnerUp, "winner != runnerUp");
        winner = _idWinner;
        runnerUp = _idRunnerUp;

        if(rewardPoolLocked == 0)
            rewardPoolLocked = token.balanceOf(address(this));

        winnerTotalLocked = totalSupply(winner);
        runnerUpTotalLocked = totalSupply(runnerUp);
        emit WinnerDeclared(winner);
        emit RunnerUpDeclared(runnerUp);
    }

    /// @dev Set the sale end time (only Owner)
    /// @param _endTime the block.timestamp for the time to end the sale
    function setEndTime(uint256 _endTime) external onlyOwner {
        require(winner == ~uint256(0), "Winner has been declared");
        require(block.timestamp < _endTime, "Time passed");
        endTime = _endTime;
        emit SetEndTime(endTime);
    }

    /// @dev Calculates and transfers the rewards (NFT will be burnt)
    function claimRewardAll() external {
        uint256 userPoolShare = claimableAll();

        if(userPoolShare > 0) {
            if(winner != ~uint256(0) && balanceOf(_msgSender(), winner) > 0) {
                _mint(_msgSender(), totalTeams, balanceOf(_msgSender(), winner), "0x0");
                //Burn NFT token so that user can't claim again
                _burn(_msgSender(), winner, balanceOf(_msgSender(), winner));
            }
            if(runnerUp != ~uint256(0) && balanceOf(_msgSender(), runnerUp) > 0) {
                _mint(_msgSender(), totalTeams + 1, balanceOf(_msgSender(), runnerUp), "0x0");
                //Burn NFT token so that user can't claim again
                _burn(_msgSender(), runnerUp, balanceOf(_msgSender(), runnerUp));
            }
            //Transfer ERC20 to the user
            token.safeTransfer(_msgSender(), userPoolShare);

            emit ClaimReward(_msgSender(), userPoolShare);
        }
    }

    /// @dev Calculates and transfers the rewards (NFT will be burnt)
    function claimRewardExact(uint256 _id, uint256 _tokenAmount) external {
        uint256 userPoolShare = claimableExact(_id, _tokenAmount);
        if(userPoolShare > 0) {
            //Mint Winner/Runner Up NFTs
            if(_id == winner)
                _mint(_msgSender(), totalTeams, _tokenAmount, "0x0");
            else
                _mint(_msgSender(), totalTeams + 1, _tokenAmount, "0x0");

             //Burn NFT token so that user can't claim again
            _burn(_msgSender(), _id, _tokenAmount);

            //Transfer ERC20 to the user
            token.safeTransfer(_msgSender(), userPoolShare);
            emit ClaimReward(_msgSender(), userPoolShare);
        }
    }

    /// @dev calculates the claim of the user
    /// @return claim claimable amount
    function claimableAll() public view returns (uint256 claim) {
        if(winnerTotalLocked == 0) claim += 0;
        else if(winner == ~uint256(0))
            claim += 0;
        else
            claim += (balanceOf(_msgSender(), winner) * (rewardPoolLocked * winnerRate / 100)) / winnerTotalLocked;

        if(runnerUpTotalLocked == 0) claim +=0;
        else if(runnerUp == ~uint256(0))
            claim += 0;
        else
            claim += (balanceOf(_msgSender(), runnerUp) *
                     (rewardPoolLocked * runnerUpRate / 100)) /
                     runnerUpTotalLocked;
    }

    /// @dev calculates the claim of the user
    /// @return claim claimable amount for the id and the number of tokens
    function claimableExact(uint256 _id, uint256 _tokenAmount) public view returns (uint256 claim) {
        uint256 rate;
        uint256 totalLocked;
        if(_id == winner) {
            rate = winnerRate;
            totalLocked = winnerTotalLocked;
        }
        else if (_id == runnerUp) {
            rate = runnerUpRate;
            totalLocked = runnerUpTotalLocked;
        }
        else return 0;

        if(balanceOf(_msgSender(), _id) < _tokenAmount) return 0;
        if(totalLocked == 0) claim += 0;
        else if(_id == ~uint256(0))
            claim += 0;
        else
            claim += _tokenAmount * (rewardPoolLocked * rate / 100) / totalLocked;
    }

    /// @dev Function for admin to remove collected burn fee
    function withdrawTreasury() external onlyOwner {
        require(!treasuryClaimed, "Can't claim again");
        token.safeTransfer(treasury, rewardPoolLocked * treasuryRate / 100);
        treasuryClaimed = true;

        emit TreasuryClaimed(rewardPoolLocked * treasuryRate / 100);
    }

    /// @dev Emergency Withdraw (onlyOwner)
    function emergencyWithdraw() external onlyOwner {
        uint256 amount = token.balanceOf(address(this));
        token.safeTransfer(_msgSender(), amount);

        emit EmergencyWithdraw(amount);
    }
}