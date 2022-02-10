//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/utils/Context.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import './utils/Constants.sol';
import './interfaces/IStrategy.sol';

/**
 *
 * @title Zunami Protocol
 *
 * @notice Contract for Convex&Curve protocols optimize.
 * Users can use this contract for optimize yield and gas.
 *
 *
 * @dev Zunami is main contract.
 * Contract does not store user funds.
 * All user funds goes to Convex&Curve pools.
 *
 */

contract Zunami is Context, Ownable, ERC20 {
    using SafeERC20 for IERC20Metadata;

    struct PendingDeposit {
        uint256[3] amounts;
        address depositor;
    }

    struct PendingWithdrawal {
        uint256 lpAmount;
        uint256[3] minAmounts;
        address withdrawer;
    }

    struct PoolInfo {
        IStrategy strategy;
        uint256 startTime;
    }

    uint8 private constant POOL_ASSETS = 3;

    address[POOL_ASSETS] public tokens;
    uint256[POOL_ASSETS] public decimalsMultiplierS;
    mapping(address => uint256) public deposited;
    // Info of each pool
    PoolInfo[] public poolInfo;
    uint256 public totalDeposited;

    uint256 public constant FEE_DENOMINATOR = 1000;
    uint256 public managementFee = 10; // 1%
    bool public isLock = false;
    uint256 public constant MIN_LOCK_TIME = 1 days;

    mapping(address => uint256[3]) public accDepositPending;
    mapping(address => PendingWithdrawal) public pendingWithdrawals;

    event PendingDepositEvent(address depositor, uint256[3] amounts);
    event PendingWithdrawEvent(address withdrawer, uint256[3] amounts);
    event Deposited(address depositor, uint256[3] amounts, uint256 lpShares);
    event Withdrawn(address withdrawer, uint256[3] amounts, uint256 lpShares);
    event AddStrategy(address strategyAddr);
    event BadDeposit(address depositor, uint256[3] amounts, uint256 lpShares);
    event BadWithdraw(address withdrawer, uint256[3] amounts, uint256 lpShares);

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier isNotLocked() {
        require(!isLock, 'Zunami: Deposit functions locked');
        _;
    }

    modifier isStrategyStarted(uint256 pid) {
        require(block.timestamp >= poolInfo[pid].startTime, 'Zunami: strategy not started yet!');
        _;
    }

    constructor() ERC20('ZunamiLP', 'ZLP') {
        tokens[0] = Constants.DAI_ADDRESS;
        tokens[1] = Constants.USDC_ADDRESS;
        tokens[2] = Constants.USDT_ADDRESS;
        for (uint256 i; i < POOL_ASSETS; i++) {
            if (IERC20Metadata(tokens[i]).decimals() < 18) {
                decimalsMultiplierS[i] = 10**(18 - IERC20Metadata(tokens[i]).decimals());
            } else {
                decimalsMultiplierS[i] = 1;
            }
        }
    }

    /**
     * @dev update managementFee, this is a Zunami commission from protocol profit
     * @param  newManagementFee - minAmount 0, maxAmount FEE_DENOMINATOR - 1
     */

    function setManagementFee(uint256 newManagementFee) external onlyOwner {
        require(newManagementFee < FEE_DENOMINATOR, 'Zunami: wrong fee');
        managementFee = newManagementFee;
    }

    /**
     * @dev Returns managementFee for strategy's when contract sell rewards
     * @return Returns commission on the amount of profit in the transaction
     * @param amount - amount of profit for calculate managementFee
     */
    function calcManagementFee(uint256 amount) external view returns (uint256) {
        return (amount * managementFee) / FEE_DENOMINATOR;
    }

    /**
     * @dev Returns commission total holdings for all pools (strategy's)
     * @return Returns sum holdings (USD) for all pools
     */
    function totalHoldings() public view returns (uint256) {
        uint256 length = poolInfo.length;
        uint256 totalHold = 0;
        for (uint256 pid = 0; pid < length; pid++) {
            totalHold += poolInfo[pid].strategy.totalHoldings();
        }
        return totalHold;
    }

    /**
     * @dev Returns price depends on the income of users
     * @return Returns currently price of ZLP (1e18 = 1$)
     */
    function lpPrice() external view returns (uint256) {
        return (totalHoldings() * 1e18) / totalSupply();
    }

    /**
     * @dev Returns number (length of poolInfo)
     * @return Returns number (length of poolInfo)
     */
    function poolInfoLength() external view returns (uint256) {
        return poolInfo.length;
    }

    /**
     * @dev in this func user sends funds to the contract and then waits for the completion of the transaction for all users
     * @param amounts - array of deposit amounts by user
     */
    function delegateDeposit(uint256[3] memory amounts) external isNotLocked {
        for (uint256 i = 0; i < amounts.length; i++) {
            if (amounts[i] > 0) {
                IERC20Metadata(tokens[i]).safeTransferFrom(_msgSender(), address(this), amounts[i]);
                accDepositPending[_msgSender()][i] += amounts[i];
            }
        }

        emit PendingDepositEvent(_msgSender(), amounts);
    }

    /**
     * @dev in this func user sends pending withdraw to the contract and then waits for the completion of the transaction for all users
     * @param  lpAmount - amount of ZLP for withdraw
     * @param minAmounts - array of amounts stablecoins that user want minimum receive
     */
    function delegateWithdrawal(uint256 lpAmount, uint256[3] memory minAmounts) external {
        PendingWithdrawal memory user;
        address userAddr = _msgSender();

        user.lpAmount = lpAmount;
        user.minAmounts = minAmounts;
        user.withdrawer = userAddr;

        pendingWithdrawals[userAddr] = user;

        emit PendingWithdrawEvent(userAddr, minAmounts);
    }

    /**
     * @dev Zunami protocol owner complete all active pending deposits of users
     * @param userList - dev send array of users from pending to complete
     * @param pid - number of the pool to which the deposit goes
     */
    function completeDeposits(address[] memory userList, uint256 pid)
        external
        onlyOwner
        isStrategyStarted(pid)
    {
        IStrategy strategy = poolInfo[pid].strategy;
        uint256[3] memory totalAmounts;
        // total sum deposit, contract => strategy
        uint256 addHoldings = 0;
        uint256 completeAmount = 0;
        uint256 holdings = totalHoldings();
        uint256[] memory userCompleteHoldings = new uint256[](userList.length);

        for (uint256 i = 0; i < userList.length; i++) {
            completeAmount = 0;

            for (uint256 x = 0; x < totalAmounts.length; x++) {
                totalAmounts[x] += accDepositPending[userList[i]][x];
                completeAmount += accDepositPending[userList[i]][x] * decimalsMultiplierS[x];
            }
            userCompleteHoldings[i] = completeAmount;
        }

        for (uint256 y = 0; y < POOL_ASSETS; y++) {
            if (totalAmounts[y] > 0) {
                addHoldings += totalAmounts[y] * decimalsMultiplierS[y];
                IERC20Metadata(tokens[y]).safeTransfer(address(strategy), totalAmounts[y]);
            }
        }
        uint256 sum = strategy.deposit(totalAmounts);
        require(sum > 0, 'too low amount!');
        uint256 lpShares = 0;
        uint256 changedHoldings = 0;
        uint256 currentUserAmount = 0;
        address userAddr;

        for (uint256 z = 0; z < userList.length; z++) {
            currentUserAmount = (sum * userCompleteHoldings[z]) / addHoldings;
            userAddr = userList[z];
            deposited[userAddr] += currentUserAmount;
            changedHoldings += currentUserAmount;
            if (totalSupply() == 0) {
                lpShares = currentUserAmount;
            } else {
                lpShares =
                    (currentUserAmount * totalSupply()) /
                    (holdings + changedHoldings - currentUserAmount);
            }
            _mint(userAddr, lpShares);
            strategy.updateZunamiLpInStrat(lpShares, true);
            // remove deposit from list
            delete accDepositPending[userAddr];
        }
        totalDeposited += changedHoldings;
    }

    /**
     * @dev Zunami protocol owner complete all active pending withdrawals of users
     * @param userList - array of users from pending withdraw to complete
     * @param pid - number of the pool from which the funds are withdrawn
     */
    function completeWithdrawals(address[] memory userList, uint256 pid)
        external
        onlyOwner
        isStrategyStarted(pid)
    {
        require(userList.length > 0, 'there are no pending withdrawals requests');

        PendingWithdrawal memory user;
        IStrategy strategy = poolInfo[pid].strategy;

        for (uint256 i = 0; i < userList.length; i++) {
            user = pendingWithdrawals[userList[i]];
            uint256 balance = balanceOf(user.withdrawer);

            if (balance >= user.lpAmount && user.lpAmount > 0) {
                if (!(strategy.withdraw(user.withdrawer, user.lpAmount, user.minAmounts))) {
                    emit BadWithdraw(user.withdrawer, user.minAmounts, user.lpAmount);

                    return;
                }

                uint256 userDeposit = (totalDeposited * user.lpAmount) / totalSupply();
                _burn(user.withdrawer, user.lpAmount);
                strategy.updateZunamiLpInStrat(user.lpAmount, false);

                if (userDeposit > deposited[user.withdrawer]) {
                    userDeposit = deposited[user.withdrawer];
                }

                deposited[user.withdrawer] -= userDeposit;
                totalDeposited -= userDeposit;

                emit Withdrawn(user.withdrawer, user.minAmounts, user.lpAmount);
            }

            delete pendingWithdrawals[userList[i]];
        }
    }

    /**
     * @dev deposit in one tx, without waiting complete by dev
     * @return Returns amount of lpShares minted for user
     * @param amounts - user send amounts of stablecoins to deposit
     * @param pid - number of the pool to which the deposit goes
     */
    function deposit(uint256[3] memory amounts, uint256 pid)
        external
        isNotLocked
        isStrategyStarted(pid)
        returns (uint256)
    {
        IStrategy strategy = poolInfo[pid].strategy;
        uint256 holdings = totalHoldings();

        for (uint256 i = 0; i < amounts.length; i++) {
            if (amounts[i] > 0) {
                IERC20Metadata(tokens[i]).safeTransferFrom(
                    _msgSender(),
                    address(strategy),
                    amounts[i]
                );
            }
        }
        uint256 sum = strategy.deposit(amounts);
        require(sum > 0, 'too low amount!');

        uint256 lpShares = 0;
        if (totalSupply() == 0) {
            lpShares = sum;
        } else {
            lpShares = (sum * totalSupply()) / holdings;
        }
        _mint(_msgSender(), lpShares);
        strategy.updateZunamiLpInStrat(lpShares, true);
        deposited[_msgSender()] += sum;
        totalDeposited += sum;

        emit Deposited(_msgSender(), amounts, lpShares);
        return lpShares;
    }

    /**
     * @dev withdraw in one tx, without waiting complete by dev
     * @param lpShares - amount of ZLP for withdraw
     * @param minAmounts -  array of amounts stablecoins that user want minimum receive
     * @param pid - number of the pool from which the funds are withdrawn
     */
    function withdraw(
        uint256 lpShares,
        uint256[3] memory minAmounts,
        uint256 pid
    ) external isStrategyStarted(pid) {
        IStrategy strategy = poolInfo[pid].strategy;
        address userAddr = _msgSender();

        require(balanceOf(userAddr) >= lpShares, 'Zunami: not enough LP balance');
        require(
            strategy.withdraw(userAddr, lpShares, minAmounts),
            'user lps share should be at least required'
        );

        uint256 userDeposit = (totalDeposited * lpShares) / totalSupply();
        _burn(userAddr, lpShares);
        strategy.updateZunamiLpInStrat(lpShares, false);

        if (userDeposit > deposited[userAddr]) {
            userDeposit = deposited[userAddr];
        }

        deposited[userAddr] -= userDeposit;
        totalDeposited -= userDeposit;

        emit Withdrawn(userAddr, minAmounts, lpShares);
    }

    /**
     * @dev security func, dev can disable all new deposits (not withdrawals)
     * @param _lock - dev can lock or unlock deposits
     */

    function setLock(bool _lock) external onlyOwner {
        isLock = _lock;
    }

    /**
     * @dev dev withdraw commission from one strategy
     * @param strategyAddr - address from which strategy managementFees withdrawn
     */

    function claimManagementFees(address strategyAddr) external onlyOwner {
        IStrategy(strategyAddr).claimManagementFees();
    }

    /**
     * @dev add new strategy in strategy list, deposits in the new strategy are blocked for one day for safety
     * @param _strategy - add new address strategy in poolInfo Array
     */

    function add(address _strategy) external onlyOwner {
        poolInfo.push(
            PoolInfo({ strategy: IStrategy(_strategy), startTime: block.timestamp + MIN_LOCK_TIME })
        );
    }

    /**
     * @dev dev can transfer funds between strategy's for better APY
     * @param  _from - number strategy, from which funds are withdrawn
     * @param _to - number strategy, to which funds are deposited
     */
    function moveFunds(uint256 _from, uint256 _to) external onlyOwner {
        IStrategy fromStrat = poolInfo[_from].strategy;
        IStrategy toStrat = poolInfo[_to].strategy;
        uint256[3] memory amountsBefore;
        for (uint256 y = 0; y < POOL_ASSETS; y++) {
            amountsBefore[y] = IERC20Metadata(tokens[y]).balanceOf(address(this));
        }
        fromStrat.withdrawAll();
        uint256[3] memory amounts;
        for (uint256 i = 0; i < POOL_ASSETS; i++) {
            amounts[i] = IERC20Metadata(tokens[i]).balanceOf(address(this)) - amountsBefore[i];
            if (amounts[i] > 0) {
                IERC20Metadata(tokens[i]).safeTransfer(address(toStrat), amounts[i]);
            }
        }
        toStrat.deposit(amounts);
        uint256 transferLpAmount = fromStrat.getZunamiLpInStrat();
        fromStrat.updateZunamiLpInStrat(transferLpAmount, false);
        toStrat.updateZunamiLpInStrat(transferLpAmount, true);
    }

    /**
     * @dev dev can transfer funds from few strategy's to one strategy for better APY
     * @param _from - array of strategy's, from which funds are withdrawn
     * @param _to - number strategy, to which funds are deposited
     */
    function moveFundsBatch(uint256[] memory _from, uint256 _to) external onlyOwner {
        uint256 length = _from.length;
        uint256[3] memory amounts;
        uint256[3] memory amountsBefore;
        uint256 zunamiLp = 0;
        for (uint256 y = 0; y < POOL_ASSETS; y++) {
            amountsBefore[y] = IERC20Metadata(tokens[y]).balanceOf(address(this));
        }
        for (uint256 i = 0; i < length; i++) {
            poolInfo[_from[i]].strategy.withdrawAll();
            uint256 thisPidLpAmount = poolInfo[_from[i]].strategy.getZunamiLpInStrat();
            zunamiLp += thisPidLpAmount;
            poolInfo[_from[i]].strategy.updateZunamiLpInStrat(thisPidLpAmount, false);
        }
        for (uint256 y = 0; y < POOL_ASSETS; y++) {
            amounts[y] = IERC20Metadata(tokens[y]).balanceOf(address(this)) - amountsBefore[y];
            if (amounts[y] > 0) {
                IERC20Metadata(tokens[y]).safeTransfer(address(poolInfo[_to].strategy), amounts[y]);
            }
        }
        poolInfo[_to].strategy.updateZunamiLpInStrat(zunamiLp, true);
        require(poolInfo[_to].strategy.deposit(amounts) > 0, 'too low amount!');
    }

    /**
     * @dev dev can emergency transfer funds from all strategy's to zero pool (strategy)
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 length = poolInfo.length;
        require(length > 1, 'Zunami: Nothing withdraw');
        uint256[3] memory amounts;
        uint256[3] memory amountsBefore;
        uint256 zunamiLp = 0;
        for (uint256 y = 0; y < POOL_ASSETS; y++) {
            amountsBefore[y] = IERC20Metadata(tokens[y]).balanceOf(address(this));
        }
        for (uint256 i = 1; i < length; i++) {
            poolInfo[i].strategy.withdrawAll();
            uint256 thisPidLpAmount = poolInfo[i].strategy.getZunamiLpInStrat();
            zunamiLp += thisPidLpAmount;
            poolInfo[i].strategy.updateZunamiLpInStrat(thisPidLpAmount, false);
        }
        for (uint256 y = 0; y < POOL_ASSETS; y++) {
            amounts[y] = IERC20Metadata(tokens[y]).balanceOf(address(this)) - amountsBefore[y];
            if (amounts[y] > 0) {
                IERC20Metadata(tokens[y]).safeTransfer(address(poolInfo[0].strategy), amounts[y]);
            }
        }
        poolInfo[0].strategy.updateZunamiLpInStrat(zunamiLp, true);
        require(poolInfo[0].strategy.deposit(amounts) > 0, 'too low amount!');
    }

    /**
     * @dev user remove his active pending deposit
     */
    function pendingDepositRemove() external {
        for (uint256 i = 0; i < POOL_ASSETS; i++) {
            if (accDepositPending[_msgSender()][i] > 0) {
                IERC20Metadata(tokens[i]).safeTransfer(
                    _msgSender(),
                    accDepositPending[_msgSender()][i]
                );
            }
        }
        delete accDepositPending[_msgSender()];
    }

    /**
     * @dev disable renounceOwnership for safety
     */
    function renounceOwnership() public view override onlyOwner {
        revert('Zunami must have an owner');
    }
}