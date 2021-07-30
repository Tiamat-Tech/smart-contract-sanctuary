// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface ArbitraryTokenStorage {
    function withdrawToken(IERC20 token) external;
}

contract ERC20Storage is Ownable, ArbitraryTokenStorage {
    
    function withdrawToken(IERC20 token) external override virtual onlyOwner{
        uint256 balance = token.balanceOf(address(this));
        
        require(balance > 0, "Contract has no balance");
        require(token.transfer(owner(), balance), "Transfer failed");
    }

    function withdrawEth() public virtual onlyOwner{
        uint256 etherBalance = address(this).balance;
        (bool success,  ) = msg.sender.call{value: etherBalance}("");
        require(success, "Transfer failed.");
    }
}

contract NEXA is Pausable,ERC20Burnable,ERC20Storage {
    using SafeMath for uint256;
    bool mintCalled=false;
    
    address public _strategicBucketAddress;
    address public _foundingBucketAddress;
    address public _marketingBucketAddress;
    address public _artistBucketAddress;
    address public _technologyBucketAddress;
    address public _advisersBucketAddress;
    address public _foundationBucketAddress;
    address public _liquidityBucketAddress;

    uint256 public strategicLimit =  10 * (10**6) * 10**decimals();   // 10m tokens for Strategic Partners
    uint256 public foundingLimit =  10 * (10**6) * 10**decimals();   // 10m tokens for Founding Members
    uint256 public marketingLimit =  25 * (10**6) * 10**decimals();   // 25m tokens for Marketing
    uint256 public artistsLimit =  7.5 * (10**6) * 10**decimals();   // 7.5m tokens for Artists
    uint256 public technologyLimit =  10 * (10**6) * 10**decimals();   // 10m tokens for Technology Contributors
    uint256 public advisersLimit =  5 * (10**6) * 10**decimals();   // 5m tokens for Advisers
    uint256 public foundationLimit =  10 * (10**6) * 10**decimals();   // 10m tokens for Foundation
    uint256 public liquidityLimit = 20 * (10**6) * 10**decimals();   // 20m tokens for Liquidity
    uint256 public publicSaleLimit = 2.5 * (10**6) * 10**decimals();   // 2.5m tokens for public sale

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(owner(), publicSaleLimit);
    }

    function setAllocation(
        address strategicBucketAddress,
        address foundingBucketAddress,
        address marketingBucketAddress,
        address artistBucketAddress,
        address technologyBucketAddress,
        address advisersBucketAddress,
        address foundationBucketAddress,
        address liquidityBucketAddress
        ) public onlyOwner {
        require(mintCalled == false, "Allocation already done.");

        _strategicBucketAddress = strategicBucketAddress;
        _foundingBucketAddress = foundingBucketAddress;
        _marketingBucketAddress = marketingBucketAddress;
        _artistBucketAddress = artistBucketAddress;
        _technologyBucketAddress = technologyBucketAddress;
        _advisersBucketAddress = advisersBucketAddress;
        _foundationBucketAddress = foundationBucketAddress;
        _liquidityBucketAddress = liquidityBucketAddress;
        
        _mint(_strategicBucketAddress, strategicLimit);
        _mint(_foundingBucketAddress, foundingLimit);
        _mint(_marketingBucketAddress, marketingLimit);
        _mint(_artistBucketAddress, artistsLimit);
        _mint(_technologyBucketAddress, technologyLimit);
        _mint(_advisersBucketAddress, advisersLimit);
        _mint(_foundationBucketAddress, foundationLimit);
        _mint(_liquidityBucketAddress, liquidityLimit);
        
        mintCalled=true;
    }

    function purchase() payable external{
    }
    
    receive() external payable{
    }
}