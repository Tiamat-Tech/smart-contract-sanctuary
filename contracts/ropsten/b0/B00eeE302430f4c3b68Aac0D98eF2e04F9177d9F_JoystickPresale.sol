// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "../utils/AuthorizableUpgradeable.sol";
import "../token/xJoyToken.sol";

contract JoystickPresale is ContextUpgradeable, AuthorizableUpgradeable {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    // Info of each coin like USDT, USDC
    struct CoinInfo {
        address addr;
        uint256 rate;
    }

    // Info of each Vesting
    struct VestingInfo {
        uint256 lockingDuration;         // Locking Duration
        uint256 vestingDuration;        // Vesting Duration
    }

    // Info of each Purchaser
    struct UserInfo {
        uint8   vestingIndex;           // Index of VestingInfo
        uint256 depositedAmount;        // How many Coins amount the user has deposited.
        uint256 purchasedAmount;        // How many JOY tokens the user has purchased.
        uint256 withdrawnAmount;        // Withdrawn amount
        uint256 lastWithdrawnTime;      // Last Withdrawn time  
    }

    // The JOY Token
    IERC20 public govToken;
    // The xJOY Token
    IERC20 public xGovToken;

    // treasury addresses
    address[] public treasuryAddrs;
    uint16 public treasuryIndex;

    // Coin Info list
    CoinInfo[] public coinList;
    uint8 public COIN_DECIMALS;

    // Vesting Info
    VestingInfo[] public vestingList;       // 0: For early investors, 1: For teams, 2: For advisors

    // Sale flag and time.
    bool public SALE_FLAG;
    uint256 public SALE_START;
    uint256 public SALE_DURATION;

    // User address => UserInfo
    mapping(address => UserInfo) public userList;
    address[] public userAddrs;

    // total tokens amounts (all 18 decimals)
    uint256 public totalSaleAmount;
    uint256 public totalCoinAmount;
    uint256 public totalSoldAmount;

    // Events.
    event TokensPurchased(address indexed purchaser, uint256 coinAmount, uint256 tokenAmount);
    event TokensWithdrawed(address indexed purchaser, uint256 tokenAmount);

    // Modifiers.
    modifier whenSale() {
        require(checkSalePeriod(), "This is not sale period.");
        _;
    }
    modifier whenVesting(address userAddr) {
        require(checkVestingPeriod(userAddr), "This is not vesting period.");
        _;
    }

    function initialize(
        IERC20 _govToken, 
        IERC20 _xGovToken, 
        uint256 _totalSaleAmount,
        CoinInfo[] memory _coinList,
        VestingInfo[] memory _vestingList
    ) public virtual initializer
    {
        __Context_init();
        __Authorizable_init();
        addAuthorized(_msgSender());

        govToken = _govToken;
        xGovToken = _xGovToken;
        
        treasuryAddrs.push(_msgSender());
        treasuryIndex = 0;

        COIN_DECIMALS = 18;
        setCoinList(_coinList);
        setVestingList(_vestingList);

        startSale(true);
        updateSaleDuration(60 days);

        updateTotalSaleAmount(_totalSaleAmount);
    }

    // Update token
    function updateTokens(IERC20 _govToken, IERC20 _xGovToken) public onlyAuthorized {
        govToken = _govToken;
        xGovToken = _xGovToken;
    }

    // update the treasury address
    function updateTreasuryAddrs(address[] memory _treasuryAddrs) public onlyAuthorized {
        delete treasuryAddrs;
        for (uint i=0; i<_treasuryAddrs.length; i++) {
            treasuryAddrs.push(_treasuryAddrs[i]);
        }
        treasuryIndex = 0;
    }
    function updateTreasuryIndex(uint16 _treasuryIndex) public onlyAuthorized {
        treasuryIndex = _treasuryIndex;
        if (treasuryAddrs.length > 0 && treasuryIndex >= treasuryAddrs.length) {
            treasuryIndex = 0;
        }
    }

    // Set coin list
    function setCoinList(CoinInfo[] memory _coinList) public onlyAuthorized {
        delete coinList;
        for (uint i=0; i<_coinList.length; i++) {
            coinList.push(_coinList[i]);
        }
    }

    // Update coin info
    function updateCoinInfo(uint8 index, address addr, uint256 rate) public onlyAuthorized {
        coinList[index] = CoinInfo(addr, rate);
    }

    // Set vesting list
    function setVestingList(VestingInfo[] memory _vestingList) public onlyAuthorized {
        delete vestingList;
        for (uint i=0; i<_vestingList.length; i++) {
            vestingList.push(_vestingList[i]);
        }
    }

    // Update vesting info
    function updateVestingInfo(uint8 index, uint256 addr, uint256 rate) public onlyAuthorized {
        vestingList[index] = VestingInfo(addr, rate);
    }

    // Get user's vesting info
    function getUserVestingInfo(address userAddr) public view returns (VestingInfo memory) {
        UserInfo memory userInfo = userList[userAddr];
        VestingInfo memory vestingInfo = vestingList[userInfo.vestingIndex];
        return vestingInfo;
    }

    // Start stop sale
    function startSale(bool bStart) public onlyAuthorized {
        SALE_FLAG = bStart;
        if (bStart) {
            SALE_START = block.timestamp;
        }
    }

    // Update sale duration
    function updateSaleDuration(uint256 saleDuration) public onlyAuthorized {
        SALE_DURATION = saleDuration;
    }

    // check sale period
    function checkSalePeriod() public view returns (bool) {
        return SALE_FLAG && block.timestamp >= SALE_START && block.timestamp <= SALE_START.add(SALE_DURATION);
    }

    // check locking period
    function checkLockingPeriod(address userAddr) public view returns (bool) {
        VestingInfo memory vestingInfo = getUserVestingInfo(userAddr);
        return block.timestamp >= SALE_START && block.timestamp <= SALE_START.add(vestingInfo.lockingDuration);
    }

    // check vesting period
    function checkVestingPeriod(address userAddr) public view returns (bool) {
        VestingInfo memory vestingInfo = getUserVestingInfo(userAddr);
        uint256 VESTING_START = SALE_START.add(vestingInfo.lockingDuration);
        return block.timestamp >=  VESTING_START;
    }

    // Update total sale amount
    function updateTotalSaleAmount(uint256 amount) public onlyAuthorized {
        totalSaleAmount = amount;
    }

    // Get user addrs
    function getUserAddrs() public view returns (address[] memory) {
        address[] memory returnData = new address[](userAddrs.length);
        for (uint i=0; i<userAddrs.length; i++) {
            returnData[i] = userAddrs[i];
        }
        return returnData;
    }
    
    // Get user infos
    function getUserList() public view returns (UserInfo[] memory returnData) {
        returnData = new UserInfo[](userAddrs.length);
        for (uint i=0; i<userAddrs.length; i++) {
            UserInfo memory userInfo = userList[userAddrs[i]];
            returnData[i] = userInfo;
        }
        return returnData;
    }

    // set User Info
    function setUserInfo(address addr, uint8 vestingIndex, uint256 depositedAmount, uint256 purchasedAmount, uint256 withdrawnAmount) public onlyAuthorized {
       UserInfo storage userInfo = userList[addr];
       if (userInfo.depositedAmount == 0) {
           userAddrs.push(addr);
       } else {
           totalCoinAmount = totalCoinAmount.sub(Math.min(totalCoinAmount, userInfo.depositedAmount));
           totalSoldAmount = totalSoldAmount.sub(Math.min(totalSoldAmount, userInfo.purchasedAmount));
       }
        totalCoinAmount = totalCoinAmount.add(depositedAmount);
        totalSoldAmount = totalSoldAmount.add(purchasedAmount);
        
        userInfo.vestingIndex = vestingIndex;
        userInfo.depositedAmount = depositedAmount;
        userInfo.purchasedAmount = purchasedAmount;
        userInfo.withdrawnAmount = withdrawnAmount;
    }


    // deposit
    // coinAmount (decimals: COIN_DECIMALS) 
    function deposit(uint256 _coinAmount, uint8 coinIndex) external whenSale {
        require( totalSaleAmount >= totalSoldAmount, "totalSaleAmount >= totalSoldAmount");

        CoinInfo memory coinInfo = coinList[coinIndex];
        IERC20Upgradeable coin = IERC20Upgradeable(coinInfo.addr);

        // calculate token amount to be transferred
        (uint256 tokenAmount, uint256 coinAmount) = calcTokenAmount(_coinAmount, coinIndex);
        uint256 availableTokenAmount = totalSaleAmount.sub(totalSoldAmount);

        // if the token amount is less than remaining
        if (availableTokenAmount < tokenAmount) {
            tokenAmount = availableTokenAmount;
            (_coinAmount, coinAmount) = calcCoinAmount(availableTokenAmount, coinIndex);
        }

        // validate purchasing
        _preValidatePurchase(_msgSender(), tokenAmount, coinAmount, coinIndex);

        // transfer coin and token
        coin.safeTransferFrom(_msgSender(), address(this), coinAmount);
        xGovToken.transfer(_msgSender(), tokenAmount);

        // transfer coin to treasury
        if (treasuryAddrs.length != 0) {
            coin.transfer(treasuryAddrs[treasuryIndex], coinAmount);
        }

        // update global state
        totalCoinAmount = totalCoinAmount.add(_coinAmount);
        totalSoldAmount = totalSoldAmount.add(tokenAmount);
        
       // update purchased token list
       UserInfo storage userInfo = userList[_msgSender()];
       if (userInfo.depositedAmount == 0) {
           userAddrs.push(_msgSender());
       }
       userInfo.vestingIndex = 0;
       userInfo.depositedAmount = userInfo.depositedAmount.add(_coinAmount);
       userInfo.purchasedAmount = userInfo.purchasedAmount.add(tokenAmount);
       
       emit TokensPurchased(_msgSender(), _coinAmount, tokenAmount);

       xJoyToken _xJoyToken = xJoyToken(address(xGovToken));
       _xJoyToken.addPurchaser(_msgSender(), tokenAmount);
    }

    // withdraw
    function withdraw() external whenVesting(_msgSender()) {
        uint256 withdrawalAmount = calcWithdrawalAmount(_msgSender());
        uint256 govTokenAmount = govToken.balanceOf(address(this));
        uint256 xGovTokenAmount = xGovToken.balanceOf(address(_msgSender()));
        uint256 withdrawAmount = Math.min(withdrawalAmount, Math.min(govTokenAmount, xGovTokenAmount));
       
        require(withdrawAmount > 0, "No withdraw amount!");
        require(xGovToken.allowance(_msgSender(), address(this)) >= withdrawAmount, "withdraw's allowance is low!");

        xGovToken.transferFrom(_msgSender(), address(this), withdrawAmount);
        govToken.transfer(_msgSender(), withdrawAmount);

        UserInfo storage userInfo = userList[_msgSender()];
        userInfo.withdrawnAmount = userInfo.withdrawnAmount.add(withdrawAmount);
        userInfo.lastWithdrawnTime = block.timestamp;

        emit TokensWithdrawed(_msgSender(), withdrawAmount);
    }

    // Calc token amount by coin amount
    function calcWithdrawalAmount(address userAddr) public view returns (uint256) {
        require(checkVestingPeriod(userAddr), "This is not vesting period.");

        VestingInfo memory vestingInfo = getUserVestingInfo(userAddr);
        uint256 VESTING_START = SALE_START.add(vestingInfo.lockingDuration);

        UserInfo memory userInfo = userList[userAddr];
        uint256 totalAmount = 0;
        if (block.timestamp >= VESTING_START.add(vestingInfo.vestingDuration)) {
            totalAmount = userInfo.purchasedAmount;
        } else {
            totalAmount = userInfo.purchasedAmount.mul(block.timestamp.sub(VESTING_START)).div(vestingInfo.vestingDuration);
        }

        uint256 withdrawalAmount = totalAmount.sub(userInfo.withdrawnAmount);
        return withdrawalAmount;
    }

    // Calc token amount by coin amount
    function calcTokenAmount(uint256 _coinAmount, uint8 coinIndex) public view returns (uint256, uint256) {
        require( coinList.length > coinIndex, "coinList.length > coinIndex");

        CoinInfo memory coinInfo = coinList[coinIndex];
        ERC20 coin = ERC20(coinInfo.addr);
        uint256 rate = coinInfo.rate;

        uint tokenDecimal =  ERC20(address(xGovToken)).decimals() + coin.decimals() - COIN_DECIMALS;
        uint256 tokenAmount = _coinAmount
        .mul(10**tokenDecimal)
        .div(rate);
        
        uint coinDecimal =  COIN_DECIMALS - coin.decimals();
        uint256 coinAmount = _coinAmount
        .div(10**coinDecimal);

        return (tokenAmount, coinAmount);
    }

    // Calc coin amount by token amount
    function calcCoinAmount(uint256 _tokenAmount, uint8 coinIndex) public view returns (uint256, uint256) {
        require( coinList.length > coinIndex, "coinList.length > coinIndex");

        CoinInfo memory coinInfo = coinList[coinIndex];
        ERC20 coin = ERC20(coinInfo.addr);
        uint256 rate = coinInfo.rate;

        uint _coinDecimal =  ERC20(address(xGovToken)).decimals() + coin.decimals() - COIN_DECIMALS;
        uint256 _coinAmount = _tokenAmount
        .div(10**_coinDecimal)
        .mul(rate);
        
        uint coinDecimal =  COIN_DECIMALS - coin.decimals();
        uint256 coinAmount = _coinAmount
        .div(10**coinDecimal);

        return (_coinAmount, coinAmount);
    }

    // Calc max coin amount to be deposit
    function calcMaxCoinAmountToBeDeposit(uint8 coinIndex) public view returns (uint256) {
        uint256 availableTokenAmount = totalSaleAmount.sub(totalSoldAmount);
        (uint256 _coinAmount,) = calcCoinAmount(availableTokenAmount, coinIndex);
        return _coinAmount;
    }

    // Validate purchase
    function _preValidatePurchase(address purchaser, uint256 tokenAmount, uint256 coinAmount, uint8 coinIndex) internal view {
        require( coinList.length > coinIndex, "coinList.length > coinIndex");
        CoinInfo memory coinInfo = coinList[coinIndex];
        IERC20 coin = IERC20(coinInfo.addr);

        require(purchaser != address(0), "Purchaser is the zero address");
        require(coinAmount != 0, "Coin amount is 0");
        require(tokenAmount != 0, "Token amount is 0");

        require(xGovToken.balanceOf(address(this)) >= tokenAmount, "$xJoyToken amount is lack!");
        require(coin.balanceOf(msg.sender) >= coinAmount, "Purchaser's coin amount is lack!");
        require(coin.allowance(msg.sender, address(this)) >= coinAmount, "Purchaser's allowance is low!");

        this;
    }

    /**
     * withdraw all coins by owner
     */
    function withdrawAllCoins(address treasury) public onlyOwner {
        for (uint i=0; i<coinList.length; i++) {
            CoinInfo memory coinInfo = coinList[i];
            IERC20Upgradeable _coin = IERC20Upgradeable(coinInfo.addr);
            uint256 coinAmount = _coin.balanceOf(address(this));
            _coin.safeTransfer(treasury, coinAmount);
        }
    }

    /**
     * withdraw all xJOY by owner
     */
    function withdrawAllxGovTokens(address treasury) public onlyOwner {
        uint256 tokenAmount = xGovToken.balanceOf(address(this));
        xGovToken.transfer(treasury, tokenAmount);
    }

    /**
     * withdraw all $JOY by owner
     */
    function withdrawAllGovTokens(address treasury) public onlyOwner {
        uint256 tokenAmount = govToken.balanceOf(address(this));
        govToken.transfer(treasury, tokenAmount);
    }
}