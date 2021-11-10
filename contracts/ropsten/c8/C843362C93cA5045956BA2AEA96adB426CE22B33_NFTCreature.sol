//SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTCreature is ERC721, ERC721Enumerable , Ownable {

    uint256 public lastTokenID;
    mapping (uint256 => string) private tokenURIs;
    address public _battle;
    mapping (uint256 => mapping (string => string)) public battleStorage;
    mapping (uint256 => mapping (string => string)) public userStorage;

    constructor () ERC721 ("CreaturesBattle", "CRB"){
       // _transferOwnership(_msgSender());
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function setBattle (address battle) public onlyOwner{
        _battle = battle;
    }

    function setUserInfo(uint256 id,string memory name, string memory value) public{//todo
      userStorage[id][name] = value;
    }

    function setBattleInfo(uint256 id,string memory name, string memory value) public onlyOwner{//todo
      require(_battle == _msgSender(), "Ownable: caller is not the battle contract");
      battleStorage[id][name] = value;
    }

    function tokenURI(uint256 tokenId) public override view returns (string memory) {
        require(_exists(tokenId), 'ERC721Metadata: URI query for nonexistent token');
        return tokenURIs[tokenId];
    }

    function mintCreature(string memory _tokenURI) public onlyOwner{
        tokenURIs[lastTokenID]=_tokenURI;    
        _safeMint(msg.sender, lastTokenID);
        lastTokenID++;
    }

    function rescueCoin() public onlyOwner{
        uint256 balance = address(this).balance;
        payable(_msgSender()).transfer(balance);
    }

    function rescueToken(address _token, uint256 _amount) public onlyOwner{
        IERC20(_token).transfer(msg.sender, _amount);
    }

}