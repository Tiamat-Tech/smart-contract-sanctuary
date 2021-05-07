/**
* Submitted for verification at blockscout.com on 2018-10-22 15:11:03.814491Z
*/
pragma solidity ^0.8.0;

import "@OpenZeppelin/contracts/access/Ownable.sol";
import "@OpenZeppelin/contracts/utils/math/SafeMath.sol";

interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}


contract Airdrop is Ownable {
    using SafeMath for uint256;
    
    uint256 public fee;
    
    constructor (uint256 _fee,address _admin) {
        fee = _fee;
        transferOwnership(_admin);
    }

    function disperseToken(IERC20 token,address[] memory _recipients, uint256[] memory _amount) public payable returns (bool) {
        
        require(msg.value == fee,'Insufficient fee');
        
        require(_recipients.length == _amount.length, 'Invalid data');
        
        uint256 total = 0;
        for (uint256 i = 0; i < _recipients.length; i++)
            total += _amount[i];
                            
        for (uint256 i = 0; i < _recipients.length; i++) {
            require(_recipients[i] != address(0), 'Not allowed transfer to address 0');            
            require(token.transferFrom(msg.sender, _recipients[i], _amount[i]));
        }

        return true;
    }
    
    
     function disperseEther(address payable[] memory _recipients, uint256[] memory _amount) public payable  returns (bool) {
         
        require(_recipients.length == _amount.length, 'Invalid data');
        uint256 total = 0;

        for(uint256 j = 0; j < _amount.length; j++) {
            total = total.add(_amount[j]);
        }

        require(total.add(fee) <= msg.value ,  'Insufficient amount');
            
        for (uint256 i = 0; i < _recipients.length; i++) {
            require(_recipients[i] != address(0), 'Not allowed transfer to address 0');

            _recipients[i].transfer(_amount[i]);
        }

        return true;
    }
    
    
    function withdrawEther(address payable beneficiary) public onlyOwner {
        beneficiary.transfer(address(this).balance);
    }
    
    function updateFee(uint256 _fee) public onlyOwner {
        fee = _fee;
    }
    
    function balance() public view returns (uint256) {
        return address(this).balance;
    }
    
    
    

    

    
}