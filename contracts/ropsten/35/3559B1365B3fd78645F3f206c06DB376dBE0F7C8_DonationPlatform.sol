// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC721{
      function createAndSend(address _admin,uint256 _tokenId,address _to) external payable;
}

 
/// @title Crypto donation platorm
/// @author Luka Jevremovic
/// @notice This is authors fisrt code in soldity, be cearful!!!
/// @dev All function calls are currently implemented without side effects
/// @custom:experimental This is an experimental contract.
contract DonationPlatform is Ownable{
  
   //pakovanje strukure
    struct Campagine{
        uint timeTrget;
        uint  amountTarget;
        address payable  menager;
        //uint amount;
        string  name;
        string descripton;
        bool  closed;
   }
    
    mapping (address=>mapping(string=>uint)) private contributors;
    address public immutable admin;
    mapping (string=>Campagine) public campagines;
    uint256 private nftid;
    IERC721 public immutable nft;
    mapping (string=>uint) private amounts;

    event ContrbutionReceived(address indexed sender, string message);
    event CampagineCreated(address  sender, string indexed name);
    event Whithdraw(address reciver);
    event CampagineClosed(string indexed name);
    constructor(address _nft){
        admin=msg.sender;
        nft=IERC721(_nft);
    }

    function creatCampagine(address _menanger, string memory _name,string  memory _descritpion, uint _timeTarget, uint  _amountTarget) public onlyOwner {
        require(bytes(campagines[_name].name).length==0,"Campagine with that name already exists");// ne znam dal ovo moze bolje da se napise
        Campagine memory newcampagine;
        newcampagine.menager=payable(_menanger);
        newcampagine.name=_name;
        newcampagine.descripton=_descritpion;
        newcampagine.timeTrget=block.timestamp+_timeTarget*86400;//number of days
        newcampagine.amountTarget=_amountTarget;
        campagines[_name]=newcampagine;

        emit CampagineCreated(msg.sender,_name);
    }
    
    function contribute(string memory _name) public payable{
        require(msg.value>0,"thats not nice");
        require(bytes(campagines[_name].name).length!=0,"Campagine with that name doesn't exists");
        /// reverts donation if time target has passsed
        Campagine memory campagine=campagines[_name];
        if (campagine.closed ||block.timestamp>=campagine.timeTrget) 
           revert("this Campagine is closed");

        ///closes the campagine but doesnt revert the donation
        if (campagine.amountTarget<=amounts[_name]+msg.value) {
                campagines[_name].closed=true;
                emit CampagineClosed(campagines[_name].name);
        }

        if (contributors[msg.sender][_name]==0)
             nft.createAndSend(admin, nftid++,msg.sender);
        amounts[_name]+=msg.value;
        contributors[msg.sender][_name]+=msg.value;//treba da se doda provera jedinstevnosti za drugi zadatak

        emit ContrbutionReceived(msg.sender,"Contribution recevied");
    }
    
    function withdraw(string memory _name) public payable {
        require(msg.sender==campagines[_name].menager,"only menager can whithdraw");
        (bool success, ) = campagines[_name].menager.call{value: amounts[_name]}("");
        require(success, "Failed to send Ether");
        amounts[_name]=0;
        emit Whithdraw(msg.sender);
    }

    function getBalance(string memory _name) public view returns (uint) {
        return amounts[_name];
    }
    
}