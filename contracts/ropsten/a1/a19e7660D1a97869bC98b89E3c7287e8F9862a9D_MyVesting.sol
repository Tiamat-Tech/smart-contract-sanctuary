// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

// File: openzeppelin-solidity/contracts/ownership/Ownable.sol

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";
// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/utils/SafeERC20.sol";

// File: contracts/MaticTokenVesting.sol

/**
 * @title TokenVesting
 * @dev A token holder contract that can release its token balance gradually like a
 * typical vesting scheme, with a cliff and vesting period. Optionally revocable by the
 * owner.
 */
contract MyVesting is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 private maticToken;
    uint256 private tokensToVest = 0;
    uint256 private vestingId = 0;

    string private constant INSUFFICIENT_BALANCE = "Insufficient balance";
    string private constant INVALID_VESTING_ID = "Invalid vesting id";
    string private constant VESTING_ALREADY_RELEASED = "Vesting already released";
    string private constant INVALID_BENEFICIARY = "Invalid beneficiary address";
    string private constant NOT_VESTED = "Tokens have not vested yet";

    struct Vesting {
        uint256 releaseTime;
        uint256 amount;
        address beneficiary;
        bool released;
    }
    mapping(uint256 => Vesting) public vestings;

    event TokenVestingReleased(uint256 indexed vestingId, address indexed beneficiary, uint256 amount);
    event TokenVestingAdded(uint256 indexed vestingId, address indexed beneficiary, uint256 amount);
    event TokenVestingRemoved(uint256 indexed vestingId, address indexed beneficiary, uint256 amount);

    constructor(IERC20 _token) {
        require(address(_token) != address(0x0), "Matic token address is not valid");
        maticToken = _token;

        uint256 SCALING_FACTOR = 10 ** 18;
 //       uint256 day = 1 days;
        uint256 _minute = 1 minutes;

        addVesting(0xa1b9997cc41eC50F96135A36DE62544CAe3F2bFB, block.timestamp + 0, 100000000 * SCALING_FACTOR);
        addVesting(0xa1b9997cc41eC50F96135A36DE62544CAe3F2bFB, block.timestamp + 5 * _minute, 100000000 * SCALING_FACTOR);
        // addVesting(0xb316fa9Fa91700D7084D377bfdC81Eb9F232f5Ff, block.timestamp + 61 * day, 25000000 * SCALING_FACTOR);
        // addVesting(0xb316fa9Fa91700D7084D377bfdC81Eb9F232f5Ff, block.timestamp + 91 * day, 25000000 * SCALING_FACTOR);
        // addVesting(0xb316fa9Fa91700D7084D377bfdC81Eb9F232f5Ff, block.timestamp + 122 * day, 25000000 * SCALING_FACTOR);
        // addVesting(0xb316fa9Fa91700D7084D377bfdC81Eb9F232f5Ff, block.timestamp + 153 * day, 25000000 * SCALING_FACTOR);
        // addVesting(0xb316fa9Fa91700D7084D377bfdC81Eb9F232f5Ff, block.timestamp + 183 * day, 1088418885 * SCALING_FACTOR);
        // addVesting(0xb316fa9Fa91700D7084D377bfdC81Eb9F232f5Ff, block.timestamp + 214 * day, 25000000 * SCALING_FACTOR);
        // addVesting(0xb316fa9Fa91700D7084D377bfdC81Eb9F232f5Ff, block.timestamp + 244 * day, 25000000 * SCALING_FACTOR);
        // addVesting(0xb316fa9Fa91700D7084D377bfdC81Eb9F232f5Ff, block.timestamp + 275 * day, 25000000 * SCALING_FACTOR);
        // addVesting(0xb316fa9Fa91700D7084D377bfdC81Eb9F232f5Ff, block.timestamp + 306 * day, 25000000 * SCALING_FACTOR);
        // addVesting(0xb316fa9Fa91700D7084D377bfdC81Eb9F232f5Ff, block.timestamp + 335 * day, 25000000 * SCALING_FACTOR);
        // addVesting(0xb316fa9Fa91700D7084D377bfdC81Eb9F232f5Ff, block.timestamp + 366 * day, 1218304816 * SCALING_FACTOR);
        // addVesting(0xb316fa9Fa91700D7084D377bfdC81Eb9F232f5Ff, block.timestamp + 396 * day, 25000000 * SCALING_FACTOR);
        // addVesting(0xb316fa9Fa91700D7084D377bfdC81Eb9F232f5Ff, block.timestamp + 427 * day, 25000000 * SCALING_FACTOR);
        // addVesting(0xb316fa9Fa91700D7084D377bfdC81Eb9F232f5Ff, block.timestamp + 457 * day, 25000000 * SCALING_FACTOR);
        // addVesting(0xb316fa9Fa91700D7084D377bfdC81Eb9F232f5Ff, block.timestamp + 488 * day, 25000000 * SCALING_FACTOR);
        // addVesting(0xb316fa9Fa91700D7084D377bfdC81Eb9F232f5Ff, block.timestamp + 519 * day, 25000000 * SCALING_FACTOR);
        // addVesting(0xb316fa9Fa91700D7084D377bfdC81Eb9F232f5Ff, block.timestamp + 549 * day, 1218304816 * SCALING_FACTOR);
        // addVesting(0xb316fa9Fa91700D7084D377bfdC81Eb9F232f5Ff, block.timestamp + 580 * day, 25000000 * SCALING_FACTOR);
        // addVesting(0xb316fa9Fa91700D7084D377bfdC81Eb9F232f5Ff, block.timestamp + 610 * day, 25000000 * SCALING_FACTOR);
        // addVesting(0xb316fa9Fa91700D7084D377bfdC81Eb9F232f5Ff, block.timestamp + 641 * day, 25000000 * SCALING_FACTOR);
        // addVesting(0xb316fa9Fa91700D7084D377bfdC81Eb9F232f5Ff, block.timestamp + 672 * day, 25000000 * SCALING_FACTOR);
        // addVesting(0xb316fa9Fa91700D7084D377bfdC81Eb9F232f5Ff, block.timestamp + 700 * day, 25000000 * SCALING_FACTOR);
        // addVesting(0xb316fa9Fa91700D7084D377bfdC81Eb9F232f5Ff, block.timestamp + 731 * day, 1084971483 * SCALING_FACTOR);
        // addVesting(0xb316fa9Fa91700D7084D377bfdC81Eb9F232f5Ff, block.timestamp + 761 * day, 25000000 * SCALING_FACTOR);
        // addVesting(0xb316fa9Fa91700D7084D377bfdC81Eb9F232f5Ff, block.timestamp + 792 * day, 25000000 * SCALING_FACTOR);
        // addVesting(0xb316fa9Fa91700D7084D377bfdC81Eb9F232f5Ff, block.timestamp + 822 * day, 25000000 * SCALING_FACTOR);
        // addVesting(0xb316fa9Fa91700D7084D377bfdC81Eb9F232f5Ff, block.timestamp + 853 * day, 25000000 * SCALING_FACTOR);
        // addVesting(0xb316fa9Fa91700D7084D377bfdC81Eb9F232f5Ff, block.timestamp + 884 * day, 25000000 * SCALING_FACTOR);
        // addVesting(0xb316fa9Fa91700D7084D377bfdC81Eb9F232f5Ff, block.timestamp + 914 * day, 618304816 * SCALING_FACTOR);
        // addVesting(0xb316fa9Fa91700D7084D377bfdC81Eb9F232f5Ff, block.timestamp + 945 * day, 25000000 * SCALING_FACTOR);
        // addVesting(0xb316fa9Fa91700D7084D377bfdC81Eb9F232f5Ff, block.timestamp + 975 * day, 25000000 * SCALING_FACTOR);
        // addVesting(0xb316fa9Fa91700D7084D377bfdC81Eb9F232f5Ff, block.timestamp + 1096 * day, 593304816 * SCALING_FACTOR);
        // addVesting(0xb316fa9Fa91700D7084D377bfdC81Eb9F232f5Ff, block.timestamp + 1279 * day, 273304816 * SCALING_FACTOR);
    }

    function token() public view returns (IERC20) {
        return maticToken;
    }

    function beneficiary(uint256 _vestingId) public view returns (address) {
        return vestings[_vestingId].beneficiary;
    }

    function releaseTime(uint256 _vestingId) public view returns (uint256) {
        return vestings[_vestingId].releaseTime;
    }

    function vestingAmount(uint256 _vestingId) public view returns (uint256) {
        return vestings[_vestingId].amount;
    }

    function viewbalance() public view returns (uint256) {
        return maticToken.balanceOf(address(this));
    }

    function removeVesting(uint256 _vestingId) public onlyOwner {
        Vesting storage vesting = vestings[_vestingId];
        require(vesting.beneficiary != address(0x0), INVALID_VESTING_ID);
        require(!vesting.released , VESTING_ALREADY_RELEASED);
        vesting.released = true;
        tokensToVest = tokensToVest.sub(vesting.amount);
        emit TokenVestingRemoved(_vestingId, vesting.beneficiary, vesting.amount);
    }

    function addVesting(address _beneficiary, uint256 _releaseTime, uint256 _amount) public onlyOwner {
        require(_beneficiary != address(0x0), INVALID_BENEFICIARY);
        tokensToVest = tokensToVest.add(_amount);
        vestingId = vestingId.add(1);
        vestings[vestingId] = Vesting({
            beneficiary: _beneficiary,
            releaseTime: _releaseTime,
            amount: _amount,
            released: false
        });
        emit TokenVestingAdded(vestingId, _beneficiary, _amount);
    }

    function release(uint256 _vestingId) public {
        Vesting storage vesting = vestings[_vestingId];
        require(vesting.beneficiary != address(0x0), INVALID_VESTING_ID);
        require(!vesting.released , VESTING_ALREADY_RELEASED);
        // solhint-disable-next-line not-rely-on-time
        require(block.timestamp >= vesting.releaseTime, NOT_VESTED);

     //   require(maticToken.balanceOf(address(this)) >= vesting.amount, INSUFFICIENT_BALANCE);
        vesting.released = true;
        tokensToVest = tokensToVest.sub(vesting.amount);
        maticToken.safeTransfer(vesting.beneficiary, vesting.amount);
        emit TokenVestingReleased(_vestingId, vesting.beneficiary, vesting.amount);
    }

    function retrieveExcessTokens(uint256 _amount) public onlyOwner {
        require(_amount <= maticToken.balanceOf(address(this)).sub(tokensToVest), INSUFFICIENT_BALANCE);
        maticToken.safeTransfer(owner(), _amount);
    }
}