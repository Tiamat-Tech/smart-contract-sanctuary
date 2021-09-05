// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract PrettyShapes is ERC721Enumerable, Ownable {

    using Strings for uint256;

    string _baseTokenURI;
    uint public constant MAX_ENTRIES = 100;
    
    constructor(string memory baseURI) ERC721("PrettyShapes", "PS")  {
        setBaseURI(baseURI);
    }

	// Only the owner of the contract can mint
    function mint(address _to, uint256 num) public payable onlyOwner() {
        uint256 supply = totalSupply();
		
        require( supply + num <= MAX_ENTRIES, "Exceeds maximum supply" );

        for(uint256 i; i < num; i++){
          _safeMint( _to, supply + i );
        }
    }

    function walletOfOwner(address _owner) public view returns(uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);

        uint256[] memory tokensId = new uint256[](tokenCount);
        for(uint256 i; i < tokenCount; i++){
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokensId;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }

    function withdrawAll() public payable onlyOwner {
        require(payable(msg.sender).send(address(this).balance));
    }
}