// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./ERC20.sol";

contract VerifyCoin is ERC20 {
    
    /*
     *      Burn Stops at 1% of totalSupply() 
     *      _minimumSupply = 1,000,000,000,000 = 1 trillion
     */
    uint256 private _minimumSupply = 99 * ((10) ** uint256(decimals()));
    
    
    //Wallet addresses for each burn fee, treasury fee, community fee
    address communityWallet = 0xD0BB8771798a3D69dcF71D468Ee3378296484c7F;
    address burnWallet = 0xc7ccf7481c1a7103F200Ee1884A5D8842ffa09b2;
    address treasuryWallet = 0x4df9f50525582a34C201871cAA9D17b2358D1692;
    
    
    constructor () ERC20("VerifyCoin", "VFC") {
        
        //Initial Total Supply = 100,000,000,000,000 = 100 trillion
        _mint(msg.sender, 100 * ((10) ** uint256(decimals())));

    }
    
    /* 
     *  For transfer() and transferFrom() - override to include 6% fee on each transaction:
     *      -1% to the community wallet
     *      -3% burned to address(0) 
     *      -2% to the treasury wallet 
     * 
     *  Continues to burn while totalSupply >= _minimumSupply
     */
     
    function transfer(address to, uint256 amount)  public override returns (bool) {
        
        uint256 onePercentFee = (amount * 1) / 100 ;
        uint256 burnFee = onePercentFee * 3;
        uint256 treasuryFee = onePercentFee  * 2;
            
        //Burn if the total supply after the burn is >= _minimumSupply
        if (totalSupply() > _minimumSupply) {
                
            uint256 newTotalSupply = totalSupply() - burnFee;
            if (newTotalSupply >= _minimumSupply) {
                _burn(msg.sender, burnFee);
            }else{
            //when burn limit is reached, the amount burned is reduced to keep the supply at _minimumSupply
               uint256 slashAndBurn = totalSupply() - _minimumSupply;
               _burn(msg.sender, slashAndBurn);
            }
        }
            
        //transfer treasury and community fees 
        super.transfer(treasuryWallet, treasuryFee);
        super.transfer(communityWallet, onePercentFee);
            
        //transfer requested amount
        return super.transfer(to, (amount));
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        
        uint256 onePercentFee = (amount * 1) / 100 ;
        uint256 burnFee = onePercentFee * 3;
        uint256 treasuryFee = onePercentFee  * 2;
        
        
        //Burn if the total supply after the burn is >= _minimumSupply
        if (totalSupply() > _minimumSupply){
            
            uint256 newTotalSupply = totalSupply() - burnFee;
            if (newTotalSupply >= _minimumSupply) {
                _burn(msg.sender, burnFee);
            }else{
            //when burn limit is reached, the amount burned is reduced to keep the supply at _minimumSupply
               uint256 slashAndBurn = totalSupply() - _minimumSupply;
               _burn(msg.sender, slashAndBurn);
            }
        }
        
        //transfer treasury and community fees
        super.transfer(treasuryWallet, treasuryFee);
        super.transfer(communityWallet, onePercentFee);
        
        //transfer requested amount
        return super.transferFrom(from, to, amount);
    }


}