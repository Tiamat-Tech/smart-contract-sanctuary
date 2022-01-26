// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol"; 
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

contract Tygr26_2 is ERC721, Ownable {
  using Strings for uint256;
  using Counters for Counters.Counter;

  Counters.Counter private supply;

  string public uriPrefix = "";
  string public uriSuffix = ".json";
  string public hiddenMetadataUri;
  
  uint256 public cost = 0.01 ether;
  uint256 public maxSupply = 27;
  uint256 public maxPreSale = 10;
  uint256 public maxMintAmountPerTx = 10;

  bool public paused = false;
  bool public revealed = true;

  address public elixirContractAddress;
  address[3] private _shareholders;
  uint[3] private _shares;


  uint256 public maxPresaleMintsPerWallet = 10;

  bool public preSaleIsActive = false;

  mapping (address => uint256) private _presaleMints;

  
  function flipPreSaleState() public onlyOwner {
    preSaleIsActive = !preSaleIsActive;
  }


  event PaymentReleased(address to, uint256 amount);

  constructor() ERC721("Tygr26_2", "Tygr26_2") {
      
    _shareholders[0] = 0x0D514Ba2c3BE50D0592185b8A168eD31cB2E4028; // Anki 1
    _shareholders[1] = 0xe5Df8FC2342DA184363D121e8fcf7DcDE5F809b5; // Mike 2
    

    _shares[0] = 17;
    _shares[1] = 10;
    
    // Settin the hidden JSON metadata before the reveal
    setHiddenMetadataUri("ipfs://QmQGx8MiiNyE9PpPvnXDkrXQjeqrUir7Fk6TZWPhU53frR/");
  }

  function setMaxPresaleMintsPerWallet(uint256 newLimit) public onlyOwner {
        maxPresaleMintsPerWallet = newLimit;
  }

  function setElixirContractAddress(address newElixirContractAddress) public onlyOwner {
        elixirContractAddress = newElixirContractAddress;
  }

  

  modifier mintCompliance(uint256 _mintAmount) {
    require(_mintAmount > 0 && _mintAmount <= maxMintAmountPerTx, "Invalid mint amount!");
    require(supply.current() + _mintAmount <= maxSupply, "Max supply exceeded!");
    _;
  }

  

  function totalSupply() public view returns (uint256) {
    return supply.current();
  }

  function mint(uint256 _mintAmount) public payable mintCompliance(_mintAmount) {
    require(!paused, "The contract is paused!");
    require(!preSaleIsActive, "Pre-sale live");
    require(cost * _mintAmount <= msg.value, "Ether value sent is not correct");

    _mintLoop(msg.sender, _mintAmount);
  }

  function mintPresale(uint256 _mintAmount) public payable {
    require(!paused, "The contract is paused!");
    require(preSaleIsActive, "Pre-sale is not live yet");
    require(_presaleMints[msg.sender] + _mintAmount <= maxPresaleMintsPerWallet, "Max mints per wallet limit exceeded");
    require(totalSupply() + _mintAmount <= maxPreSale, "Purchase would exceed max available NFTs");
    require(cost * _mintAmount <= msg.value, "Ether value sent is not correct");
    _presaleMints[msg.sender] += _mintAmount;
    //require(msg.value <= cost * _mintAmount, "Insufficient funds!");

    _mintLoop(msg.sender, _mintAmount);
  }
  
  function mintForAddress(uint256 _mintAmount, address _receiver) public mintCompliance(_mintAmount) onlyOwner {
    _mintLoop(_receiver, _mintAmount);
  }


  function burnForElixir(uint256 tokenId) external {
        require(_isApprovedOrOwner(tx.origin, tokenId) && msg.sender == elixirContractAddress, "Caller is not owner nor approved");
        _burn(tokenId);
  }


  function walletOfOwner(address _owner)
    public
    view
    returns (uint256[] memory)
  {
    uint256 ownerTokenCount = balanceOf(_owner);
    uint256[] memory ownedTokenIds = new uint256[](ownerTokenCount);
    uint256 currentTokenId = 1;
    uint256 ownedTokenIndex = 0;

    while (ownedTokenIndex < ownerTokenCount && currentTokenId <= maxSupply) {
      address currentTokenOwner = ownerOf(currentTokenId);

      if (currentTokenOwner == _owner) {
        ownedTokenIds[ownedTokenIndex] = currentTokenId;

        ownedTokenIndex++;
      }

      currentTokenId++;
    }

    return ownedTokenIds;
  }

  function tokenURI(uint256 _tokenId)
    public
    view
    virtual
    override
    returns (string memory)
  {
    require(
      _exists(_tokenId),
      "ERC721Metadata: URI query for nonexistent token"
    );

    if (revealed == false) {
      return hiddenMetadataUri;
    }

    string memory currentBaseURI = _baseURI();
    return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, _tokenId.toString(), uriSuffix))
        : "";
  }

  function setRevealed(bool _state) public onlyOwner {
    revealed = _state;
  }

  function setMaxPreSale(uint256 _maxPreSale) public onlyOwner {
    maxPreSale = _maxPreSale;
  }

  function setCost(uint256 _cost) public onlyOwner {
    cost = _cost;
  }

  function setMaxMintAmountPerTx(uint256 _maxMintAmountPerTx) public onlyOwner {
    maxMintAmountPerTx = _maxMintAmountPerTx;
  }

  function setHiddenMetadataUri(string memory _hiddenMetadataUri) public onlyOwner {
    hiddenMetadataUri = _hiddenMetadataUri;
  }

  function setUriPrefix(string memory _uriPrefix) public onlyOwner {
    uriPrefix = _uriPrefix;
  }

  function setUriSuffix(string memory _uriSuffix) public onlyOwner {
    uriSuffix = _uriSuffix;
  }

  function setPaused(bool _state) public onlyOwner {
    paused = _state;
  }

    function withdraw(uint256 amount) public onlyOwner {
        require(address(this).balance >= amount, "Insufficient balance");        
        uint256 totalShares = supply.current();
        for (uint256 i = 0; i < 2; i++) {
            uint256 payment = amount * _shares[i] / totalShares;
            Address.sendValue(payable(_shareholders[i]), payment);
            emit PaymentReleased(_shareholders[i], payment);
        }
    }
  function _mintLoop(address _receiver, uint256 _mintAmount) internal {
    for (uint256 i = 0; i < _mintAmount; i++) {
      supply.increment();
      _safeMint(_receiver, supply.current());
    }
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return uriPrefix;
  }
  function withdrawToOwnerWallet() public onlyOwner {
    (bool os, ) = payable(owner()).call{value: address(this).balance}("");
    require(os);
  }

  function getTheBalance() public view returns (uint256) {
    return address(this).balance;
  }
}