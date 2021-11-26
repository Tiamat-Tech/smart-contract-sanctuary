// SPDX-License-Identifier: GPL-3.0

/// @dev Using specific compiler pragma as 1 of 2 requisite 'Protect against two attack vectors from the "Smart Contracts" section with its SWC number '
pragma solidity 0.8.1; // SWC-103

/// @dev using inheritance (taking over a contract from OpenZeppelin). 1 of 2 requisite 'Use at least two design patterns from the "Smart Contracts" section'.
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
/// @dev using Access Control Design Patterns (namely Ownable). 2 of 2 requisite 'Use at least two design patterns from the "Smart Contracts" section'.
import "@openzeppelin/contracts/access/Ownable.sol";


/// @author Marco De Falco - Basing myself of a lot of work by Hashlips
/// @notice You can use this contract for only the most basic simulation
/// @dev All function calls are currently implemented without side effects

contract BlockgemsNFTcollectionRinkeby is ERC721Enumerable, Ownable {
  using Strings for uint256;

  string public baseURI;
  string public baseExtension = ".json";
  uint256 public cost = 0.01 ether;
  uint256 public maxSupply = 18;
  uint256 public maxMintAmount = 2;
  bool public paused = false;
  mapping(address => bool) public whitelisted;


/// @notice In the constructor we run '1 time only' fucntions that are executed when the contract is deployed.
/// @notice besides the NFT name and symbol we are giving a base URI (where is the data going to be located?) and minting one for the owner. (This is not needed, I just included it) 
  constructor(
    string memory _name,
    string memory _symbol,
    string memory _initBaseURI
  ) ERC721(_name, _symbol) {
    setBaseURI(_initBaseURI);
    mint(msg.sender, 1); 
  }

  /// @notice an internal function that returns the base URI. It will be useful later.
  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }

  /// @notice The actual minter
  /// @dev as you can see it uses the 'battle tested' safemint function, which should be similar to safetransfer but for erc 721
  function mint(address _to, uint256 _mintAmount) public payable {
    uint256 supply = totalSupply();
    require(!paused);
    require(_mintAmount > 0);
    require(_mintAmount <= maxMintAmount);
    require(supply + _mintAmount <= maxSupply);

    if (msg.sender != owner()) {
        if(whitelisted[msg.sender] != true) {
          require(msg.value >= cost * _mintAmount);
        }
    }

    for (uint256 i = 1; i <= _mintAmount; i++) {
      _safeMint(_to, supply + i);
    }
  }
 /// @notice it returns the number of tokens the owner has in their wallet
  function walletOfOwner(address _owner)
    public
    view
    returns (uint256[] memory)
  {
    uint256 ownerTokenCount = balanceOf(_owner);
    uint256[] memory tokenIds = new uint256[](ownerTokenCount);
    for (uint256 i; i < ownerTokenCount; i++) {
      tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
    }
    return tokenIds;
  }
 /// @notice you insert the token ID and it returns an ipfs adress pointing to a single json that identifies the metadata of that token

  function tokenURI(uint256 tokenId)
    public
    view
    virtual
    override
    returns (string memory)
  {
    require(
      _exists(tokenId),
      "ERC721Metadata: URI query for nonexistent token"
    );

    string memory currentBaseURI = _baseURI();
    return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension))
        : "";
  }

  /// @notice below the function exclusively callable by the owner
  /// @dev these are bonus entries for 'Use at least two design patterns from the "Smart Contracts" section'. In fact, they provide 'upgrades/changes' to the contract. 

  /// @notice it changes the minting price of the token

  function setCost(uint256 _newCost) public onlyOwner {
    cost = _newCost;
  }

  /// @notice it changes the max amount of token the contract can mint

  function setmaxMintAmount(uint256 _newmaxMintAmount) public onlyOwner {
    maxMintAmount = _newmaxMintAmount;
  }

  /// @notice it changes the location where the metadata is stored

  function setBaseURI(string memory _newBaseURI) public onlyOwner {
    baseURI = _newBaseURI;
  }

  /// @notice it changes the file extension e.g. .json


  function setBaseExtension(string memory _newBaseExtension) public onlyOwner {
    baseExtension = _newBaseExtension;
  }

    /// @notice it pauses / unpauses the minting ability of the contract


  function pause(bool _state) public onlyOwner {
    paused = _state;
  }
 
  /// @notice it whitelists an address

 function whitelistUser(address _user) public onlyOwner {
    whitelisted[_user] = true;
  }
 
  /// @notice it removes an address from the whitelist

  function removeWhitelistUser(address _user) public onlyOwner {
    whitelisted[_user] = false;
  }

/// @dev 2 of 2 requisite 'Protect against two attack vectors from the "Smart Contracts" section with its SWC number '
/// @dev SWC-115 . Instead of using require(tx.origin == owner) I use onlyOwner 
  function withdraw() public payable onlyOwner {
    require(payable(msg.sender).send(address(this).balance));
  }
}