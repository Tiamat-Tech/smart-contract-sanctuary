//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SkullBasquiatTribute is ERC1155 , Ownable{

    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    string public name = "Skull Basquiat Tribute";
    string public symbol = "SKULL";
    string private cURI = "https://raw.githubusercontent.com/nawab69/skull-nft-makelismos/master/metadata.json";
    address private royalityOwner = 0xE9354f4B8e8b7Ad4A48577a3262382621917F1e7;

    constructor() ERC1155("https://raw.githubusercontent.com/nawab69/skull-nft-makelismos/master/metadata/{id}.json") {
        _mint(royalityOwner,0,1,"");
        _mint(royalityOwner,1,10,"");
        _mint(royalityOwner,2,100,"");
        _transferOwnership(royalityOwner);
    }
    
    function mint(uint256 _tokenId, uint256 _amount) public onlyOwner {
        _mint(msg.sender,_tokenId,_amount,"");
    }

    
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view returns (address receiver, uint256 royaltyAmount) {
        if(_tokenId >= 0 ){
            return (royalityOwner, (_salePrice * 10)/100 );
        }else{
            return (address(0), 0);
        }   
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155) returns (bool) {
        if(interfaceId == _INTERFACE_ID_ERC2981) {
            return true;
        }
        return super.supportsInterface(interfaceId);
    }

    function contractURI() public view returns (string memory) {
        return cURI;
    }

    function setURI(string memory _newURI) public onlyOwner {
        _setURI(_newURI);
    }

    function setContractURI(string memory  _contractURI) public onlyOwner {
         cURI = _contractURI;
    }

}