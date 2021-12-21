//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";


interface IERC20 {
    function totalsupply() external view returns (uint256);

    function balanceof(address account) external view returns (uint256);

   // function transfer(address recipent, uint256 amount) internal returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
}
contract tokenname is IERC20 {
    mapping(address => uint256)public balances;
    uint256 public _totalSupply = 1000000;
    uint256 public constant tokenprice =0.01 ether ;
    address public  owner;
    uint256 public contrac;
    constructor() public 
  {
      owner=msg.sender;
      balances[msg.sender] = _totalSupply;
  }
     function totalsupply() public view override returns (uint256) {
        return _totalSupply;
    }

      function balanceof(address tokenowner)
        public
        view
        override
        returns (uint256)
    {
        return balances[tokenowner];
    }
    //    function transfer(address reciver, uint256 numOfToken)
    //     internal
        
    //     returns (bool)
    // {
    //     // sender should have transferable amount of token
    //     require(numOfToken <= balances[msg.sender],"you not have enough token"); 
    //     balances[msg.sender] -= numOfToken;
    //     balances[reciver] += numOfToken;
    //     emit Transfer(msg.sender, reciver, numOfToken);
    //     return true;
    // }
    function Buy(uint256 token) public payable
   {
       require(msg.value >=token*tokenprice,"please pay complte amount");
     // this(address).transfer(sender);
       
       balances[msg.sender] += token;
       _totalSupply -=token;
       balances[owner]-=token;
       emit Transfer(owner,msg.sender,token);
   }
   function sell (uint256 token) public payable 
   {
       require(balances[msg.sender]>=token,"your token are less");
        balances[msg.sender] -= token;
       _totalSupply +=token;
       balances[owner]+=token;
      address payable recviver=payable(msg.sender);
    contrac = address(this).balance;
      recviver.transfer(address(this).balance);
       emit Transfer(msg.sender,owner,token);
   }

}