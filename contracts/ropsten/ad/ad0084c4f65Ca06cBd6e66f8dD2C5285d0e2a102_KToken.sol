// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract KToken is ERC20 {
    //ETH-USD=1, wBTC-USD=2, Polygon-USD=3
    uint8 _underlying = 1; 
    
    uint _strike = 3405;
    uint _maturity = 1;
    uint _expiresOn = 1622063740;
    bool _isPut = false;
    
    address public minter = 0xfbF39e5ceE83f35DbF62a91A31cefb36Fedc2b58; //This is the Octopus smart contract
    
    function getUnderlying() public view returns (uint8) {
        return _underlying;
    }
    
    function getStrike() public view returns (uint) {
        return _strike;
    }
    
    function getMaturity() public view returns (uint) {
        return _maturity;
    }

    function getExpiresOn() public view returns (uint) {
        return _expiresOn;
    }
    
    function isPut() public view returns (bool) {
        return _isPut;
    }

    function getDecimals() public view returns (uint) {
        return decimals();
    }
    
   function mint(address to, uint256 value) public {
       require(msg.sender == minter, "Invalid caller");
       
        _mint(to, value);
    }
    
    constructor() ERC20('K-Token', 'KTK')
    {
        
    }
}