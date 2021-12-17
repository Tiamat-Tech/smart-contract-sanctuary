//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";


contract fenchbulldog is ERC721URIStorage {

     uint256 public MAX_TOKEN = 10;
    uint256 public PRICE = 0.01 ether;
    address public CREATOR = 0x55e534195C35B44e9097E244e53c3E3BD766078A;
    uint256 public token_count;

    constructor() ERC721("fenchbulldog", "fNFT") {
       // _setTokenURI(0, "http://my-json-server.typicode.com/abcoathup/samplenft/tokens/0");
    }

    //function _baseURI() internal view virtual override returns (string memory) {
        //return "https://github.com/Ninja-LLC/frenchbulldog/blob/main/";
//}

 // _setTokenURI(uint256 tokenId, string memory _tokenURI);
    

 function mintNFT(address to) public payable
    {
        require(token_count < MAX_TOKEN, "Sold out");
        require(msg.value >= PRICE, "Must pay price");
        _setTokenURI(token_count, "http://my-json-server.typicode.com/abcoathup/samplenft/tokens/0");
        _mint(to, token_count);
        token_count  += 1;
    }

    function withdrawAll() public
    {
        (bool success, ) = CREATOR.call{value:address(this).balance}("");
        require(success, "Transfer failed.");
    }
}