// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import '@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol';
import '@pancakeswap/pancake-swap-lib/contracts/utils/Address.sol';
import '@pancakeswap/pancake-swap-lib/contracts/GSN/Context.sol';
import '@pancakeswap/pancake-swap-lib/contracts/utils/EnumerableSet.sol';
import "./interfaces/ISmartLottery.sol";
import "./utils/AuthorizedList.sol";
import "./utils/LockableFunction.sol";
import "./utils/LPSwapSupport.sol";
import "./utils/UserInfoManager.sol";


contract SuperFuelSmartLottery is UserInfoManager, ISmartLottery, LPSwapSupport, LockableFunction, AuthorizedListExt {
    using EnumerableSet for EnumerableSet.AddressSet;

    RewardType public rewardType;
    IBEP20 public lotteryToken;
    IBEP20 public superFuelToken;
    uint256 private superFuelDecimals = 9;
    JackpotRequirements public eligibilityCriteria;
    RewardInfo private rewardTokenInfo;

    address[] public pastWinners;
    EnumerableSet.AddressSet private jackpotParticipants;
    uint256 private maxAttemptsToFindWinner = 10;

    uint256 private jackpot;
    uint256 public override draw = 1;

    uint256 private defaultDecimals = 10 ** 18;

    mapping(uint256 => WinnerLog) public winnersByRound;
    mapping(address => bool) public isExcludedFromJackpot;

    constructor(address superFuel, address _router, address _rewardsToken) AuthorizedListExt(true) public {
        pancakeRouter = IPancakeRouter02(_router);
        superFuelToken = IBEP20(payable(superFuel));

        if(_rewardsToken == address(0)){
            rewardType = RewardType.CURRENCY;
            rewardTokenInfo.name = "BNB";
            rewardTokenInfo.rewardAddress = address(0);
            rewardTokenInfo.decimals = defaultDecimals;
            jackpot = 12 * 10 ** 8 * rewardTokenInfo.decimals;
        } else {
            rewardType = RewardType.TOKEN;
            lotteryToken = IBEP20(payable(_rewardsToken));
            rewardTokenInfo.name = lotteryToken.name();
            rewardTokenInfo.rewardAddress = _rewardsToken;
            rewardTokenInfo.decimals = 10 ** uint256(lotteryToken.decimals());
        }

        jackpot = 12 * 10 ** 8 * rewardTokenInfo.decimals;

        eligibilityCriteria = JackpotRequirements({
            minSuperFuelBalance: 250000 * 10 ** 9,
            minDrawsSinceLastWin: 1,
            timeSinceLastTransfer: 48 hours
        });

        isExcludedFromJackpot[address(this)] = true;
        isExcludedFromJackpot[superFuel] = true;
        isExcludedFromJackpot[deadAddress] = true;

        _owner = superFuel;
    }

    receive() external payable{
        if(!inSwap)
            swap();
    }

    function deposit() external payable onlyOwner {
        if(!inSwap)
            swap();
    }

    function rewardCurrency() external view override returns(string memory){
        return rewardTokenInfo.name;
    }

    function swap() lockTheSwap internal {
        if(rewardType == RewardType.TOKEN) {
            uint256 contractBalance = address(this).balance;
            swapCurrencyForTokensAdv(address(lotteryToken), contractBalance, address(this));
        }
    }

    function setJackpotToCurrency() external virtual override onlyOwner{
        require(rewardType != RewardType.CURRENCY, "Rewards already set to reflect currency");
        require(!inSwap, "Contract engaged in swap, unable to change rewards");
        resetToCurrency();
    }

    function resetToCurrency() private lockTheSwap {
        uint256 contractBalance = lotteryToken.balanceOf(address(this));
        swapTokensForCurrencyAdv(address(lotteryToken), contractBalance, address(this));
        lotteryToken = IBEP20(0);

        rewardTokenInfo.name = "BNB";
        rewardTokenInfo.rewardAddress = address(0);
        rewardTokenInfo.decimals = defaultDecimals;

        rewardType = RewardType.CURRENCY;
    }

    function setJackpotToToken(address _tokenAddress) external virtual override authorized{
        require(rewardType != RewardType.TOKEN || _tokenAddress != address(lotteryToken), "Rewards already set to reflect this token");
        require(!inSwap, "Contract engaged in swap, unable to change rewards");
        resetToToken(_tokenAddress);
    }

    function resetToToken(address _tokenAddress) private lockTheSwap {
        uint256 contractBalance;
        if(rewardType == RewardType.TOKEN){
            contractBalance = lotteryToken.balanceOf(address(this));
            swapTokensForCurrencyAdv(address(lotteryToken), contractBalance, address(this));
        }
        contractBalance = address(this).balance;
        swapCurrencyForTokensAdv(_tokenAddress, contractBalance, address(this));

        lotteryToken = IBEP20(payable(_tokenAddress));

        rewardTokenInfo.name = lotteryToken.name();
        rewardTokenInfo.rewardAddress = _tokenAddress;
        rewardTokenInfo.decimals = 10 ** uint256(lotteryToken.decimals());

        rewardType = RewardType.TOKEN;
    }

    function lotteryBalance() public view returns(uint256 balance){
        balance =  _lotteryBalance();
        balance = balance.div(rewardTokenInfo.decimals);
    }

    function _lotteryBalance() internal view returns(uint256 balance){
        if(rewardType == RewardType.CURRENCY){
            balance =  address(this).balance;
        } else {
            balance = lotteryToken.balanceOf(address(this));
        }
    }

    function jackpotAmount() public override view returns(uint256 balance) {
        balance = jackpot;
        if(rewardTokenInfo.decimals > 0){
            balance = balance.div(rewardTokenInfo.decimals);
        }
    }

    function setJackpot(uint256 newJackpot) external override authorized {
        require(newJackpot > 0, "Jackpot must be set above 0");
        jackpot = newJackpot;
        if(rewardTokenInfo.decimals > 0){
            jackpot = jackpot.mul(rewardTokenInfo.decimals);
        }
        emit JackpotSet(rewardTokenInfo.name, newJackpot);
    }

    function checkAndPayJackpot() public override returns(bool){
        if(_lotteryBalance() >= jackpot && !locked){
            return _selectAndPayWinner();
        }
        return false;
    }

    function isJackpotReady() external view override returns(bool){
        return _lotteryBalance() >= jackpot;
    }

    function _selectAndPayWinner() private lockFunction returns(bool winnerFound){
        winnerFound = false;
        uint256 possibleWinner = pseudoRand();
        uint256 numParticipants = jackpotParticipants.length();

        uint256 maxAttempts = maxAttemptsToFindWinner >= numParticipants ? numParticipants : maxAttemptsToFindWinner;

        for(uint256 attempts = 0; attempts < maxAttempts; attempts++){
            possibleWinner = possibleWinner.add(attempts);
            if(possibleWinner >= numParticipants){
                possibleWinner = 0;
            }
            if(_isEligibleForJackpot(jackpotParticipants.at(possibleWinner))){
                reward(jackpotParticipants.at(possibleWinner));
                winnerFound = true;
                break;
            }
        }
    }

    function reward(address winner) private {
        if(rewardType == RewardType.CURRENCY){
            winner.call{value: jackpot}("");
        } else if(rewardType == RewardType.TOKEN){
            lotteryToken.transfer(winner, jackpot);
        }
        winnersByRound[draw] = WinnerLog({
            rewardName: rewardTokenInfo.name,
            winnerAddress: winner,
            drawNumber: draw,
            prizeWon: jackpot
        });

        hodlerInfo[winner].lastWin = draw;
        pastWinners.push(winner);

        emit JackpotWon(winner, rewardTokenInfo.name, jackpot, draw);
        ++draw;
    }

    function isEligibleForJackpot(address participant) external view returns(bool){
        if(!jackpotParticipants.contains(participant) || hodlerInfo[participant].tokenBalance < eligibilityCriteria.minSuperFuelBalance)
            return false;
        return _isEligibleForJackpot(participant);
    }

    function _isEligibleForJackpot(address participant) private view returns(bool){
        if(hodlerInfo[participant].lastTransfer < block.timestamp.sub(eligibilityCriteria.timeSinceLastTransfer)
                && (hodlerInfo[participant].lastWin == 0 || hodlerInfo[participant].lastWin < draw.sub(eligibilityCriteria.minDrawsSinceLastWin))){
            return true;
        }
        return false;
    }

    function pseudoRand() private view returns(uint256){
        uint256 nonce = draw.add(_lotteryBalance());
        uint256 modulo = jackpotParticipants.length();
        uint256 someValue = uint256(keccak256(abi.encodePacked(nonce, msg.sender, gasleft(), block.timestamp, draw, jackpotParticipants.at(0))));
        return someValue.mod(modulo);
    }

    function excludeFromJackpot(address user, bool shouldExclude) public override authorized {
        if(isExcludedFromJackpot[user] && !shouldExclude && hodlerInfo[user].tokenBalance >= eligibilityCriteria.minSuperFuelBalance)
            jackpotParticipants.add(user);
        if(!isExcludedFromJackpot[user] && shouldExclude)
            jackpotParticipants.remove(user);

        isExcludedFromJackpot[user] = shouldExclude;
    }

    function logTransfer(address payable from, uint256 fromBalance, address payable to, uint256 toBalance) public override(UserInfoManager, IUserInfoManager) onlyOwner {
        super.logTransfer(from, fromBalance, to, toBalance);

        if(!isExcludedFromJackpot[from]){
            if(fromBalance >= eligibilityCriteria.minSuperFuelBalance){
                jackpotParticipants.add(from);
            } else {
                jackpotParticipants.remove(from);
            }
        }

        if(!isExcludedFromJackpot[to]){
            if(toBalance >= eligibilityCriteria.minSuperFuelBalance){
                jackpotParticipants.add(to);
            } else {
                jackpotParticipants.remove(to);
            }
        }
    }

    function _approve(address, address, uint256) internal override {
        require(false);
    }

    function setMaxAttempts(uint256 attemptsToFindWinner) external override authorized {
        require(attemptsToFindWinner > 0 && attemptsToFindWinner != maxAttemptsToFindWinner, "Invalid or duplicate value");
        maxAttemptsToFindWinner = attemptsToFindWinner;
    }

    function setJackpotEligibilityCriteria(uint256 minSuperFuelBalance, uint256 minDrawsSinceWin, uint256 timeSinceLastTransferHours) external override authorized {
        JackpotRequirements memory newCriteria = JackpotRequirements({
            minSuperFuelBalance: minSuperFuelBalance * 10 ** superFuelDecimals,
            minDrawsSinceLastWin: minDrawsSinceWin,
            timeSinceLastTransfer: timeSinceLastTransferHours * 1 hours
        });
        emit JackpotCriteriaUpdated(minSuperFuelBalance, minDrawsSinceWin, timeSinceLastTransferHours);
        eligibilityCriteria = newCriteria;
    }

}