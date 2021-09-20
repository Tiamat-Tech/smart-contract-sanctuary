pragma solidity ^0.8.0;
import './IERC20.sol';

 contract Distribution {


address  admin;
address _tokenAddress=0xe1833b37c9034B96ECCA4beA82Ca6e7BB0fD3344;

mapping(address=>User) users;

constructor(){
        admin=msg.sender;
}

 modifier onlyOwner {
        require(
            msg.sender == admin,
            "Only owner can call this function."
        );
        _;
    }



struct User{
     address userAddress;
     string name;
     string designation;
     uint amount;
}



function addUser(address _userAddress,string memory _name, string memory _designation) external  onlyOwner returns (bool ) {
    users[_userAddress]=User (_userAddress ,_name,_designation,0);
    return true;
}

function getUser(address _userAddress) external view returns(User memory _user){
    _user=users[_userAddress];
}


function getBalance(address _userAddress) public view returns(uint){

return IERC20(_tokenAddress).balanceOf(_userAddress);

}

function transferToUser( address _userAddress,uint _amount) public  {

   IERC20(_tokenAddress).transfer( _userAddress , _amount);
   User storage _user=users[_userAddress];
   _user.amount=_user.amount + _amount;
   
}

}