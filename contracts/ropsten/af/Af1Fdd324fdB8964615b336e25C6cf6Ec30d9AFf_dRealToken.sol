// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IPriceConsumer {
    function getLatestPrice() external view returns (int);
}

contract dRealToken is ERC20 {
    address PRICE_CONSUMER = 0x0529104EC7c2e21f0970f6Aa76AAd902C9ADD789;
    
    uint256 PRESALE_STARTS_ON = 1643670000; //01/02/2022
    
    uint256 SALE_STARTS_ON = 1644879600; //15/02/2022
    uint256 SALE_FINISHES_ON = 1648591200; //30/03/2022
    
    uint256 PRESALE_PRICE = 450000; //$0.0045 
    uint256 SALE_PRICE = 12000; //$0.012
    
    uint256 MAX_CAP_PRESALE = 500000000 * 10 ** 18;

    uint256 MAX_CAP_SALE = 2500000000 * 10 ** 18;
    
    uint256 public totalSold = 0;
    bool notSoldBurnt = false;
    
    //And let's make it so that what is not sold is burned
    
    function getBuyingPrice(uint256 _tokenAmount) public view returns(uint256) {
        //Price in USD (8 decimals) for 1 ETH
        uint256 currentPrice = uint256(IPriceConsumer(PRICE_CONSUMER).getLatestPrice());
        
        return 1 / currentPrice * _tokenAmount * PRESALE_PRICE;
    }

    function buyFromIco(uint256 _tokenAmount) public payable {
        require(block.timestamp > PRESALE_STARTS_ON && block.timestamp < SALE_FINISHES_ON, "Invalid date");
        
        uint256 buyingPrice = getBuyingPrice(_tokenAmount);
        
        require(msg.value == buyingPrice, 'Invalid payment amount');
         
        transfer(msg.sender, _tokenAmount * 1e18);
        
        totalSold += _tokenAmount;
    }

    function burnNotSoldTokens() public {
        require(block.timestamp > SALE_FINISHES_ON, "Invalid date");
        require(notSoldBurnt == false, "Already called");
        
        notSoldBurnt = true;
        
        uint256 totalToBurn = MAX_CAP_SALE - totalSold * 1e18;
        
        _burn(address(this), totalToBurn);
    }    
    
    
    constructor() ERC20('REAL', 'REAL')
    {
        _mint(msg.sender, 2500000000 * 10 ** 18);
        _mint(address(this), 2500000000 * 10 ** 18);
    }
}