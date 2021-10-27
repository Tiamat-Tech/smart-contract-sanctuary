// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Vesting {
    using SafeMath for uint256;
    using SafeMath for uint16;

    modifier onlyOwner() {
        require(msg.sender == walletOwner, "not owner");
        _;
    }

    modifier onlyValidAddress(address _recipient) {
        require(
            _recipient != address(0) &&
                _recipient != address(this) &&
                _recipient != address(token),
            "not valid _recipient"
        );
        _;
    }

    modifier starTimeSettedUp() {
        require(startTime != 0, "start time not setted up yet");
        _;
    }

    modifier vestingReleased() {
        require(walletReleased, "the wallet is not released yet");
        _;
    }

    uint256 internal constant SECONDS_PER_DAY = 86400;

    struct Grant {
        uint256 amount;
        bool claimed;
        uint16 vestingCliff;
        address recipient;
    }

    event GrantAdded(address indexed recipient, uint256 indexed grantId);
    event GrantClaimed(address indexed recipient, uint256 indexed grantId);
    event GrantRemoved(address recipient, uint256 amount);
    event ChangedWalletOwner(address indexed newOwner);
    event VestingReleased();
    event StartTimeSetup();

    ERC20 public token;

    // map[grantId]Grant
    mapping(uint256 => Grant) public mapTokenGrants;
    // map[recipientAddress][]grantId
    mapping(address => uint256[]) private mapRecipientGrants;

    address public walletOwner;
    uint256 public currentVestingId;
    bool public walletReleased;
    uint256 public startTime;

    constructor(ERC20 _token) {
        require(address(_token) != address(0));
        walletOwner = msg.sender;
        token = _token;
        walletReleased = false;
        startTime = 0;
    }

    function releaseVesting() external onlyOwner {
        require(walletReleased == false, "wallet has released");
        walletReleased = true;
        emit VestingReleased();
    }

    function setStartTime() external onlyOwner {
        require(startTime == 0, "start time already setted up");
        startTime = currentTime();
        emit StartTimeSetup();
    }

    function addTokenGrant(
        address _recipient,
        uint256 _amount,
        uint16 _vestingCliffInDays
    ) external onlyOwner {
        require(_vestingCliffInDays <= 10 * 365, "more than 10 years");
        require(_recipient != address(0), "missing recipient address");

        // Transfer the grant tokens under the control of the vesting contract
        require(token.approve(address(this), _amount));
        
        require(
            token.transferFrom(walletOwner, address(this), _amount),
            "transfer failed"
        );

        Grant memory grant = Grant({
            amount: _amount,
            vestingCliff: _vestingCliffInDays,
            recipient: _recipient,
            claimed: false
        });
        mapTokenGrants[currentVestingId] = grant;
        mapRecipientGrants[_recipient].push(currentVestingId);
        emit GrantAdded(_recipient, currentVestingId);
        currentVestingId++;
    }

    function getGrantsByRecipient(address _recipient)
        public
        view
        returns (uint256[] memory)
    {
        return mapRecipientGrants[_recipient];
    }

    /// @notice Calculate the vested amount for `_grantId` to claim
    /// Returns 0 if cliff has not been reached
    function calculateGrantClaim(uint256 _grantId)
        public
        view
        returns (uint256)
    {
        Grant storage tokenGrant = mapTokenGrants[_grantId];

        // vesting token claimed
        if (tokenGrant.claimed) {
            return 0;
        }

        // return all token grant amount when start time not setted up
        if (startTime == 0) {
            return tokenGrant.amount;
        }

        // For grants created with a future start date, that hasn't been reached, return 0
        if (currentTime() < startTime) {
            return 0;
        }

        // Check cliff was reached
        uint256 elapsedTime = currentTime().sub(startTime);
        uint256 elapsedDays = elapsedTime.div(SECONDS_PER_DAY);

        if (elapsedDays < tokenGrant.vestingCliff) {
            return 0;
        }

        // If over vesting duration, all tokens vested

        return tokenGrant.amount;
    }

    /// @notice Allows a grant recipient to claim their vested tokens. Errors if no tokens have vested.
    /// Require wallet released to claim vested token.
    /// It is advised recipients check they are entitled to claim via `calculateGrantClaim` before calling this
    function claimVestedTokens(uint256 _grantId)
        external
        vestingReleased
        starTimeSettedUp
    {
        uint256 amountVested = calculateGrantClaim(_grantId);
        require(amountVested > 0, "amountVested is 0");

        Grant storage tokenGrant = mapTokenGrants[_grantId];
        tokenGrant.claimed = true;

        require(
            token.transfer(tokenGrant.recipient, amountVested),
            "no tokens"
        );
        emit GrantClaimed(tokenGrant.recipient, _grantId);
    }

    /// @notice Terminate token grant to the `_grantId`
    /// and returning all non-vested tokens to the Wallet Owner
    /// Secured to the Wallet Owner only
    /// @param _grantId grantId of the token grant recipient
    function removeTokenGrant(uint256 _grantId) external onlyOwner {
        Grant storage tokenGrant = mapTokenGrants[_grantId];
        address recipient = tokenGrant.recipient;
        uint256 amount = calculateGrantClaim(_grantId);

        require(token.transfer(walletOwner, amount));

        tokenGrant.amount = 0;
        tokenGrant.claimed = false;
        tokenGrant.vestingCliff = 0;
        tokenGrant.recipient = address(0);

        emit GrantRemoved(recipient, amount);
    }

    function currentTime() private view returns (uint256) {
        return block.timestamp;
    }

    function changeWalletOwner(address _newOwner)
        external
        onlyOwner
        onlyValidAddress(_newOwner)
    {
        walletOwner = _newOwner;
        emit ChangedWalletOwner(_newOwner);
    }
}