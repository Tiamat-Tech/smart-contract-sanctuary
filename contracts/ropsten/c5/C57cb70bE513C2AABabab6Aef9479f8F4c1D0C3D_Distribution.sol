pragma solidity ^0.8.0;
import './Token.sol';
contract Distribution is MyToken{

mapping(uint=>User) users;


 

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
}



function addUser(uint _id,string memory _name, string memory _designation) external  onlyOwner returns (string memory ) {
    users[_id]=User (_id,_name,_designation,0);
    return "success";
}

function getUser(uint _id) external view returns(User memory _user){
    _user=users[_id];
}

}