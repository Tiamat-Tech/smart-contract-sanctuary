// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./libraries/SafeERC20.sol";

/// @title TokensSale
/// @dev A token sale contract that is used to create a sale for not yet minted token
/// that accepts only desired USD stable coins as a payment. Blocks any direct ETH deposits.
contract TokenSale {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    // token sale limits per user in USD
    uint256 public minPerUser;
    uint256 public maxPerUser;

    // cap in USD for token sale
    uint256 public cap;

    // timestamp and duration are expressed in UNIX time, the same units as block.timestamp
    uint256 public startTime;
    uint256 public duration;

    // used to prevent gas usage when sale is ended
    bool private _ended;

    // users balances in USD
    mapping(address => uint256) public balances;

    // collected stable coins balances
    mapping(address => uint256) private _deposited;
    // collected amound in USD
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
    /// @param _minPerUser min abount in USD that user can buy
    /// @param _maxPerUser max abount in USD that user can buy
    /// @param _cap amount that sale plans to raise
    /// @param _startTime the time (as Unix time) at which point sale starts
    /// @param _duration duration in miliseconds of token sale
    /// @param _stableCoinsAddresses array of ERC20 token addresses of stable coins accepted in the sale
    constructor(
        address _owner,
        uint256 _minPerUser,
        uint256 _maxPerUser,
        uint256 _cap,
        uint256 _startTime,
        uint256 _duration,
        address[] memory _stableCoinsAddresses
    ) {
        require(_owner != address(0), "TokenSale: Owner is a zero address");
        require(_cap > 0, "TokenSale: Cap is 0");
        require(_duration > 0, "TokenSale: Duration is 0");
        require(_startTime + _duration > block.timestamp, "TokenSale: Final time is before current time");

        owner = _owner;
        minPerUser = _minPerUser;
        maxPerUser = _maxPerUser;
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

    /// @return the amount in USD of remaining allocation
    function allocationRemaining(address user) external view returns (uint256) {
        return maxPerUser - balances[user];
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
        require(!whitelistedOnly || whitelisted[msg.sender], "TokenSale: User is not whitelisted");
        _;
    }

    modifier isOngoing() {
        require(isLive(), "TokenSale: Sale is not active");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "TokenSale: Only for contract Owner");
        _;
    }

    modifier isEnded() {
        require(_ended || block.timestamp > startTime + duration, "TokenSale: Not ended");
        _;
    }

    // -----------------------------------------------------------------------
    // SETTERS
    // -----------------------------------------------------------------------

    /// @notice buy tokens using stable coins
    /// @dev use approve/transferFrom flow
    /// @param stableCoinAddress stable coin token address
    /// @param amount number of USD
    function buyWith(address stableCoinAddress, uint256 amount) external isOngoing onlyWhitelisted {
        require(stableCoins.contains(stableCoinAddress), "TokenSale: Stable coin not supported");
        require(amount > 0, "TokenSale: Amount is 0");
        require(_isBalanceSufficient(amount), "TokenSale: Insufficient remaining amount");
        require(amount + balances[msg.sender] >= minPerUser, "TokenSale: Amount too low");
        require(balances[msg.sender] + amount <= maxPerUser, "TokenSale: Amount too high");

        uint8 decimals = IERC20(stableCoinAddress).safeDecimals();
        uint256 stableCoinUnits = amount * (10**decimals);

        // solhint-disable-next-line max-line-length
        require(IERC20(stableCoinAddress).allowance(msg.sender, address(this)) >= stableCoinUnits, "TokenSale: Insufficient stable coin allowance");
        IERC20(stableCoinAddress).safeTransferFrom(msg.sender, stableCoinUnits);

        balances[msg.sender] += amount;
        collected += amount;
        _deposited[stableCoinAddress] += stableCoinUnits;

        emit Purchased(msg.sender, amount);
    }

    function endPresale() external onlyOwner {
        require(collected >= cap, "TokenSale: Limit not reached");
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
        require(_newOwner != address(0), "TokenSale: New Owner is a zero address");
        newOwner = _newOwner;
    }

    function acceptOwnership() external {
        require(msg.sender == newOwner, "TokenSale: Only new Owner");
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
        require(allowETH, "TokenSale: Revert on all ETH transfers");
    }
}