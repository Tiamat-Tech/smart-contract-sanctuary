pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Distribution {

mapping(uint=>User) users;
   address payable admin;
constructor(){
        admin=payable(msg.sender);
}

 modifier onlyOwner {
        require(
            msg.sender == admin,
            "Only owner can call this function."
        );
        _;
    }


struct User{
     uint id;
     string name;
     string designation;
     uint amount;
     address userAddress;
}



function addUser(uint _id,string memory _name, string memory _designation,address _userAddress) external  onlyOwner returns (bool ) {
    users[_id]=User (_id,_name,_designation,0,_userAddress);
    return true;
}

function getUser(uint _id) external view returns(User memory _user){
    _user=users[_id];
}

function transfertouser(address _recipient, uint _amount) public onlyOwner{

    payable(_recipient).transfer(_amount);
    User storage user1=users[123];
    user1.amount=user1.amount+_amount;

}

}