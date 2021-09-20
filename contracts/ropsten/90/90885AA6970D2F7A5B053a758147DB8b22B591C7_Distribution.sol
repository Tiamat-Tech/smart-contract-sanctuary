pragma solidity ^0.8.0;
import './IERC20.sol';

 contract Distribution {


address  admin;
address _tokenAddress=0x674dAC661f1905eB622edDf263A85d8b96b3C20D;

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

function transferToUser( address _userAddress,uint _amount) public onlyOwner {
   IERC20(_userAddress).transferFrom(admin,_userAddress,_amount);
   User storage _user=users[_userAddress];
   _user.amount=_user.amount + _amount;
}

}