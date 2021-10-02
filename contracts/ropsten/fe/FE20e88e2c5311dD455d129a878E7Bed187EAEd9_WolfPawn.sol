// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract WolfPawn is ERC20, ERC20Burnable, Ownable {
    using EnumerableSet for EnumerableSet.UintSet;
    
    bool public isPreSale = true;
    bool public salesStarted = false;
    
    IERC721 _wolfGang = IERC721(0x8078948bf9fbE5ECbBBFC7698acb6Db1aF24405c);
    address _pairAddress;
    
    mapping (address => bool) public userHasBought;
    mapping (address => uint) public userBoughtPreSale;
    
    constructor() ERC20("WolfPawn", "PAWN") {
        _mint(msg.sender, 10000 * 10 ** decimals());
    }
    
    function buyAllowance(address userAddress) public view returns (uint) {
        uint wolfBalance = _wolfGang.balanceOf(userAddress);
        if (!userHasBought[userAddress]) return wolfBalance * 10 ** decimals();
        return (wolfBalance - userBoughtPreSale[userAddress]) * 10 ** decimals();
    }
    
    function setPairAddress(address pairAddress_) public onlyOwner {
        _pairAddress = pairAddress_;
    }
    
    function toggleSales() public onlyOwner {
        salesStarted = !salesStarted;
    }
    
    function endPreSale() public onlyOwner {
        isPreSale = false;
    }
    
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        // require(_pairAddress != address(0));
        // if (to == owner() || from != _pairAddress) return;
        // require(salesStarted, "sales has not been started");
        // if (!isPreSale) return;
        
        // require(amount <= buyAllowance(to), "amount exceeds buy allowance");
        // userBoughtPreSale[to] += amount;
    }
}