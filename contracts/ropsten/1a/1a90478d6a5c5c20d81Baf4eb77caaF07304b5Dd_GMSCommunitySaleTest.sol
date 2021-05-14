// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./libraries/SafeERC20.sol";

/// @title TokensSale
/// @dev A token sale contract that accepts only desired USD stable coins as a payment. Blocks any direct ETH deposits.
contract GMSCommunitySaleTest {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    // token sale limits per account in USD with 2 decimals (cents)
    uint256 public minPerAccount;
    uint256 public maxPerAccount;

    // cap in USD for token sale with 2 decimals (cents)
    uint256 public cap;

    // timestamp and duration are expressed in UNIX time, the same units as block.timestamp
    uint256 public startTime;
    uint256 public duration;

    // used to prevent gas usage when sale is ended
    bool private _ended;

    // account balance in USD with 2 decimals (cents)
    mapping(address => uint256) public balances;

    // account token balance
    mapping(address => uint256) public tokens;

    // collected stable coins balances
    mapping(address => uint256) private _deposited;

    // collected amound in USD with 2 decimals (cents)
    uint256 public collected;

    // whitelist
    mapping(address => bool) public whitelisted;
    bool public whitelistedOnly = true;

    // list of supprted stable coins
    EnumerableSet.AddressSet private stableCoins;

    // owner address
    address public owner;
    address public newOwner;

    // blocks ETH direct deposits by default
    bool private allowETH = false;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event WhitelistChanged(bool newEnabled);
    event Purchased(address indexed purchaser, uint256 amount);

    /// @dev creates a token sale contract that accepts only USD stable coins
    /// @param _owner address of the owner
    /// @param _minPerAccount min limit in USD cents that account needs to spend
    /// @param _maxPerAccount max allocation in USD cents per account
    /// @param _cap sale limit amount in USD cents
    /// @param _startTime the time (as Unix time) of sale start
    /// @param _duration duration in seconds of token sale
    /// @param _stableCoinsAddresses array of ERC20 token addresses of stable coins accepted in the sale
    constructor(
        address _owner,
        uint256 _minPerAccount,
        uint256 _maxPerAccount,
        uint256 _cap,
        uint256 _startTime,
        uint256 _duration,
        address[] memory _stableCoinsAddresses
    ) {
        require(_owner != address(0), "GMSCommunitySaleTest: Owner is a zero address");
        require(_cap > 0, "GMSCommunitySaleTest: Cap is 0");
        require(_duration > 0, "GMSCommunitySaleTest: Duration is 0");
        require(_startTime + _duration > block.timestamp, "GMSCommunitySaleTest: Final time is before current time");

        owner = _owner;
        minPerAccount = _minPerAccount;
        maxPerAccount = _maxPerAccount;
        cap = _cap;
        startTime = _startTime;
        duration = _duration;

        for (uint256 i = 0; i < _stableCoinsAddresses.length; i++) {
            stableCoins.add(_stableCoinsAddresses[i]);
        }

        emit OwnershipTransferred(address(0), msg.sender);
    }

    // -----------------------------------------------------------------------
    // GETTERS
    // -----------------------------------------------------------------------

    /// @return the end time of the sale
    function endTime() external view returns (uint256) {
        return startTime + duration;
    }

    /// @return the balance of the account in USD cents
    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }

     /// @return the max allocation for account
    function maxAllocationOf(address account) external view returns (uint256) {
        if (!whitelistedOnly || whitelisted[account]) {
            return maxPerAccount;
        } else {
            return 0;
        }
    }

    /// @return the amount in USD cents of remaining allocation
    function remainingAllocation(address account) external view returns (uint256) {
        if (!whitelistedOnly || whitelisted[account]) {
            if (maxPerAccount > 0) {
                return maxPerAccount - balances[account];
            } else {
                return cap - collected;
            }
        } else {
            return 0;
        }
    }

    /// @return the amount of tokens bought
    function tokensBought(address account) external view returns (uint256) {
        return tokens[account];
    }

    /// @return the price of the token
    function tokenPrice() external pure returns (uint256) {
        return 1;
    }

    /// @return information if account is whitelisted
    function isWhitelisted(address account) external view returns (bool) {
        if (whitelistedOnly) {
            return whitelisted[account];
        } else {
            return true;
        }
    }

    /// @return addresses with all stable coins supported in the sale
    function acceptableStableCoins() external view returns (address[] memory) {
        address[] memory addresses = new address[](stableCoins.length());
        
        for (uint256 i = 0; i < stableCoins.length(); i++) {
            addresses[i] = stableCoins.at(i);
        }

        return addresses;
    }

    /// @return info if sale is still ongoing
    function isLive() public view returns (bool) {
        return !_ended && block.timestamp > startTime && block.timestamp < startTime + duration;
    }

    // -----------------------------------------------------------------------
    // INTERNAL
    // -----------------------------------------------------------------------

    function _isBalanceSufficient(uint256 _amount) private view returns (bool) {
        return _amount + collected <= cap;
    }

    // -----------------------------------------------------------------------
    // MODIFIERS
    // -----------------------------------------------------------------------

    modifier onlyWhitelisted() {
        require(!whitelistedOnly || whitelisted[msg.sender], "GMSCommunitySaleTest: Account is not whitelisted");
        _;
    }

    modifier isOngoing() {
        require(isLive(), "GMSCommunitySaleTest: Sale is not active");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "GMSCommunitySaleTest: Only for contract Owner");
        _;
    }

    modifier isEnded() {
        require(_ended || block.timestamp > startTime + duration, "GMSCommunitySaleTest: Not ended");
        _;
    }

    // -----------------------------------------------------------------------
    // SETTERS
    // -----------------------------------------------------------------------

    /// @notice buy tokens using USD stable coins
    /// @dev use approve/transferFrom flow
    /// @param stableCoinAddress stable coin token address
    /// @param amount amount of USD cents
    function buyWith(address stableCoinAddress, uint256 amount) external isOngoing onlyWhitelisted {
        require(stableCoins.contains(stableCoinAddress), "GMSCommunitySaleTest: Stable coin not supported");
        require(amount > 0, "GMSCommunitySaleTest: Amount is 0");
        require(_isBalanceSufficient(amount), "GMSCommunitySaleTest: Insufficient remaining amount");
        require(amount + balances[msg.sender] >= minPerAccount, "GMSCommunitySaleTest: Amount too low");
        require(maxPerAccount == 0 || balances[msg.sender] + amount <= maxPerAccount, "GMSCommunitySaleTest: Amount too high");

        uint8 decimals = IERC20(stableCoinAddress).safeDecimals();
        uint256 stableCoinUnits = amount * (10**(decimals-2));

        // solhint-disable-next-line max-line-length
        require(IERC20(stableCoinAddress).allowance(msg.sender, address(this)) >= stableCoinUnits, "GMSCommunitySaleTest: Insufficient stable coin allowance");
        IERC20(stableCoinAddress).safeTransferFrom(msg.sender, stableCoinUnits);

        balances[msg.sender] += amount;
        collected += amount;
        _deposited[stableCoinAddress] += stableCoinUnits;

        emit Purchased(msg.sender, amount);
    }

    function endPresale() external onlyOwner {
        require(collected >= cap, "GMSCommunitySaleTest: Limit not reached");
        _ended = true;
    }

    function withdrawFunds() external onlyOwner isEnded {
        _ended = true;

        uint256 amount;

        for (uint256 i = 0; i < stableCoins.length(); i++) {
            address stableCoin = address(stableCoins.at(i));
            amount = IERC20(stableCoin).balanceOf(address(this));
            if (amount > 0) {
                IERC20(stableCoin).safeTransfer(owner, amount);
            }
        }

        amount = address(this).balance;
        if (amount > 0) {
            payable(owner).transfer(amount);
        }
    }

    function recoverErc20(address token) external onlyOwner {
        uint256 amount = IERC20(token).balanceOf(address(this));
        amount -= _deposited[token];
        if (amount > 0) {
            IERC20(token).safeTransfer(owner, amount);
        }
    }

    function recoverEth() external onlyOwner isEnded {
        payable(owner).transfer(address(this).balance);
    }

    function changeOwner(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "GMSCommunitySaleTest: New Owner is a zero address");
        newOwner = _newOwner;
    }

    function acceptOwnership() external {
        require(msg.sender == newOwner, "GMSCommunitySaleTest: Only new Owner");
        newOwner = address(0);
        emit OwnershipTransferred(owner, msg.sender);
        owner = msg.sender;
    }

    function setWhitelistedOnly(bool enabled) public onlyOwner {
        whitelistedOnly = enabled;
        emit WhitelistChanged(enabled);
    }

    function addWhitelistedAddresses(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            whitelisted[addresses[i]] = true;
        }
    }

    function setAllowETH(bool enabled) public onlyOwner {
        allowETH = enabled;
    }

    receive() external payable {
        require(allowETH, "GMSCommunitySaleTest: Revert on all ETH transfers");
    }
}