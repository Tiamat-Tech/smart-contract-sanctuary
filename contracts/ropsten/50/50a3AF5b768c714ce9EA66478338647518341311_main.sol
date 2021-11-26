pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";



contract main is ERC721 {

using Counters for Counters.Counter;

Counters.Counter private _tokenIds;

 constructor() public ERC721("test university", "tu") {}

 struct person{
    uint256[] id;
}
 
 mapping(address => person) internal personDetails; // stores the persons address with all the ids allocated to it

 mapping(string => uint8) internal hashes; //ipfs url of the file

 mapping(uint256 => string) public tokenId;
 

function addItem(address recipient, string memory hash, string memory metadata)
  public
  returns (uint256)
{
  require(hashes[hash] != 1, "Files already assigned !!");

  hashes[hash] = 1;

  _tokenIds.increment();

  uint256 newItemId = _tokenIds.current();

  _mint(recipient, newItemId); //assigns an id with an address

  //setTokenURI( newItemId, metadata);//
  tokenId[newItemId] = metadata;// sets the tokenid to json file containg the metadata and file link

   personDetails[recipient].id.push(newItemId);

  return newItemId;
}

function getIdLenght(address add) public view returns(uint256){ //will get he total number of ids hold by a address
   return personDetails[add].id.length;
}

function getId(address add, uint256 d) public view returns(uint256){ //after getting the lenght of ids stored by an address, this can called by running an array to get all the allocated ids
    return personDetails[add].id[d];
}

// function setTokenURI(uint256 newItemId, string memory metadata)
// internal
// {
//     tokenId[newItemId] = metadata;// change it to hash, to display the ipfs link
// }
// }
}


//to check if an id is owned by a person in check window, a databse should store the ids owned by a persons address or else, the js script should call the get function and with
//returned value, for loop should be runned to check if the provided id is contained by the persons address and return bool based on that