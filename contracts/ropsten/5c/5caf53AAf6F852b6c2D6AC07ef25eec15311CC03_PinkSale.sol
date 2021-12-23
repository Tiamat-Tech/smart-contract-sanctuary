//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// TS= Total Supply

contract PinkSale is ERC20{
    address public admin;
    uint256 public TS;
    uint public maxBuyPerWallet;
    uint public maxWalletAmount;
    uint public maxSalePerWallet;
    address liquidityWallet;
    address buyBacksWallet;
    address marketingWallet;
    address referalWallet;
    uint public liquidityTax; 
    uint public buyBacksTax;
    uint public marketingTax;
    uint ownerAmount;
    event _Transfer(address indexed from, address indexed to, uint256 value);
    uint liquidityPercentageToBuy = 70;
    uint buyBacksPercentageToBuy = 20;
    uint liquidityPercentageToSell = 10;
    uint buyBacksPercentageToSell = 3; 
    uint marketingPercentageToSell = 2;
    uint referedAmount;
    bool listingTaxValue = false;
    uint listingTaxPercentage;
    address[] blackListAddresses;
    uint currentTime;
    uint minute = 60 seconds; 
    
    constructor() ERC20('C0DE X', 'token'){
        TS = 100000000;
        admin = msg.sender;
        maxWalletAmount = (TS * 7/2) / 100;
        maxBuyPerWallet = (TS * 3/2) / 100;
        maxSalePerWallet = (TS * 1/2) / 100;
        referedAmount = TS / 100;
        _mint(msg.sender, TS);
        liquidityWallet = 0x7c064627fCe1ac89Edd04A623706f6C81caDAd75;
        buyBacksWallet = 0x8cC8f4184380A58677416c9B9E79397D21Bdd442;
        marketingWallet = 0xd1243351088Ff86475F6d54f9c44439e8029B7d1;
        referalWallet = 0x6c448b1D2f34C8b03d24bf16d55baC085d6F2BA1;

    }
    function setListingTax(bool enable) public{
        listingTaxValue = enable;
    }
    function getListingTax() public view returns(bool){
        return listingTaxValue;
    }

    function maxBuy(uint amount, address recipient) public {
        if(listingTaxValue == true)
        {
            require(balanceOf(recipient) <= maxWalletAmount, 'amount in your wallet is greater than max wallet');
            listingTaxPercentage = (amount * 95) / 100;
            amount = amount - listingTaxPercentage;
            require(balanceOf(recipient)  + amount <= maxWalletAmount,' maximum amount exceeded than max Wallet Amount');
            _transfer(msg.sender, recipient, amount);
            _transfer(msg.sender, buyBacksWallet, listingTaxPercentage);
        }
        else
        {
            require(balanceOf(recipient) <= maxWalletAmount, 'amount in your wallet is greater than max wallet');
            require(amount <= maxBuyPerWallet, 'you cannot do transaction more than maxBuyPerWallet');
            require(balanceOf(recipient)  + amount <= maxWalletAmount,' maximum amount exceeded than max Wallet Amount');
            ownerAmount =  (amount * 90 ) / 100;
            _transfer(msg.sender, recipient, ownerAmount);
            amount = amount - ownerAmount;
            liquidityTax = (amount * liquidityPercentageToBuy) / 100;
            _transfer(msg.sender, liquidityWallet, liquidityTax);
            buyBacksTax = (amount * buyBacksPercentageToBuy) / 100;
            _transfer(msg.sender, buyBacksWallet, buyBacksTax);
            amount = amount - liquidityTax - buyBacksTax;
            _transfer(msg.sender, marketingWallet, amount);
        }
        

    }
    function maxSale(uint amount, address seller) public {
        bool blackListed;
        for(uint i=0; i<=blackListAddresses.length; i++){
            if(seller == blackListAddresses[i]){
          blackListed = true;
            }
        }
        require(currentTime + 60 < block.timestamp, 'wait until 1 minute');
        require(blackListed == false, 'your address is black listed');
        require(balanceOf(msg.sender) > 0, 'you have insufficient token to sell');
        require(amount <= maxSalePerWallet, 'you cannot do transaction more than max Sale');
        liquidityTax = (amount * liquidityPercentageToSell) / 100;
        buyBacksTax = (amount * buyBacksPercentageToSell) / 100;
        marketingTax = (amount * marketingPercentageToSell) / 100;
        require(balanceOf(msg.sender) >= amount + liquidityTax + buyBacksTax + marketingTax, 'your current balance is less than your transaction');
        _transfer(msg.sender, seller, amount);
        _transfer(msg.sender, liquidityWallet, liquidityTax);
        _transfer(msg.sender, buyBacksWallet, buyBacksTax);
        _transfer(msg.sender, marketingWallet, marketingTax);
        currentTime = block.timestamp;

    }
    function referalSystem() public {
        require(msg.sender == admin, 'only admin');
        _transfer(msg.sender, referalWallet, referedAmount);

    }
    
    // function _transferOwnership(address account, uint256 amount) internal virtual {

    // }
    function BlackList(address blackListAddress) public {
        require(msg.sender == admin, 'only admin');
        blackListAddresses.push(blackListAddress);
    }
    function RemoveFromBlackList(address blackListAddress) public{
        require(msg.sender == admin, 'only admin');

        for(uint i=0; i<blackListAddresses.length; i++){
            if(blackListAddress == blackListAddresses[i]){
                delete blackListAddress;
            }
        }
    }

   
    
}