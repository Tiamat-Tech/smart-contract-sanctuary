// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@imtbl/imx-contracts/contracts/Mintable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Asset is Ownable, ERC721, Mintable {

    uint public tokenCount = 0;
    uint public cost = 0.07 ether;
    uint public totalSupply = 8888;
    uint public preSaleSupply = 6018;
    uint public preSaleMintLimit = 3;
    uint public publicSaleMintLimit = 5;

    address[] public whiteListed;
    
    constructor(
        address _owner,
        string memory _name,
        string memory _symbol,
        address _imx
    ) ERC721(_name, _symbol) Mintable(_owner, _imx) {}

    function _mintFor(
        address user,
        uint256 id,
        bytes memory _blueprint
    ) internal override {
        _safeMint(user, id);
        blueprints[id] = _blueprint;
        emit AssetMinted(user, id, _blueprint);
    }

    function isWhiteListed(address _user) internal view returns(bool){
      for(uint i = 0; i < whiteListed.length; ++i){
        if(whiteListed[i] == _user){
          return true;
        }
      }
      return false;
    }

    function mintTokens(string memory _uri) internal {
      _mintFor(_msgSender(), ++tokenCount, bytes(_uri));
    }


    function preSaleBuyTokens(uint _tokens, string[] memory uris) public payable {
      require(isWhiteListed(_msgSender()), "ERROR: User not whitelisted.");
      require(tokenCount+_tokens <= preSaleSupply, "ERROR: Amount exceeds supply.");
      require(_tokens <= preSaleMintLimit, "ERROR: Amount exceeds wallet limit.");
      require(msg.value == cost*_tokens, "ERROR: Cost insufficient.");
      require(_tokens == uris.length, "ERROR: Invalid numbers of blueprints.");
      for(uint i = 0; i < _tokens; ++i){
        mintTokens(uris[i]);
      }
      (bool success, ) = payable(owner()).call{value: msg.value}("");
        require(success, "Payment not sent.");
    }

    function publicSaleBuyTokens(uint _tokens, string[] memory uris) public payable{
      require(_tokens <= publicSaleMintLimit, "ERROR: Amount exceeds wallet limit.");
      require(tokenCount+_tokens <= totalSupply, "ERROR: Amount exceeds supply.");
      require(msg.value == cost*_tokens, "ERROR: Cost insufficient.");
      require(_tokens == uris.length, "ERROR: Invalid numbers of blueprints.");
      for(uint i = 0; i < _tokens; ++i){
        mintTokens(uris[i]);
      }
      (bool success, ) = payable(owner()).call{value: msg.value}("");
        require(success, "Payment not sent.");
    }
    function whitelistUser(address _user) public onlyOwner {
      if(!isWhiteListed(_user)){
        whiteListed.push(_user);
      }
    }

    function addWhitelistUsers(address[] calldata _users) public onlyOwner {
      for(uint i = 0; i < _users.length; ++i) {
        whitelistUser(_users[i]);
      }
    }

    function removeWhitelistUser(address _user) public onlyOwner {
      int index = -1;
      for(uint i = 0; i < whiteListed.length; ++i ){
        if(whiteListed[i] == _user){
          index = int(i);
        }
      }
      if(index != -1){
        delete whiteListed[uint(index)];
      }
    }

    function setCost(uint _cost) external onlyOwner {
      cost = _cost;
    }

    function setTotalSupply(uint _supply) external onlyOwner {
      totalSupply = _supply;
    }

    function setPreSaleSupply(uint _supply) external onlyOwner {
      require(_supply <= totalSupply, "ERROR: preSaleSupply exceeds the totalSupply.");
      preSaleSupply = _supply;
    }

    function setPublicMintLimit(uint _limit) external onlyOwner {
      publicSaleMintLimit = _limit;
    }

    function setPreMintLimit(uint _limit) external onlyOwner {
      preSaleMintLimit = _limit;
    }
}