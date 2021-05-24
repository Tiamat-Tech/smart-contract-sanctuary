// SPDX-License-Identifier: MIT

/*

There once was a lad named Shappy
Who alerted to all coins crappy
He called it a bug
And then came the rug
Now he's gone from the mappy

Dear Shapp,

Consider my 2 ETH a donation to your bail fund. We didn't need the audit anyway.

Yours truly,

Nodezy

*/

pragma solidity 0.7.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./KojiVesting.sol";

contract KojiTeamVesting is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public immutable KOJI;
    address public immutable VESTING_LOGIC;

    mapping(address => address[]) public vestings;
    
    uint256 public vestingCliffDuration = 0 days;
    uint256 public vestingDuration = 1 days;

    constructor(address _koji, address _vestingLogic) {
        require(_koji != address(0), "KojiVEST: koji is a zero address");
        require(_vestingLogic != address(0), "KojiVEST: vestingLogic is a zero address");
       
        KOJI = IERC20(_koji);
        VESTING_LOGIC = _vestingLogic;
        
    }

    
    function vest(address recipient, uint256 amount) onlyOwner public {
        
        require(amount >= 1, "KojiVEST: KOJI amount is less than 1");
        amount = amount.mul(1e18);
        require(amount <= 15000000000000000000000000000, "KojiVEST: amount is too large, no amount vested is this size");
        uint256 balance = KOJI.balanceOf(address(this));
        require(amount <= balance, "KojiVEST: koji balance is insufficient");       

        KojiVesting vesting = KojiVesting(Clones.clone(VESTING_LOGIC));
        vesting.initialize(
            address(KOJI),
            recipient,
            amount,
            block.timestamp,
            vestingCliffDuration,
            vestingDuration
        );

        KOJI.safeTransfer(address(vesting), amount);
        vestings[recipient].push(address(vesting));
    }

    function getVestings(address _account, uint256 _start, uint256 _length) external view returns (address[] memory) {
        address[] memory filteredVestings = new address[](_length);
        address[] memory accountVestings = vestings[_account];

        for (uint256 i = _start; i < _length; i++) {
            if (i == accountVestings.length) {
                break;
            }
            filteredVestings[i] = accountVestings[i];
        }

        return filteredVestings;
    }

    function getAllVestings(address _account) external view returns (address[] memory) {
        return vestings[_account];
    }

    function getVestingsLength(address _account) external view returns (uint256) {
        return vestings[_account].length;
    }


    function setVestingCliffDuration(uint256 _vestingCliffDuration) external onlyOwner {
        require(_vestingCliffDuration != 0, "KojiVEST: vestingCliffDuration is zero");
        require(_vestingCliffDuration <= vestingDuration, "KojiVEST: vestingCliffDuration is longer than vestingDuration");
        vestingCliffDuration = _vestingCliffDuration;
    }

    function setVestingDuration(uint256 _vestingDuration) external onlyOwner {
        require(_vestingDuration != 0, "KojiVEST: vestingDuration is zero");
        vestingDuration = _vestingDuration;
    }


    function withdrawTokens() public onlyOwner {
        uint256 kojiBalance = KOJI.balanceOf(address(this));
        require(kojiBalance != 0, "KojiVEST: no koji tokens to withdraw");
        KOJI.safeTransfer(owner(), kojiBalance);
    }

    function withdrawFunds() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance != 0, "KojiVEST: no funds to withdraw");
        payable(owner()).transfer(balance);
    }

    
}