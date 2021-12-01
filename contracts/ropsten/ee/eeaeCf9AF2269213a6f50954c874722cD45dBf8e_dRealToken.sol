// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IPriceConsumer {
    function getLatestPrice() external view returns (int);
}

contract dRealToken is ERC20 {
    address owner;

    address PRICE_CONSUMER = 0xF6D9f3695F0CCF7cF745fE357C4B0F9DBBE37841; //Mainnet: 0x0529104EC7c2e21f0970f6Aa76AAd902C9ADD789
    
    uint256 PRESALE_STARTS_ON = 1637794800; // 1643670000; //01/02/2022
    
    uint256 SALE_STARTS_ON = 1638054000; // 1644879600; //15/02/2022
    uint256 SALE_FINISHES_ON = 1639147031; //1648591200; //30/03/2022
    
    uint256 PRESALE_PRICE = 450000; //$0.0045 
    uint256 SALE_PRICE = 1200000; //$0.012
    
    uint256 MAX_CAP_PRESALE = 500000000 * 10 ** 18;

    uint256 MAX_CAP_SALE = 2500000000 * 10 ** 18;
    
    uint256 public totalSold = 0;
    bool notSoldBurnt = false;

    function getTokenPrice() public view returns (uint256) {
        uint tokenPrice = PRESALE_PRICE;
        if (block.timestamp > SALE_STARTS_ON) {
            tokenPrice = SALE_PRICE;
        }
        return tokenPrice;
    }

    function getETHPrice() public view returns (uint256) {
        return uint256(IPriceConsumer(PRICE_CONSUMER).getLatestPrice());
    }
    
    function getBuyingPrice(uint256 _tokenAmount) public view returns(uint256) {
        //Price in USD (8 decimals) for 1 ETH
        uint256 ETHPrice = getETHPrice();

        //Price in USD (8 decimals) for 1 token
        uint tokenPrice = getTokenPrice();

        //WEI required for this purchase
        return _tokenAmount * tokenPrice / ETHPrice;
    }

    function buyFromIco(uint256 _tokenAmount) public payable {
        require(block.timestamp > PRESALE_STARTS_ON && block.timestamp < SALE_FINISHES_ON, "Invalid date");
        
        uint256 buyingPrice = getBuyingPrice(_tokenAmount);
        
        require(msg.value >= buyingPrice, 'Invalid payment amount');
         
        transferFrom(address(this), msg.sender, _tokenAmount);
        
        totalSold += _tokenAmount;
    }

    function withdraw() public payable {
        uint balance = address(this).balance;
        require(payable(owner).send(balance));
    }

    function burnNotSoldTokens() public {
        require(block.timestamp > SALE_FINISHES_ON, "Invalid date");
        require(notSoldBurnt == false, "Already called");
        
        notSoldBurnt = true;
        
        uint256 totalToBurn = MAX_CAP_SALE - totalSold;
        
        _burn(address(this), totalToBurn);
    }    
    
    constructor() ERC20('REAL', 'REAL')
    {
        _mint(msg.sender, 2500000000 * 10 ** 18);
        _mint(address(this), 2500000000 * 10 ** 18);

        owner = msg.sender;
    }
}