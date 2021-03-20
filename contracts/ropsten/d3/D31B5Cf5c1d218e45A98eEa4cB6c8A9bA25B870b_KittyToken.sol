pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721Full.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/lifecycle/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
//import "@openzeppelin/contracts/utils/Counters.sol";

// NFT Kitty token
// Stores 1 value for every token: attribute

contract KittyToken is ERC721Full, Ownable, Pausable, ReentrancyGuard {
  
  string public constant name = "DrKitty Token";
  string public constant symbol = "DKT";
  using Counters for Counters.Counter;
  Counters.Counter private tokenId;

  struct Kitty {
    uint256 kittyTokenId;
    string birthday;
    string owner;
    string gender;
    uint256 generation;
    uint256 motherId;
    uint256 fatherId;
    string kittyType;
    string imageURL;
  }
  
  //Kitty[] public kitties;
  mapping(uint256 => Kitty) public kittyDictionary;

  constructor(
  )
    ERC721Full(name, symbol)
    public
  {}

  // Return name, gender, attribute of a kitty token
  function getKitty( uint256 inputTokenId ) 
    public view returns(uint256 kittyTokenId,
      string memory birthday,
      string memory owner,
      string memory gender,
      uint256 generation,
      uint256 motherId,
      uint256 fatherId,
      string memory kittyType, 
      string memory imageURL) {

    Kitty memory _kitty = kittyDictionary[inputTokenId];

    kittyTokenId = _kitty.kittyTokenId;
    birthday = _kitty.birthday;
    owner = _kitty.owner;
    gender = _kitty.gender;
    generation = _kitty.generation;
    motherId = _kitty.motherId;
    fatherId = _kitty.fatherId;
    kittyType = _kitty.kittyType;
    imageURL = _kitty.imageURL;
  }
	
  // Create a new Kitty token with params: name, gender, attribute
  function mint(address _to, 
    uint256 _kittyTokenId,
    string memory _birthday,
    string memory _owner,
    string memory _gender,
    uint256 _generation,
    uint256 _motherId,
    uint256 _fatherId,
    string memory _kittyType,
    string memory _imageURL,
    string memory _tokenURI) public payable onlyOwner {

    //uint256 kittyTokenId = tokenId.current();
    
    Kitty memory _kitty = Kitty({ 
      kittyTokenId: _kittyTokenId,
      birthday : _birthday,
      owner : _owner,   
      gender: _gender,
      generation : _generation,
      motherId : _motherId,
      fatherId : _fatherId,
      kittyType : _kittyType,
      imageURL : _imageURL
    });

    //kitties.push(_kitty);
    kittyDictionary[_kittyTokenId] = _kitty;
    _mint(_to, _kittyTokenId);
    _setTokenURI(_kittyTokenId, _tokenURI);
    //tokenId.increment();
  }
}